import SwiftUI

// MARK: - PasswordCaptureChipView
//
// Chrome-style "Save password?" / "Update password?" chip. Appears
// bottom-center after a login form submits a credential the user hasn't
// saved (or has saved with a different password). Save/Update writes the
// credential to the Keychain — the explicit click is the consent; the
// "Never for this site" control records the host durably; the close button
// dismisses without saving.

struct PasswordCaptureChipView: View {
    @Environment(BrowserState.self) private var state
    let offer: PasswordCaptureOffer

    private var isUpdate: Bool {
        if case .update = offer.kind { return true }
        return false
    }

    var body: some View {
        HStack(spacing: HiveDesign.Space.lg) {
            Image(systemName: isUpdate ? "arrow.triangle.2.circlepath" : "lock.fill")
                .font(.system(size: HiveDesign.Icon.large, weight: .semibold))
                .foregroundStyle(Color.hiveAccent)
                .frame(width: 34, height: 34)
                .background(Color.hiveAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.md, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(isUpdate ? "Update password for \(offer.host)?" : "Save password for \(offer.host)?")
                    .font(.system(size: HiveDesign.Typography.sizeBody, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(offer.username)
                    .font(.system(size: HiveDesign.Typography.sizeMD))
                    .foregroundStyle(HiveDesign.Text.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                state.acceptPasswordCaptureOffer()
            } label: {
                Text(isUpdate ? "Update" : "Save")
                    .font(.system(size: HiveDesign.Typography.sizeBody, weight: .semibold))
                    .padding(.horizontal, HiveDesign.Space.lg)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(Color.hiveAccent)
            .keyboardShortcut(.defaultAction)

            Button {
                state.neverSavePasswordForHost(offer.host)
            } label: {
                Text("Never for this site")
                    .font(.system(size: HiveDesign.Typography.sizeBody, weight: .medium))
                    .padding(.horizontal, HiveDesign.Space.md)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .lineLimit(1)

            Button(action: { state.dismissPasswordCaptureOffer() }) {
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
        .frame(maxWidth: 560)
        .background(HiveDesign.Material.panel)
        .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous)
                .strokeBorder(HiveDesign.Surface.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: -6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isUpdate
            ? "Update password for \(offer.host)"
            : "Save password for \(offer.host)")
        .id(offer.id)
    }
}
