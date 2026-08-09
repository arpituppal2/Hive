//
//  SheetsPanel+List.swift
//  Hive
//
//  Carved out of SheetsPanelView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Sheet List
//

import SwiftUI
import AppKit
import HiveCore
import UniformTypeIdentifiers

// MARK: - SheetsPanel + List

@MainActor
extension SheetsPanel {


    // MARK: - Sheet List

    var sheetListView: some View {
        VStack(spacing: 0) {
            headerBar
            if isCreatingSheet { newSheetForm }
            if let error = sheetError {
                Text(error)
                    .font(HiveDesign.Typography.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if sheets.isEmpty && !isCreatingSheet {
                        emptyState
                    } else {
                        ForEach(sheets) { sheet in
                            SheetListItem(sheet: sheet) {
                                withAnimation(reduceMotion ? nil : HiveDesign.Animation.spring) {
                                    selectedSheetID = sheet.id
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }


    var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "tablecells")
                .font(HiveDesign.Typography.sidebarItemSemiBold)
                .foregroundStyle(HiveDesign.Accent.primary)
            Text("Sheets")
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(HiveDesign.Text.primary)
            Spacer()
            // Import CSV button
            Button(action: { importCSV() }) {
                Image(systemName: "square.and.arrow.down")
                    .font(HiveDesign.Typography.sectionHeader)
                    .foregroundStyle(HiveDesign.Text.tertiary)
                    .frame(width: 20, height: 20)
                    .background(HiveDesign.Surface.level2)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .help("Import CSV")
            .accessibilityLabel("Import CSV")
            // Create new sheet
            Button(action: { withAnimation(reduceMotion ? nil : HiveDesign.Animation.spring) { isCreatingSheet.toggle() } }) {
                Image(systemName: isCreatingSheet ? "xmark" : "plus")
                    .font(HiveDesign.Typography.sectionHeader)
                    .foregroundStyle(HiveDesign.Accent.primary)
                    .frame(width: 20, height: 20)
                    .background(HiveDesign.Surface.level2)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .help(isCreatingSheet ? "Cancel" : "New sheet")
            .accessibilityLabel(isCreatingSheet ? "Cancel new sheet" : "Create new sheet")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }


    var newSheetForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Sheet title", text: $newSheetTitle)
                .textFieldStyle(.plain)
                .font(HiveDesign.Typography.sidebarItemMedium)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(HiveDesign.Surface.level2)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onSubmit { Task { await createSheet() } }
            HStack {
                Spacer()
                Button("Create") { Task { await createSheet() } }
                    .buttonStyle(.borderedProminent)
                    .tint(HiveDesign.Accent.primary)
                    .font(HiveDesign.Typography.sectionHeader)
                    .disabled(newSheetTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }


    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tablecells")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(HiveDesign.Text.tertiary.opacity(0.5))
            Text("No sheets yet")
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(HiveDesign.Text.secondary)
            Text("Create a sheet or import CSV to organize data with formulas and source provenance.")
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(HiveDesign.Text.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
}
