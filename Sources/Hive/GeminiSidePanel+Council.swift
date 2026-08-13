//
//  GeminiSidePanel+Council.swift
//  Hive
//
//  Carved out of GeminiSidePanel.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Council Verdict Section
//

import SwiftUI
import HiveCore

// MARK: - GeminiSidePanel + Council

@MainActor
extension GeminiSidePanel {


    /// Prefills the input with /deep for multi-step research.
    /// Does NOT auto-send — the user types their query after the prefix.


    // MARK: - Model Footer

    // MARK: - Council Verdict Section

    /// Shows the parallel multi-model council verdict when available.
    /// While convening: animated progress with provider count.
    /// Once complete: synthesized answer with per-provider responses and degradation indicators.
    @ViewBuilder
    var councilVerdictSection: some View {
        if state.isCouncilConvening {
            councilConveningView
        } else if let verdict = state.latestCouncilVerdict {
            councilVerdictView(verdict)
        }
    }


    var councilConveningView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
                Text("Council deliberating...")
                    .font(HiveDesign.Typography.captionSemiBold)
                    .foregroundStyle(Color.hiveAccent)
                Spacer()
                Text("\(state.councilLiveResponses.count) responded")
                    .font(HiveDesign.Typography.monoMicroMedium)
                    .foregroundStyle(.tertiary)
                Button(action: { state.cancelCouncil() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Cancel council")
            }

            // Live response cards — one per model as it responds
            if !state.councilLiveResponses.isEmpty {
                VStack(spacing: 4) {
                    ForEach(state.councilLiveResponses) { response in
                        liveResponseRow(response)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(HiveDesign.Surface.level1)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1)
        }
    }


    func liveResponseRow(_ response: CouncilResponse) -> some View {
        HStack(spacing: 6) {
            // Provider badge
            Text(providerLabel(response.provider))
                .font(HiveDesign.Typography.microLabelMedium)
                .foregroundStyle(providerColor(response.provider))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(providerColor(response.provider).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))

            if response.status == .success {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.green)
                Text(response.answer)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Image(systemName: statusIcon(response.status))
                    .font(.system(size: 8))
                    .foregroundStyle(HiveBrand.aiAccent)
                Text(statusMessage(response.status))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(Int(response.confidence * 100))%")
                .font(HiveDesign.Typography.monoMicroMedium)
                .foregroundStyle(response.confidence > 0.7 ? Color.green.opacity(0.7) : HiveBrand.aiAccent.opacity(0.7))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(HiveDesign.Surface.level2)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }


    func providerLabel(_ provider: CouncilProvider) -> String {
        switch provider {
        case .mlxLocal: return "Local"
        case .tavilyCloud: return "Tavily"
        case .vaneLocal: return "Vane"
        case .byokRemote: return "BYOK"
        }
    }


    func providerColor(_ provider: CouncilProvider) -> Color {
        switch provider {
        case .mlxLocal: return Color.hiveAccent
        case .tavilyCloud: return Color.purple
        case .vaneLocal: return Color.teal
        case .byokRemote: return HiveBrand.aiAccent
        }
    }


    func statusIcon(_ status: CouncilResponse.ResponseStatus) -> String {
        switch status {
        case .timeout: return "clock.badge.exclamationmark"
        case .error: return "xmark.circle.fill"
        case .unavailable: return "slash.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }


    func statusMessage(_ status: CouncilResponse.ResponseStatus) -> String {
        switch status {
        case .timeout: return "Timed out"
        case .error(let msg): return msg
        case .unavailable: return "Unavailable"
        case .success: return ""
        }
    }


    func councilVerdictView(_ verdict: CouncilVerdict) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: consensus indicator + stats
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(HiveDesign.Typography.captionSemiBold)
                    .foregroundStyle(Color.hiveAccent)
                Text("Council Verdict")
                    .font(HiveDesign.Typography.sectionHeader)
                    .foregroundStyle(.primary)
                Spacer()
                // Degradation indicator — honest, never hidden
                if verdict.isDegraded {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                        Text("Degraded")
                            .font(HiveDesign.Typography.microLabelMedium)
                    }
                    .foregroundStyle(HiveDesign.State.warning)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(HiveDesign.State.warning.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                Text("\(verdict.activeProviders.count) models")
                    .font(HiveDesign.Typography.monoMicroMedium)
                    .foregroundStyle(.tertiary)
                Text("\(Int(verdict.confidence * 100))%")
                    .font(HiveDesign.Typography.monoMicroMedium)
                    .foregroundStyle(verdict.confidence > 0.7 ? Color.green : HiveBrand.aiAccent)
            }

            // Synthesized answer
            Text(verdict.answer)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(8)
                .textSelection(.enabled)

            if !verdict.reasoning.isEmpty {
                Text(verdict.reasoning)
                    .font(HiveDesign.Typography.monoMicro)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }

            // Agreement / disagreement summary
            if !verdict.agreements.isEmpty || !verdict.disagreements.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    if !verdict.agreements.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.green)
                            Text("Agreed: \(verdict.agreements.prefix(3).joined(separator: ", "))")
                                .font(HiveDesign.Typography.microLabelSecondary)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    if !verdict.disagreements.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(HiveBrand.aiAccent)
                            Text("Disagreed: \(verdict.disagreements.prefix(3).joined(separator: ", "))")
                                .font(HiveDesign.Typography.microLabelSecondary)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }

            // Per-provider responses (expandable)
            DisclosureGroup {
                VStack(spacing: 6) {
                    ForEach(verdict.responses) { response in
                        HStack(alignment: .top, spacing: 6) {
                            Circle()
                                .fill(response.status == CouncilResponse.ResponseStatus.success ? Color.green : HiveBrand.aiAccent)
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(response.provider.rawValue)
                                        .font(HiveDesign.Typography.microLabelBold)
                                        .foregroundStyle(.primary)
                                    Text("\(Int(response.confidence * 100))%")
                                        .font(HiveDesign.Typography.monoMicroMedium)
                                        .foregroundStyle(.tertiary)
                                    Text("\(Int(response.duration * 1000))ms")
                                        .font(HiveDesign.Typography.monoMicro)
                                        .foregroundStyle(.tertiary)
                                }
                                Text(response.answer)
                                    .font(HiveDesign.Typography.monoMicro)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                    }
                }
                .padding(.leading, 4)
            } label: {
                Text("Show \(verdict.responses.count) model responses")
                    .font(HiveDesign.Typography.microLabelMedium)
                    .foregroundStyle(Color.hiveAccent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(HiveDesign.Surface.level1)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
        }
    }
}
