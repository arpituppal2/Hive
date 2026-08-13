//
//  GeminiSidePanel+Context.swift
//  Hive
//
//  Carved out of GeminiSidePanel.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Context Scope Control | - Context Scope Preview (Dia-style diagnostics) | - Hot context controls
//

import SwiftUI
import HiveCore

// MARK: - GeminiSidePanel + Context

@MainActor
extension GeminiSidePanel {


    // MARK: - Header

    // MARK: - Context Scope Control

    /// Explicitly controls the context contract for the next request. This is
    /// intentionally a menu, not a toggle hidden in settings: the user should
    /// be able to see and narrow Swarm's reach at the moment they ask.
    var contextModeControl: some View {
        Menu {
            ForEach(BrowserState.ContextMode.allCases) { mode in
                Button {
                    state.setContextMode(mode)
                } label: {
                    HStack {
                        Label(mode.title, systemImage: mode.icon)
                        if mode == state.contextMode {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            Text(state.contextMode.detail)
                .font(HiveDesign.Typography.caption)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: state.contextMode.icon)
                    .font(HiveDesign.Typography.captionSemiBold)
                    .foregroundStyle(Color.hiveAccent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Context")
                        .font(HiveDesign.Typography.microLabelBold)
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                    Text(state.contextMode.title)
                        .font(HiveDesign.Typography.sectionHeader)
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: HiveDesign.Typography.sizeXS, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HiveDesign.Surface.level1)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
        }
        .accessibilityLabel("Context scope")
        .accessibilityValue("\(state.contextMode.title). \(state.contextMode.detail)")
        .help(state.contextMode.detail)
    }


    func contextScopePreview(_ diag: ContextDiagnostics) -> some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(reduceMotion ? nil : HiveDesign.Animation.springQuick) { isContextScopeExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(HiveDesign.Typography.buttonCaption)
                        .foregroundStyle(Color.hiveAccent)

                    Text("Context")
                        .font(HiveDesign.Typography.sectionHeader)
                        .foregroundStyle(.primary)

                    Text("\(diag.contextNodeCount) nodes")
                        .font(HiveDesign.Typography.buttonCaption)
                        .foregroundStyle(.secondary)

                    if let ranker = diag.rankerProvider, ranker != "degraded" {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(HiveDesign.Typography.microLabelSecondary)
                            .foregroundStyle(Color.hiveAccent.opacity(0.7))
                    }

                    Text("\(diag.durationMS)ms")
                        .font(HiveDesign.Typography.monoMicro)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Image(systemName: isContextScopeExpanded ? "chevron.up" : "chevron.down")
                        .font(HiveDesign.Typography.microLabelBold)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isContextScopeExpanded {
                Divider().opacity(0.5)
                VStack(alignment: .leading, spacing: 8) {
                    if let title = diag.pageTitle, let host = diag.pageHost {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .font(HiveDesign.Typography.microLabelSecondary)
                                .foregroundStyle(.secondary)
                            Text("Current page:")
                                .font(HiveDesign.Typography.buttonCaption)
                                .foregroundStyle(.secondary)
                            Text(title)
                                .font(HiveDesign.Typography.captionSemiBold)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text("(\(host))")
                                .font(HiveDesign.Typography.monoMicro)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }

                    HStack(spacing: 8) {
                        contextStat("Nodes", "\(diag.contextNodeCount)", "square.grid.3x3")
                        contextStat("Provider", providerDisplayLabel(diag.providerLabel), "cpu")
                        contextStat("Time", "\(diag.durationMS)ms", "clock")
                        if let ranker = diag.rankerProvider {
                            contextStat("Ranker", ranker == "degraded" ? "fallback" : ranker, "line.3.horizontal.decrease")
                        }
                    }

                    // Per-node hot-context control — what the second brain is
                    // currently tracking, with one-tap forget. The user stays
                    // in control of what the AI knows (friction thesis).
                    if !scopeNodes.isEmpty || forgottenCount > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Hot context")
                                    .font(HiveDesign.Typography.microLabel)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                if forgottenCount > 0 {
                                    Button("Restore") { restoreForgottenNodes() }
                                        .buttonStyle(.plain)
                                        .font(HiveDesign.Typography.microLabelMedium)
                                        .foregroundStyle(Color.hiveAccent)
                                        .help("Restore \(forgottenCount) forgotten context node(s)")
                                }
                                Text("\(scopeNodes.count) tracked")
                                    .font(HiveDesign.Typography.microLabelMedium)
                                    .foregroundStyle(.tertiary.opacity(0.6))
                            }
                            ForEach(Array(scopeNodes.enumerated()), id: \.element.id) { _, node in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(scopeScoreColor(node.score))
                                        .frame(width: 5, height: 5)
                                    Text(node.label)
                                        .font(HiveDesign.Typography.buttonCaption)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text("\(Int(node.score * 100))%")
                                        .font(HiveDesign.Typography.monoMicroMedium)
                                        .foregroundStyle(.tertiary)
                                    Spacer()
                                    Button(action: { forgetScopeNode(node.id) }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: HiveDesign.Typography.sizeXS, weight: .bold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Forget this context — the AI won't see it")
                                }
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.secondary.opacity(0.06))
                        )
                    }

                    if !diag.contextSummary.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Context summary")
                                .font(HiveDesign.Typography.microLabel)
                                .foregroundStyle(.tertiary)
                            Text(diag.contextSummary)
                                .font(HiveDesign.Typography.monoMicro)
                                .foregroundStyle(.secondary)
                                .lineLimit(6)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.secondary.opacity(0.06))
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .onAppear { loadScopeNodes() }
            }
        }
    }


    // MARK: - Hot context controls

    /// Loads the live hot-memory scope (top scored entries) for the strip.
    func loadScopeNodes() {
        Task { @MainActor in
            scopeNodes = await state.hotMemory.currentContextScope()
            forgottenCount = await state.hotMemory.forgottenNodeIDList().count
        }
    }


    /// Forgets a single context node — the AI won't see it for the rest of the
    /// session (passive re-access can't resurrect it).
    func forgetScopeNode(_ id: String) {
        Task { @MainActor in
            await state.hotMemory.forgetNode(id: id)
            loadScopeNodes()
        }
    }


    /// Restores every forgotten context node — the user changed their mind.
    func restoreForgottenNodes() {
        Task { @MainActor in
            for id in await state.hotMemory.forgottenNodeIDList() {
                await state.hotMemory.unforgetNode(id: id)
            }
            loadScopeNodes()
        }
    }


    /// Color-codes a node's relevance: accent = hot, orange = cooling, gray = cold.
    func scopeScoreColor(_ score: Double) -> Color {
        if score > 0.7 { return Color.hiveAccent }
        if score > 0.3 { return HiveDesign.State.warning }
        return HiveDesign.Text.tertiary
    }


    func contextStat(_ label: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(HiveDesign.Typography.microLabelSecondary)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(HiveDesign.Typography.monoMicroMedium)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(label)
                .font(.system(size: HiveDesign.Typography.sizeXS))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }


    /// Compact provider label for the context scope strip (Dia diagnostics).
    /// Full labels live in `providerLabel` (footer); this is the short stat form.
    func providerDisplayLabel(_ raw: String) -> String {
        switch raw {
        case "appleFMF": return "Apple"
        case "mlx": return "MLX"
        case "byokRemote": return "Cloud"
        case "mock": return "Offline"
        case "error": return "Error"
        default: return raw.prefix(8).description
        }
    }


    /// Full provider label for the model footer. Maps the raw provider string
    /// (stored in `state.lastGeminiProvider`) to a human-readable status.
    var providerLabel: String {
        if state.isGeminiGenerating { return "generating..." }
        switch state.lastGeminiProvider {
        case "appleFMF": return "local · Apple on-device"
        case "mlx": return "local · MLX on-device"
        case "byokRemote": return "remote · connected"
        case "mock": return "local · offline"
        case "error": return "error"
        default: return "local · ready"
        }
    }
}
