import SwiftUI

// MARK: - FindBar
//
// Chrome-style find-in-page bar using window.find() JavaScript API.
// Highlights text in the active page and navigates between matches.
// The page reports a live match counter back over the console bridge
// (`HIVE_FIND|<current>|<total>`), so the bar shows "3/12" or
// "No matches" like Chrome and Safari. All find execution lives on
// BrowserState so the ⌘G / ⇧⌘G menu items share the exact same path.

struct FindBar: View {
    @Environment(BrowserState.self) private var state
    @State private var localQuery: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(HiveDesign.Typography.smallLabelBold)

            TextField("Find in page", text: $localQuery)
                .textFieldStyle(.plain)
                .font(HiveDesign.Typography.body)
                .focused($isFocused)
                .frame(width: 160)
                .onChange(of: localQuery) { _, newValue in
                    if !newValue.isEmpty {
                        state.findInPage(newValue)
                    } else {
                        state.clearFindHighlights()
                    }
                }
                .onSubmit { state.findNextInPage() }
                .onKeyPress(.upArrow) {
                    // Chrome convention: ↑/↓ inside the find field move
                    // between matches.
                    state.findPreviousInPage()
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    state.findNextInPage()
                    return .handled
                }
                .onKeyPress(.escape) {
                    state.clearFindHighlights()
                    state.closeFindBar()
                    return .handled
                }

            // Live match counter — "3/12" or "No matches" (Chrome/Safari).
            if let matchText = state.findMatchText, !localQuery.isEmpty {
                Text(matchText)
                    .font(HiveDesign.Typography.caption)
                    .foregroundStyle(matchText == "No matches" ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                    .monospacedDigit()
                    .fixedSize()
                    .accessibilityLabel(matchText == "No matches" ? "No matches in page" : "\(matchText) matches")
            }

            HStack(spacing: 0) {
                Button(action: { state.findPreviousInPage() }) {
                    Image(systemName: "chevron.up")
                        .font(HiveDesign.Typography.captionBold)
                        .frame(width: 22, height: 22)
                        .background(localQuery.isEmpty ? Color.clear : Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(localQuery.isEmpty)
                .help("Previous match (⇧⌘G)")

                Button(action: { state.findNextInPage() }) {
                    Image(systemName: "chevron.down")
                        .font(HiveDesign.Typography.captionBold)
                        .frame(width: 22, height: 22)
                        .background(localQuery.isEmpty ? Color.clear : Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(localQuery.isEmpty)
                .help("Next match (⌘G)")
            }

            // Aa "Match case" toggle (Chrome find-bar parity).
            Button(action: { state.toggleFindCaseSensitivity() }) {
                Text("Aa")
                    .font(HiveDesign.Typography.body)
                    .foregroundStyle(state.findMatchCaseSensitive ? Color.hiveAccent : Color.secondary)
                    .frame(width: 24, height: 22)
                    .background(state.findMatchCaseSensitive ? Color.hiveAccent.opacity(0.14) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(localQuery.isEmpty)
            .help(state.findMatchCaseSensitive ? "Match case on — click to ignore case" : "Match case off — click to match case")

            Button(action: {
                state.clearFindHighlights()
                state.closeFindBar()
            }) {
                Image(systemName: "xmark")
                    .font(HiveDesign.Typography.captionBold)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Close find bar (Esc)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        .onAppear {
            isFocused = true
            localQuery = state.findQuery
            state.findMatchText = nil
        }
        .onDisappear { state.clearFindHighlights() }
    }
}
