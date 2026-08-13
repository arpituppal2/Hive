import SwiftUI

// MARK: - HTTPSOnlyBanner
//
// Chrome-style "connection is not secure" prompt for HTTPS-Only mode. Shown
// when the active page arrived over plaintext http while the mode is on and
// the host has no exception (in-page navigations can't be upgraded at the
// network layer, so this is the honest surface for them).

struct HTTPSOnlyBanner: View {
    @Environment(BrowserState.self) private var state

    private var notice: BrowserState.HTTPSOnlyNotice? { state.httpsOnlyNotice }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.slash.fill")
                .font(HiveDesign.Typography.bodySemiBold)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 1) {
                Text(notice?.title ?? "Connection is not secure")
                    .font(HiveDesign.Typography.smallLabelBold)
                Text(notice?.detail ?? "This page loaded over plaintext HTTP.")
                    .font(HiveDesign.Typography.buttonCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Use HTTPS") {
                state.useHTTPSNow()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.hiveAccent)

            Button("Load anyway") {
                state.allowPlaintextForCurrentHost()
            }
            .buttonStyle(.borderless)

            Button {
                state.dismissHTTPSOnlyNotice()
            } label: {
                Image(systemName: "xmark")
                    .font(HiveDesign.Typography.smallLabelBold)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss this warning")
            .accessibilityLabel("Dismiss HTTPS warning")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Divider().opacity(0.35) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(notice?.accessibilityLabel ?? "Connection is not secure")
    }
}
