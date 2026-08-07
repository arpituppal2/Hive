import SwiftUI

// MARK: - TranslateBar
//
// Chrome-style translate prompt that appears in the address bar area.
// Translates pages in-place by navigating through Google Translate's proxy,
// matching how Chrome and Edge handle built-in translation.

struct TranslateBar: View {
    @Environment(ChromiumBrowserState.self) private var state

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "character.bubble")
                .font(HiveDesign.Typography.bodySemiBold)
                .foregroundStyle(Color.hiveAccent)

            Text("This page is in \(state.translateBar?.sourceLanguage ?? "another language").")
                .font(HiveDesign.Typography.bodyMedium)

            Spacer()

            Button("Translate to \(state.translateBar?.targetLanguage ?? "English")") {
                state.translateCurrentPage()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.hiveAccent)

            Button("Never") {
                state.dismissTranslateBar()
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Divider().opacity(0.35) }
    }
}
