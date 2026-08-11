import SwiftUI

// MARK: - AutofillChipView
//
// Chrome/Safari-style "Use saved password?" chip. Appears bottom-center when
// the autofill probe detects a login form on the visible page and saved
// credentials match the host. Selecting a credential fills the form (always
// an explicit click); the close button dismisses and stops the nags for the
// host this session.

struct AutofillChipView: View {
    @Environment(BrowserState.self) private var state
    let suggestion: AutofillSuggestion

    var body: some View {
        HStack(spacing: HiveDesign.Space.lg) {
            Image(systemName: "key.fill")
                .font(.system(size: HiveDesign.Icon.large, weight: .semibold))
                .foregroundStyle(Color.hiveAccent)
                .frame(width: 34, height: 34)
                .background(Color.hiveAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.md, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Use saved password?")
                    .font(.system(size: HiveDesign.Typography.sizeBody, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(suggestion.host)
                    .font(.system(size: HiveDesign.Typography.sizeMD))
                    .foregroundStyle(HiveDesign.Text.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if suggestion.matches.count == 1, let only = suggestion.matches.first {
                Button {
                    state.fillAutofill(suggestion: suggestion, credential: only)
                } label: {
                    Text("Use \\(only.username)")
                        .font(.system(size: HiveDesign.Typography.sizeBody, weight: .semibold))
                        .padding(.horizontal, HiveDesign.Space.lg)
                        .padding(.vertical, 7)
                        .lineLimit(1)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color.hiveAccent)
                .keyboardShortcut(.defaultAction)
            } else {
                Menu {
                    ForEach(suggestion.matches) { credential in
                        Button(credential.username) {
                            state.fillAutofill(suggestion: suggestion, credential: credential)
                        }
                    }
                } label: {
                    Text("Choose account…")
                        .font(.system(size: HiveDesign.Typography.sizeBody, weight: .semibold))
                        .padding(.horizontal, HiveDesign.Space.lg)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color.hiveAccent)
            }

            Button(action: { state.dismissAutofillSuggestion() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: HiveDesign.Icon.large))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Not now")
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, HiveDesign.Space.xl)
        .padding(.vertical, HiveDesign.Space.md)
        .frame(maxWidth: 520)
        .background(HiveDesign.Material.panel)
        .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous)
                .strokeBorder(HiveDesign.Surface.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: -6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Use saved password for \\(suggestion.host)")
        .id(suggestion.id)
    }
}
