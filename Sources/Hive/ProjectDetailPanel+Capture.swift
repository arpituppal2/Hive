//
//  ProjectDetailPanel+Capture.swift
//  Hive
//
//  Carved out of ProjectsPanelView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Capture
//

import SwiftUI
import HiveCore

// MARK: - ProjectDetailPanel + Capture

@MainActor
extension ProjectDetailPanel {


    // MARK: - Capture

    func captureCurrentPage() async {
        guard state.activePageContext != nil else {
            await MainActor.run { detailError = "Open a page first to capture it into this project." }
            return
        }
        await MainActor.run { isCapturingPage = true }
        do {
            let sourceID = try await state.captureCurrentPage()
            // Dedup: capturing the same page into the same project twice must
            // not create a second belongsTo edge (getProjectNodes would list
            // the source twice).
            let alreadyLinked = try await state.honeycomb.edgeExists(
                from: sourceID, to: projectID, relation: .belongsTo
            )
            if !alreadyLinked {
                _ = try await state.honeycomb.insertEdge(HoneycombStore.Edge(
                    sourceID: sourceID,
                    targetID: projectID,
                    relation: .belongsTo
                ))
            }
            await MainActor.run {
                isCapturingPage = false
                detailError = nil
            }
            await refresh()
        } catch {
            await MainActor.run {
                isCapturingPage = false
                detailError = "Capture failed: \(error.localizedDescription)"
            }
        }
    }
}
