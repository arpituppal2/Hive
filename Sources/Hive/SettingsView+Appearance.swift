//
//  SettingsView+Appearance.swift
//  Hive
//
//  Carved out of SettingsView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Appearance
//

import SwiftUI
import AppKit
import HiveCore

// MARK: - SettingsView + Appearance

@MainActor
extension SettingsView {


    // MARK: - Appearance

    var appearanceTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsGroup("Tab Layout") {
                Picker("", selection: $state.layout) {
                    ForEach(BrowserState.TabLayout.allCases) { layout in
                        HStack(spacing: 6) {
                            Image(systemName: layout.icon)
                            Text(layout.title)
                        }
                        .tag(layout)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
            }

            settingsGroup("Accent Color") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 10)], spacing: 10) {
                    ForEach(ThemePreset.presets) { preset in
                        Button(action: { state.setAccentColor(hex: preset.colorHex) }) {
                            Circle()
                                .fill(Color(hex: preset.colorHex) ?? Color.hiveAccent)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if state.browserAccentColorHex == preset.colorHex {
                                        Image(systemName: "checkmark")
                                            .font(HiveDesign.Typography.smallLabelBold)
                                            .foregroundStyle(.white)
                                    }
                                }
                                .overlay(
                                    Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(preset.name)
                    }
                }
                .frame(maxWidth: 320)
            }

            settingsGroup("New Tab") {
                Picker("", selection: $state.openBriefOnNewTab) {
                    Text("Morning Brief").tag(true)
                    Text("Start Page").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
                Text("New tabs open with a daily brief assembled locally from your browsing. The classic start page keeps search + top sites.")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            settingsGroup("Toolbar") {
                Toggle("Show Bookmarks Bar", isOn: $state.showBookmarksBar)
            }
        }
    }
}
