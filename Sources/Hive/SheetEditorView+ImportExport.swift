//
//  SheetEditorView+ImportExport.swift
//  Hive
//
//  Carved out of SheetsPanelView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - CSV Export | - Load
//

import SwiftUI
import AppKit
import HiveCore
import UniformTypeIdentifiers

// MARK: - SheetEditorView + ImportExport

@MainActor
extension SheetEditorView {


    // MARK: - CSV Export

    func exportCSV() {
        guard let sheet else { return }
        let csv = sheet.exportCSV()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "\(sheet.title).csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            editorError = "Export failed: \(error.localizedDescription)"
        }
    }


    // MARK: - Load

    func loadSheet() async {
        if let loaded = try? await state.honeycomb.getSheet(id: sheetID) {
            await MainActor.run { self.sheet = loaded }
        }
    }
}
