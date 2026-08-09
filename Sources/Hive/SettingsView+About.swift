//
//  SettingsView+About.swift
//  Hive
//
//  Carved out of SettingsView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - About
//

import SwiftUI
import AppKit
import HiveCore

// MARK: - SettingsView + About

@MainActor
extension SettingsView {


    // MARK: - About

    var aboutTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "hexagon.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Color.hiveAccent)

                VStack(spacing: 2) {
                    Text("The Hive Browser")
                        .font(.system(size: 18, weight: .bold))
                    Text("Version 1.0")
                        .font(HiveDesign.Typography.body)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)

            settingsGroup("Engine") {
                LabeledContent("Rendering engine", value: "Chromium Embedded Framework (CEF)")
                LabeledContent("JavaScript engine", value: "V8")
                LabeledContent("Platform", value: "macOS")
                LabeledContent("Swift version", value: "6.0")
            }
        }
    }
}
