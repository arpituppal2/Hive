//
//  GeminiSidePanel+Header.swift
//  Hive
//
//  Carved out of GeminiSidePanel.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Header (original)
//

import SwiftUI
import HiveCore

// MARK: - GeminiSidePanel + Header

@MainActor
extension GeminiSidePanel {


    // MARK: - Header (original)

    var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(HiveDesign.Typography.bodySemiBold)
                .foregroundStyle(Color.hiveAccent)

            Text("Ask Hive")
                .font(HiveDesign.Typography.bodySemiBold)
                .foregroundStyle(.primary)

            Spacer()

            if state.isGeminiGenerating {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                    Text("Generating")
                        .font(.system(size: HiveDesign.Typography.sizeMD, weight: .medium))
                        .foregroundStyle(Color.hiveAccent)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(HiveDesign.Surface.level2)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }

            // Model toggle — Comet-style: switch the underlying provider from
            // the panel header. The choice is persisted; the footer + context
            // strip always show which provider actually answered (honest).
            Menu {
                ForEach(GeminiProviderOption.allCases) { option in
                    Button(action: { state.setPreferredModelProvider(option.rawValue) }) {
                        if option.rawValue == state.preferredModelProvider {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                }
                Divider()
                Text("The provider that actually answers is shown below. If the selected model is unavailable, Hive falls back honestly.")
            } label: {
                Image(systemName: "cpu")
                    .font(HiveDesign.Typography.sectionHeader)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .help("Model: \(state.preferredModelProvider)")

            Button(action: { state.isGeminiPanelOpen = false }) {
                Image(systemName: "xmark")
                    .font(HiveDesign.Typography.smallLabelBold)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Ask Hive")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
