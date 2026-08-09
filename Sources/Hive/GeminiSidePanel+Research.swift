//
//  GeminiSidePanel+Research.swift
//  Hive
//
//  Carved out of GeminiSidePanel.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Deep Research Progress
//

import SwiftUI
import HiveCore

// MARK: - GeminiSidePanel + Research

@MainActor
extension GeminiSidePanel {


    // MARK: - Deep Research Progress

    /// Shows live progress of a multi-step deep research query.
    /// Plan → Search → Read → Synthesize → Refine (optional).
    @ViewBuilder
    var deepResearchProgress: some View {
        if let step = state.deepResearchStep {
            switch step {
            case .complete:
                EmptyView()
            default:
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        ProgressView(value: step.progress, total: 1.0).progressViewStyle(.linear)
                            .scaleEffect(x: 1, y: 0.5)
                            .tint(Color.hiveAccent)
                        Text("\(Int(step.progress * 100))%")
                            .font(HiveDesign.Typography.monoMicroMedium)
                            .foregroundStyle(Color.hiveAccent)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: deepResearchIcon(for: step))
                            .font(HiveDesign.Typography.captionSemiBold)
                            .foregroundStyle(Color.hiveAccent)
                            .symbolEffect(.pulse, options: .repeating)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(step.label)
                                .font(HiveDesign.Typography.captionSemiBold)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if let detail = step.liveDetail, !detail.isEmpty {
                                Text(detail)
                                    .font(HiveDesign.Typography.monoMicro)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Button(action: { state.cancelDeepResearch() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Cancel deep research")
                        Text("Deep Research")
                            .font(HiveDesign.Typography.microLabelBold)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(HiveDesign.Surface.level1)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1)
                }
            }
        }
    }


    /// Icon matching the current research phase.
    func deepResearchIcon(for step: ResearchStep) -> String {
        switch step {
        case .planning: return "text.magnifyingglass"
        case .searching: return "magnifyingglass.circle.fill"
        case .reading: return "book.pages.fill"
        case .synthesizing: return "arrow.triangle.merge"
        case .refining: return "arrow.triangle.capsulepath"
        case .complete: return "checkmark.seal.fill"
        }
    }


    var modelFooter: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
                .font(HiveDesign.Typography.microLabelSecondary)
                .foregroundStyle(.tertiary)
            Text(providerLabel)
                .font(HiveDesign.Typography.buttonCaption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 2)
    }
}
