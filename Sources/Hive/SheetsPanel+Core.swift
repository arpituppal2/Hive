//
//  SheetsPanel+Core.swift
//  Hive
//
//  Carved out of SheetsPanelView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: 
//

import SwiftUI
import AppKit
import HiveCore
import UniformTypeIdentifiers

// MARK: - SheetsPanel + Core

@MainActor
extension SheetsPanel {


    var body: some View {
        VStack(spacing: 0) {
            if let selectedSheetID {
                SheetEditorView(
                    sheetID: selectedSheetID,
                    onBack: { self.selectedSheetID = nil }
                )
            } else {
                sheetListView
            }
        }
        .task { await refresh() }
    }
}
