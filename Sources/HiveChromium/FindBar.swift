import SwiftUI

// MARK: - FindBar
//
// Chrome-style find-in-page bar using window.find() JavaScript API.
// Highlights text in the active page and navigates between matches.
// No match count — CEF's executeJavaScript doesn't return values,
// and a fake/stale number is worse than honest simplicity.

struct FindBar: View {
    @Environment(ChromiumBrowserState.self) private var state
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
                .frame(width: 180)
                .onChange(of: localQuery) { _, newValue in
                    state.findQuery = newValue
                    if !newValue.isEmpty {
                        findInPage(newValue)
                    } else {
                        clearHighlights()
                    }
                }
                .onSubmit { findNext() }
                .onKeyPress(.escape) {
                    clearHighlights()
                    state.closeFindBar()
                    return .handled
                }

            HStack(spacing: 0) {
                Button(action: { findPrev() }) {
                    Image(systemName: "chevron.up")
                        .font(HiveDesign.Typography.captionBold)
                        .frame(width: 22, height: 22)
                        .background(localQuery.isEmpty ? Color.clear : Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(localQuery.isEmpty)

                Button(action: { findNext() }) {
                    Image(systemName: "chevron.down")
                        .font(HiveDesign.Typography.captionBold)
                        .frame(width: 22, height: 22)
                        .background(localQuery.isEmpty ? Color.clear : Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(localQuery.isEmpty)
            }

            Button(action: {
                clearHighlights()
                state.closeFindBar()
            }) {
                Image(systemName: "xmark")
                    .font(HiveDesign.Typography.captionBold)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        .onAppear { isFocused = true; localQuery = state.findQuery }
        .onDisappear { clearHighlights() }
    }

    // MARK: - Find Operations

    private func findInPage(_ query: String) {
        guard let model = state.activeModel else { return }
        model.executeJavaScript(buildFindJS(query, forward: true))
    }

    private func findNext() {
        guard !localQuery.isEmpty, let model = state.activeModel else { return }
        model.executeJavaScript(buildFindJS(localQuery, forward: true))
    }

    private func findPrev() {
        guard !localQuery.isEmpty, let model = state.activeModel else { return }
        model.executeJavaScript(buildFindJS(localQuery, forward: false))
    }

    private func clearHighlights() {
        guard let model = state.activeModel else { return }
        model.executeJavaScript("window.getSelection().removeAllRanges()")
    }

    /// window.find(text, caseSensitive, backwards, wrapAround, wholeWord, searchInFrames, showDialog)
    private func buildFindJS(_ query: String, forward: Bool) -> String {
        let escaped = query.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "window.find(\"\(escaped)\", false, \(!forward), true, false, true, false)"
    }
}
