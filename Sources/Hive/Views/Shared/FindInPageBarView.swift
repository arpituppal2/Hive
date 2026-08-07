import SwiftUI
import HiveCore

// MARK: - FindInPageBarView
//
// A compact overlay bar rendered inside ChromeWebArea when find-in-page is active
// (⌘F). Shows a text field for the search query, match count ("3 of 12"), next/previous
// arrow buttons, and a close button. The bar sits at the top of the content area with a
// glass background. Dismissed by Esc, ⌘F again, or the close button.
//
// Design: 44pt height, warm glass material, pill-shaped text field, small SF Symbol arrows,
// monospaced match counter. Matches Safari's compact find bar density.

struct FindInPageBarView: View {

    @Environment(ChromeState.self) private var state

    @State private var localText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(HiveTypography.font(.caption1Medium))
                    .foregroundStyle(.hiveGraphite)
                TextField("Find in page", text: $localText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Find in page")
                    .accessibilityHint("Type text to search this page")
                    .hiveType(.body)
                    .focused($isFocused)
                    .onChange(of: localText) { _, newValue in
                        state.findInPageText = newValue
                        if !newValue.isEmpty {
                            state.requestFindInPage()
                        } else {
                            state.clearFindInPage()
                        }
                    }
                    .onSubmit {
                        state.findNextInPage()
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r6)
                    .fill(Color.hiveSurface.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: HiveRadius.r6)
                    .stroke(Color.hiveBorderSubtle, lineWidth: 0.5)
            )
            .frame(width: 220)

            // Match counter
            if state.findInPageMatchCount > 0 {
                Text("\(state.findInPageCurrentMatch) of \(state.findInPageMatchCount)")
                    .hiveType(.chromeLabel)
                    .foregroundStyle(.hiveGraphite)
                    .monospacedDigit()
                    .frame(minWidth: 44, alignment: .center)
                    .accessibilityLabel("\(state.findInPageCurrentMatch) of \(state.findInPageMatchCount) matches")
            } else if !localText.isEmpty {
                Text("0 matches")
                    .hiveType(.chromeLabel)
                    .foregroundStyle(.hiveGraphite)
                    .frame(minWidth: 44, alignment: .center)
                    .accessibilityLabel("No matches")
            }

            // Previous match
            Button {
                state.findPreviousInPage()
            } label: {
                Image(systemName: "chevron.up")
                    .font(HiveTypography.font(.caption1Medium))
                    .foregroundStyle(state.findInPageMatchCount > 0 ? .hiveInk : .hiveGraphite.opacity(0.4))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(state.findInPageMatchCount == 0)
            .accessibilityLabel("Previous match")
            .help("Previous match")

            // Next match
            Button {
                state.findNextInPage()
            } label: {
                Image(systemName: "chevron.down")
                    .font(HiveTypography.font(.caption1Medium))
                    .foregroundStyle(state.findInPageMatchCount > 0 ? .hiveInk : .hiveGraphite.opacity(0.4))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(state.findInPageMatchCount == 0)
            .accessibilityLabel("Next match")
            .help("Next match")

            // Close
            Button {
                state.dismissFindInPage()
            } label: {
                Image(systemName: "xmark")
                    .font(HiveTypography.font(.captionMedium))
                    .foregroundStyle(.hiveGraphite)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close find in page")
            .help("Close find (Esc)")
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r8))
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.r8)
                .stroke(Color.hiveBorderSubtle, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            localText = state.findInPageText
            isFocused = true
        }
        .onChange(of: state.findInPageText) { _, newValue in
            if localText != newValue {
                localText = newValue
            }
        }
        // Esc key dismisses the find bar (Safari/Chrome/Arc convention).
        .onKeyPress(.escape) {
            state.dismissFindInPage()
            return .handled
        }
    }
}
