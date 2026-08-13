import SwiftUI
import HiveCore

// MARK: - SiteSecurityPopover
//
// Safari-style site security panel. Shows when the user clicks the lock or
// info icon in the address bar. Displays connection security, certificate
// details, cookies, tracker blocking status, and Chrome-style per-site
// permission controls for the current page.

struct SiteSecurityPopover: View {
    @Environment(BrowserState.self) private var state

    private var url: URL? { state.activeModel?.url }
    private var isSecure: Bool { url?.scheme == "https" }
    private var host: String { url?.host ?? "Unknown" }
    /// Private tabs never persist per-site decisions; the controls are
    /// replaced with an honest note instead of appearing to work.
    private var isPrivateTab: Bool { state.activeTab?.isPrivate ?? false }
    /// The active tab's certificate failure, if any. The notice is already
    /// keyed to the active tab and cleared on every navigation attempt, so
    /// no host re-check is needed (a host check could wrongly suppress the
    /// warning while the address bar still shows the previous page).
    private var certError: BrowserState.CertificateErrorNotice? { state.certificateErrorNotice }
    private var isCertErrorActive: Bool { certError != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Header: security status
            HStack(spacing: HiveDesign.Space.md) {
                Image(systemName: isCertErrorActive ? "exclamationmark.shield.fill" : (isSecure ? "lock.fill" : "info.circle"))
                    .font(.system(size: HiveDesign.Icon.large, weight: .semibold))
                    .foregroundStyle(isCertErrorActive ? .red : (isSecure ? .green : .yellow))
                    .frame(width: 28, height: 28)
                    .background((isCertErrorActive ? Color.red : (isSecure ? Color.green : Color.yellow)).opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.md, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(isCertErrorActive ? "Connection is not trusted" : (isSecure ? "Connection is secure" : "Connection is not secure"))
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

                if let certNotice = certError {
                    securityRow(
                        icon: "exclamationmark.triangle.fill",
                        color: .red,
                        title: certNotice.title,
                        detail: "The certificate presented by this site could not be verified (error \(certNotice.code)). Do not enter passwords or payment details."
                    )

                    Divider().padding(.leading, 48)

                    Button(action: { state.proceedPastCertificateError() }) {
                        HStack(spacing: HiveDesign.Space.md) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: HiveDesign.Icon.medium))
                                .foregroundStyle(.red)
                            Text("Visit site anyway")
                                .font(.system(size: HiveDesign.Typography.sizeBody, weight: .medium))
                                .foregroundStyle(.red)
                            Spacer()
                        }
                        .padding(.horizontal, HiveDesign.Space.xl)
                        .padding(.vertical, HiveDesign.Space.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Allows this site to load despite its invalid certificate for this session.")
                } else {
                    securityRow(
                        icon: "clock.arrow.circlepath",
                        color: .blue,
                        title: "Certificate valid",
                        detail: "The site's certificate has been verified by a trusted authority."
                    )
                }

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

            // Permissions (Chrome-style per-site controls)
            VStack(alignment: .leading, spacing: 0) {
                Text("Permissions")
                    .font(HiveDesign.Typography.captionBold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, HiveDesign.Space.xl)
                    .padding(.top, HiveDesign.Space.lg)
                    .padding(.bottom, HiveDesign.Space.xs)

                if isPrivateTab {
                    HStack(spacing: HiveDesign.Space.md) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: HiveDesign.Icon.medium))
                            .foregroundStyle(.secondary)
                        Text("Private browsing doesn't save site permissions.")
                            .font(.system(size: HiveDesign.Typography.sizeMD))
                            .foregroundStyle(HiveDesign.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, HiveDesign.Space.xl)
                    .padding(.vertical, HiveDesign.Space.lg)
                } else {
                    ForEach(SitePermissionKind.allCases, id: \.self) { kind in
                        permissionRow(kind)
                        if kind != SitePermissionKind.allCases.last {
                            Divider().padding(.leading, 48)
                        }
                    }

                    Divider().padding(.leading, 48)

                    Button(action: { state.resetSitePermissions(forHost: host) }) {
                        HStack(spacing: HiveDesign.Space.md) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: HiveDesign.Icon.medium))
                                .frame(width: 20, height: 20)
                            Text("Reset permissions")
                                .font(.system(size: HiveDesign.Typography.sizeBody, weight: .medium))
                            Spacer()
                        }
                        .padding(.horizontal, HiveDesign.Space.xl)
                        .padding(.vertical, HiveDesign.Space.lg)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Actions
            VStack(spacing: 0) {
                Button(action: {
                    state.isSiteSecurityPanelOpen = false
                    state.openSiteSettings(focusHost: SiteMutePolicy.hostKey(for: url) ?? host.lowercased())
                }) {
                    HStack(spacing: HiveDesign.Space.md) {
                        Image(systemName: "globe.americas")
                            .font(.system(size: HiveDesign.Icon.medium))
                            .frame(width: 20, height: 20)
                        Text("Site Settings")
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

    /// One Chrome-style permission row: icon + label + Ask/Allow/Block menu.
    private func permissionRow(_ kind: SitePermissionKind) -> some View {
        HStack(spacing: HiveDesign.Space.md) {
            Image(systemName: kind.iconName)
                .font(.system(size: HiveDesign.Icon.medium))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)

            Text(kind.displayName)
                .font(.system(size: HiveDesign.Typography.sizeBody, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()

            Menu {
                Button("Ask") {
                    state.setSitePermission(.ask, forHost: host, kind: kind, isPrivate: isPrivateTab)
                }
                Button("Allow") {
                    state.setSitePermission(.allow, forHost: host, kind: kind, isPrivate: isPrivateTab)
                }
                Button("Block") {
                    state.setSitePermission(.deny, forHost: host, kind: kind, isPrivate: isPrivateTab)
                }
            } label: {
                Text(permissionLabel(for: kind))
                    .font(.system(size: HiveDesign.Typography.sizeMD, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("\(kind.displayName): \(permissionLabel(for: kind))")
        }
        .padding(.horizontal, HiveDesign.Space.xl)
        .padding(.vertical, HiveDesign.Space.md)
        .contentShape(Rectangle())
    }

    private func permissionLabel(for kind: SitePermissionKind) -> String {
        switch state.permissionState(forHost: host, kind: kind, isPrivate: isPrivateTab) {
        case .ask: return "Ask"
        case .allow: return "Allow"
        case .deny: return "Block"
        }
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
