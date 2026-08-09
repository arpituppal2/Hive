//
//  SheetsPanel+Actions.swift
//  Hive
//
//  Carved out of SheetsPanelView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Actions
//

import SwiftUI
import AppKit
import HiveCore
import UniformTypeIdentifiers

// MARK: - SheetsPanel + Actions

@MainActor
extension SheetsPanel {


    // MARK: - Actions

    func createSheet() async {
        guard !state.isKnowledgePersistenceDegraded else {
            sheetError = "Sheet creation blocked: knowledge storage is unavailable. Restart Hive to restore it."
            return
        }
        let title = newSheetTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        do {
            let sheet = HiveSheet(
                title: title,
                columns: [
                    SheetColumn(name: "A", kind: .text),
                    SheetColumn(name: "B", kind: .text),
                    SheetColumn(name: "C", kind: .text)
                ]
            )
            try await state.honeycomb.createSheet(sheet)
            await MainActor.run {
                newSheetTitle = ""
                isCreatingSheet = false
                sheetError = nil
            }
            await refresh()
        } catch {
            await MainActor.run {
                sheetError = "Could not create sheet: \(error.localizedDescription)"
                state.reportKnowledgePersistenceFailure()
            }
        }
    }


    func importCSV() {
        guard !state.isKnowledgePersistenceDegraded else {
            sheetError = "CSV import blocked: knowledge storage is unavailable. Restart Hive to restore it."
            return
        }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Import a CSV file into a new sheet"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                let csv = try String(contentsOf: url, encoding: .utf8)
                let name = url.deletingPathExtension().lastPathComponent
                let sheet = HiveSheet.importCSV(csv, title: name)
                try await state.honeycomb.createSheet(sheet)
                await refresh()
            } catch {
                await MainActor.run {
                    sheetError = "Import failed: \(error.localizedDescription)"
                    state.reportKnowledgePersistenceFailure()
                }
            }
        }
    }


    func refresh() async {
        if let list = try? await state.honeycomb.getAllSheets() {
            await MainActor.run { sheets = list }
        }
    }
}
