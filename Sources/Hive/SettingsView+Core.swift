//
//  SettingsView+Core.swift
//  Hive
//
//  Carved out of SettingsView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Helpers
//

import SwiftUI
import AppKit
import HiveCore

// MARK: - SettingsView + Core

@MainActor
extension SettingsView {


    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    SettingsSidebarRow(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) { selectedTab = tab }
                }
                Spacer()
            }
            .frame(width: 160)
            .padding(.top, 32)
            .padding(.horizontal, 8)
            .background(Color.primary.opacity(0.03))

            Divider()

            // Content
            ScrollView {
                contentView
                    .padding(32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 620, height: 440)
        .background(.background)
    }


    @ViewBuilder
    var contentView: some View {
        switch selectedTab {
        case .appearance: appearanceTab
        case .search: searchTab
        case .commands: commandsTab
        case .privacy: privacyTab
        case .performance: performanceTab
        case .about: aboutTab
        }
    }


    // MARK: - Helpers

    func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(HiveDesign.Typography.smallLabelBold)
                .foregroundStyle(Color.hiveAccent)
                .textCase(.uppercase)

            content()
                .font(HiveDesign.Typography.body)
        }
    }
}
