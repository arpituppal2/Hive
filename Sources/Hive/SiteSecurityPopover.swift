import SwiftUI

// MARK: - SiteSecurityPopover
//
// Safari-style site security panel. Shows when the user clicks the lock or
// info icon in the address bar. Displays connection security, certificate
// details, cookies, and tracker blocking status for the current page.

struct SiteSecurityPopover: View {
    @Environment(BrowserState.self) private var state

    private var url: URL? { state.activeModel?.url }
    private var isSecure: Bool { url?.scheme == "https" }
    private var host: String { url?.host ?? "Unknown" }

    var body: some View {
        VStack(spacing: 0) {
            // Header: security status
            HStack(spacing: HiveDesign.Space.md) {
                Image(systemName: isSecure ? "lock.fill" : "info.circle")
                    .font(.system(size: HiveDesign.Icon.large, weight: .semibold))
                    .foregroundStyle(isSecure ? .green : .yellow)
                    .frame(width: 28, height: 28)
                    .background((isSecure ? Color.green : Color.yellow).opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.md, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(isSecure ? "Connection is secure" : "Connection is not secure")
                        .font(.system(size: HiveDesign.Typography.sizeBody, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(host)
                        .font(.system(size: HiveDesign.Typography.sizeMD))
                        .foregroundStyle(HiveDesign.Text.secondary)
                }

                Spacer()

                Button(action: { state.isSiteSecurityPanelOpen = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: HiveDesign.Icon.large))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, HiveDesign.Space.xl)
            .padding(.top, HiveDesign.Space.xl)
            .padding(.bottom, HiveDesign.Space.lg)

            Divider()

            // Details
            VStack(spacing: 0) {
                securityRow(
                    icon: "checkmark.shield.fill",
                    color: .green,
                    title: "Encrypted connection",
                    detail: "Data sent to and from this site is encrypted using TLS."
                )

                Divider().padding(.leading, 48)

                securityRow(
                    icon: "clock.arrow.circlepath",
                    color: .blue,
                    title: "Certificate valid",
                    detail: "The site's certificate has been verified by a trusted authority."
                )

                Divider().padding(.leading, 48)

                securityRow(
                    icon: "hand.raised.fill",
                    color: Color.hiveAccent,
                    title: "\(state.trackerBlockedCount) trackers blocked",
                    detail: "Trackers from advertising, analytics, and social media are prevented from profiling you."
                )

                if !isSecure {
                    Divider().padding(.leading, 48)

                    securityRow(
                        icon: "exclamationmark.triangle.fill",
                        color: .yellow,
                        title: "Not private",
                        detail: "Information you send to this site (passwords, messages, credit cards) is not encrypted."
                    )
                }
            }

            Divider()

            // Actions
            VStack(spacing: 0) {
                Button(action: { state.openPrivacyReport() }) {
                    HStack(spacing: HiveDesign.Space.md) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: HiveDesign.Icon.medium))
                            .frame(width: 20, height: 20)
                        Text("Privacy Report")
                            .font(.system(size: HiveDesign.Typography.sizeBody, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(HiveDesign.Typography.captionBold)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, HiveDesign.Space.xl)
                    .padding(.vertical, HiveDesign.Space.lg)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()

                Button(action: {
                    state.isSiteSecurityPanelOpen = false
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url?.absoluteString ?? "", forType: .string)
                }) {
                    HStack(spacing: HiveDesign.Space.md) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: HiveDesign.Icon.medium))
                            .frame(width: 20, height: 20)
                        Text("Copy URL")
                            .font(.system(size: HiveDesign.Typography.sizeBody, weight: .medium))
                        Spacer()
                        Text(String((url?.absoluteString ?? "").prefix(40)) + ((url?.absoluteString.count ?? 0) > 40 ? "…" : ""))
                            .font(.system(size: HiveDesign.Typography.sizeSM))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, HiveDesign.Space.xl)
                    .padding(.vertical, HiveDesign.Space.lg)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 320)
        .background(HiveDesign.Material.panel)
        .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 5)
    }

    private func securityRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: HiveDesign.Space.lg) {
            Image(systemName: icon)
                .font(.system(size: HiveDesign.Icon.medium))
                .foregroundStyle(color)
                .frame(width: 20, height: 20)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: HiveDesign.Typography.sizeBody, weight: .medium))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.system(size: HiveDesign.Typography.sizeMD))
                    .foregroundStyle(HiveDesign.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, HiveDesign.Space.xl)
        .padding(.vertical, HiveDesign.Space.lg)
    }
}
