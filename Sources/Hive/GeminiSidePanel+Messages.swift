//
//  GeminiSidePanel+Messages.swift
//  Hive
//
//  Carved out of GeminiSidePanel.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Message List | - Empty State
//

import SwiftUI
import HiveCore

// MARK: - GeminiSidePanel + Messages

@MainActor
extension GeminiSidePanel {


    // MARK: - Message List

    var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(state.geminiMessages.enumerated()), id: \.element.id) { index, message in
                        let msgID = message.id.uuidString
                        let isNew = !animatedMessageIDs.contains(msgID)
                        GeminiMessageRow(message: message)
                            .id(message.id)
                            .opacity(isNew ? 0 : 1)
                            .offset(y: isNew ? 12 : 0)
                            .onAppear {
                                if isNew {
                                    withAnimation(HiveDesign.Animation.entrance.delay(Double(index) * 0.04)) {
                                        animatedMessageIDs.insert(msgID)
                                    }
                                }
                            }
                    }

                    // Loading dots — shown while the AI is generating
                    if state.isGeminiGenerating {
                        thinkingDots
                            .id("thinking-\(state.geminiMessages.count)")
                    }

                    // Council verdict reveal — shown after generation completes
                    if let verdict = state.latestCouncilVerdict, !state.isGeminiGenerating {
                        verdictReveal(verdict)
                            .id("verdict-\(state.geminiMessages.count)")
                    }

                    Color.clear.frame(height: 1).id(bottomID)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .onAppear { scrollProxy = proxy }
            .onChange(of: state.geminiMessages.count) { _, _ in
                withAnimation(reduceMotion ? nil : .smooth) {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
            .onChange(of: lastMessageID) { _, _ in
                withAnimation(reduceMotion ? nil : .smooth) {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Thinking Dots

    private var thinkingDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(HiveDesign.Accent.primary.opacity(dotTick ? 0.6 : 0.3))
                    .frame(width: 6, height: 6)
                    .scaleEffect(dotTick ? 1.0 : 0.5)
                    .animation(
                        reduceMotion
                            ? .easeOut(duration: 0.01)
                            : .easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.2 * Double(i)),
                        value: dotTick
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: HiveDesign.Radius.xl, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .onAppear {
            guard !reduceMotion else { return }
            // Pulse the tick forever while this view exists
            Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                Task { @MainActor in dotTick.toggle() }
            }
        }
    }

    // MARK: - Verdict Reveal

    private func verdictReveal(_ verdict: CouncilVerdict) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: verdictIcon(for: verdict.confidence))
                    .font(HiveDesign.Typography.captionSemiBold)
                    .foregroundStyle(verdictColor(for: verdict.confidence))
                Text("Council Verdict")
                    .font(HiveDesign.Typography.sectionHeader)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(Int(verdict.confidence * 100))% confidence")
                    .font(HiveDesign.Typography.microLabelMedium)
                    .foregroundStyle(verdictColor(for: verdict.confidence))
            }
            Text(verdict.answer)
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(.primary)
                .lineLimit(4)
            if !verdict.agreements.isEmpty {
                Label("Agreed: \(verdict.agreements.joined(separator: ", "))", systemImage: "checkmark")
                    .font(HiveDesign.Typography.microLabelMedium)
                    .foregroundStyle(.green.opacity(0.7))
            }
            if !verdict.disagreements.isEmpty {
                Label("Disagreed: \(verdict.disagreements.joined(separator: ", "))", systemImage: "exclamationmark.triangle")
                    .font(HiveDesign.Typography.microLabelMedium)
                    .foregroundStyle(.yellow.opacity(0.7))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous)
                .fill(HiveDesign.Surface.level2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous)
                .stroke(verdictColor(for: verdict.confidence).opacity(0.3), lineWidth: 1)
        )
        .transition(
            reduceMotion
                ? .opacity
                : .scale(scale: 0.95).combined(with: .opacity)
        )
    }

    private func verdictIcon(for confidence: Double) -> String {
        if confidence >= 0.85 { return "checkmark.seal.fill" }
        if confidence >= 0.60 { return "checkmark.shield" }
        return "questionmark.diamond"
    }

    private func verdictColor(for confidence: Double) -> Color {
        if confidence >= 0.85 { return .green }
        if confidence >= 0.60 { return HiveDesign.Accent.primary }
        return HiveDesign.State.warning
    }


    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "sparkles")
                .font(HiveDesign.Typography.heroDisplay)
                .foregroundStyle(Color.hiveAccent.opacity(0.5))

            VStack(spacing: 4) {
                Text("Ask anything about this page")
                    .font(.system(size: HiveDesign.Typography.sizeHeading2, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Summarize, compare, or ask questions")
                    .font(HiveDesign.Typography.body)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                suggestionChip("Summarize this page", icon: "text.alignleft")
                suggestionChip("What are the key points?", icon: "list.number")
                suggestionChip("Compare to another tab", icon: "arrow.left.arrow.right")
                deepResearchChip
            }

            Spacer()
        }
    }


    func suggestionChip(_ text: String, icon: String) -> some View {
        Button(action: {
            input = text
            send()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: HiveDesign.Typography.sizeMD, weight: .medium))
                Text(text)
                    .font(HiveDesign.Typography.sidebarItem)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }        .buttonStyle(.plain)
    }
}
