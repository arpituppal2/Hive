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
                    ForEach(state.geminiMessages) { message in
                        GeminiMessageRow(message: message)
                            .id(message.id)
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
