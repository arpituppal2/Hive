import SwiftUI

// MARK: - SafeBrowsingWarningView
//
// Chrome-style full-page warning for dangerous sites.

struct SafeBrowsingWarningView: View {
    @Environment(ChromiumBrowserState.self) private var state
    @State private var showDetails: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(.red)

            VStack(spacing: 8) {
                Text("Deceptive site ahead")
                    .font(HiveDesign.Typography.headingXL)

                Text("Attackers on \(state.safeBrowsingWarning?.url.host ?? "this site") might trick you into doing something dangerous like installing software or revealing personal information.")
                    .font(HiveDesign.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            HStack(spacing: 12) {
                Button("Back to safety") {
                    state.dismissSafeBrowsingWarning()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button(showDetails ? "Hide details" : "Advanced") {
                    showDetails.toggle()
                }
                .buttonStyle(.borderless)

                if showDetails {
                    Text("Chrome's Safe Browsing detected a deceptive site at \(state.safeBrowsingWarning?.url.absoluteString ?? ""). Visiting this page may put your personal information at risk.")
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: 420)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.92))
    }
}
