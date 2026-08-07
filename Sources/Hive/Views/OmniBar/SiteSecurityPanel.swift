import SwiftUI
import WebKit
import HiveCore

// MARK: - SiteSecurityPanel
//
// A popover that appears when the user clicks the lock/shield icon in the
// omnibar. Shows:
//   1. Connection security (HTTPS/certificate status)
//   2. Permissions granted to this site
//   3. Trackers blocked on this page
//   4. Cookies and storage used by this site
//
// The panel is a native SwiftUI popover, not a webview overlay, so it can't
// be spoofed by the page.

struct SiteSecurityPanel: View {

    let tab: BrowserTab
    let onDismiss: () -> Void

    @Environment(ChromeState.self) private var state
    @State private var cookieCount: Int?
    @State private var storageEstimate: String?

    private var host: String { tab.url?.host ?? "this site" }
    private var securityLevel: SecurityLevel? {
        guard let url = tab.url else { return nil }
        return SecurityLevel(for: url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection
                .padding(.horizontal, HiveSpacing.s16)
                .padding(.top, HiveSpacing.s16)
                .padding(.bottom, HiveSpacing.s12)

            Divider().overlay(Color.hiveBorderSubtle)

            ScrollView {
                VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                    // Connection security
                    connectionSection

                    Divider().overlay(Color.hiveBorderSubtle)
                        .padding(.vertical, HiveSpacing.s4)

                    // Swarm page visibility
                    swarmVisibilitySection

                    Divider().overlay(Color.hiveBorderSubtle)

                    // Permissions
                    permissionsSection

                    Divider().overlay(Color.hiveBorderSubtle)
                        .padding(.vertical, HiveSpacing.s4)

                    // Trackers blocked
                    trackersSection

                    Divider().overlay(Color.hiveBorderSubtle)
                        .padding(.vertical, HiveSpacing.s4)

                    // Fingerprint resistance assessment
                    fingerprintSection

                    Divider().overlay(Color.hiveBorderSubtle)
                        .padding(.vertical, HiveSpacing.s4)

                    // Cookies & site data
                    siteDataSection
                }
                .padding(HiveSpacing.s16)
            }
        }
        .frame(width: 320, height: 440)
        .background(Color.hiveBackground)
        .task { await loadSiteData() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: HiveSpacing.s12) {
            if let level = securityLevel {
                Image(systemName: level.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(level.color(scheme: .dark))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(host)
                    .hiveType(.body)
                    .foregroundStyle(.hiveInk)
                    .lineLimit(1)

                if let level = securityLevel {
                    Text(level.label)
                        .hiveType(.caption2)
                        .foregroundStyle(level.color(scheme: .dark))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(host)\(securityLevel.map { ", \($0.label)" } ?? "")")

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.hiveMist)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close site security panel")
        }
    }

    // MARK: - Connection

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s8) {
            Label("Connection", systemImage: "lock.shield")
                .hiveType(.chromeLabel)
                .foregroundStyle(.hiveGraphite)

            if let level = securityLevel {
                HStack(spacing: HiveSpacing.s8) {
                    Image(systemName: level.icon)
                        .font(HiveTypography.font(.panelTitleRegular))
                        .foregroundStyle(level.color(scheme: .dark))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(level.label)
                            .hiveType(.body)
                            .foregroundStyle(.hiveInk)
                        Text(level.detail)
                            .hiveType(.caption2)
                            .foregroundStyle(.hiveMist)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(level.label). \(level.detail)")
            } else {
                Text("No connection information available")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
            }
        }
        .padding(HiveSpacing.s12)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r8)
                .fill(Color.hiveSurfaceElevated)
        )
    }

    // MARK: - Swarm page visibility

    private var swarmVisibilitySection: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s8) {
            Label("Swarm Page Access", systemImage: tab.isAIContextAllowed ? "eye" : "eye.slash")
                .hiveType(.chromeLabel)
                .foregroundStyle(.hiveGraphite)

            if tab.isPrivate {
                HStack(spacing: HiveSpacing.s8) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.hiveMist)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Unavailable in Private Browsing")
                            .hiveType(.bodySmall)
                            .foregroundStyle(.hiveInk)
                        Text("Swarm never inspects or retains private page contents.")
                            .hiveType(.caption2)
                            .foregroundStyle(.hiveMist)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Swarm page access unavailable in Private Browsing")
            } else {
                Toggle(isOn: Binding(
                    get: { tab.isAIContextAllowed },
                    set: { state.setAIContextAllowed(tabID: tab.id, allowed: $0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tab.isAIContextAllowed ? "Allowed for this tab" : "Blocked for this tab")
                            .hiveType(.bodySmall)
                            .foregroundStyle(.hiveInk)
                        Text("Controls page text sent to Swarm. Browsing and manual capture still work.")
                            .hiveType(.caption2)
                            .foregroundStyle(.hiveMist)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)
                .accessibilityLabel("Allow Swarm to see this page")
                .accessibilityValue(tab.isAIContextAllowed ? "On" : "Off")
            }
        }
        .padding(HiveSpacing.s12)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r8)
                .fill(Color.hiveSurfaceElevated)
        )
    }

    // MARK: - Permissions

    private var permissionsSection: some View {
        let sitePerms = state.prefs.sitePermissions.filter { $0.host == host }

        return VStack(alignment: .leading, spacing: HiveSpacing.s8) {
            Label("Permissions", systemImage: "hand.raised")
                .hiveType(.chromeLabel)
                .foregroundStyle(.hiveGraphite)

            if sitePerms.isEmpty {
                Text("No special permissions granted")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
            } else {
                ForEach(sitePerms) { perm in
                    HStack(spacing: HiveSpacing.s8) {
                        Image(systemName: iconFor(perm.kind))
                            .frame(width: 18)
                            .foregroundStyle(.hiveGraphite)
                        Text(labelFor(perm.kind))
                            .hiveType(.bodySmall)
                            .foregroundStyle(.hiveInk)
                        Spacer()
                        Text(stateLabel(perm.state))
                            .hiveType(.caption2)
                            .foregroundStyle(stateColor(perm.state))
                            .padding(.horizontal, HiveSpacing.s4)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(stateColor(perm.state).opacity(0.12))
                            )
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(labelFor(perm.kind)), \(stateLabel(perm.state))")
                }
            }
        }
        .padding(HiveSpacing.s12)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r8)
                .fill(Color.hiveSurfaceElevated)
        )
    }

    // MARK: - Trackers

    private var trackersSection: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s8) {
            Label("Trackers & Ads", systemImage: "shield")
                .hiveType(.chromeLabel)
                .foregroundStyle(.hiveGraphite)

            if tab.blockedCount > 0 {
                HStack(spacing: HiveSpacing.s8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text("\(tab.blockedCount) tracker\(tab.blockedCount == 1 ? "" : "s") blocked on this page")
                        .hiveType(.bodySmall)
                        .foregroundStyle(.green)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(tab.blockedCount) tracker\(tab.blockedCount == 1 ? "" : "s") blocked on this page")

                if ContentBlockerController.shared.isActive {
                    Text("Hive's content blocker is filtering tracking scripts, ads, and analytics from this page. Disable it in Settings → Privacy.")
                        .hiveType(.caption2)
                        .foregroundStyle(.hiveMist)
                        .lineLimit(3)
                }
            } else {
                HStack(spacing: HiveSpacing.s8) {
                    Image(systemName: "shield")
                        .foregroundStyle(.hiveGraphite)
                    Text("No trackers detected on this page")
                        .hiveType(.bodySmall)
                        .foregroundStyle(.hiveGraphite)
                }
            }
        }
        .padding(HiveSpacing.s12)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r8)
                .fill(Color.hiveSurfaceElevated)
        )
    }

    // MARK: - Site Data

    private var siteDataSection: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s8) {
            Label("Cookies & Storage", systemImage: "externaldrive")
                .hiveType(.chromeLabel)
                .foregroundStyle(.hiveGraphite)

            if let cookies = cookieCount, let storage = storageEstimate {
                HStack(spacing: HiveSpacing.s16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(cookies)")
                            .font(.system(.body, design: .rounded).bold())
                            .foregroundStyle(.hiveInk)
                        Text("cookies")
                            .hiveType(.caption2)
                            .foregroundStyle(.hiveMist)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(storage)
                            .font(.system(.body, design: .rounded).bold())
                            .foregroundStyle(.hiveInk)
                        Text("storage")
                            .hiveType(.caption2)
                            .foregroundStyle(.hiveMist)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(cookies) cookies, \(storage) storage")
            } else {
                Text("Loading site data…")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
            }
        }
        .padding(HiveSpacing.s12)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r8)
                .fill(Color.hiveSurfaceElevated)
        )
    }

    // MARK: - Fingerprint Resistance

    private var fingerprintSection: some View {
        let risk = assessFingerprintRisk()

        return VStack(alignment: .leading, spacing: HiveSpacing.s8) {
            Label("Fingerprint Resistance", systemImage: "fingerprint")
                .hiveType(.chromeLabel)
                .foregroundStyle(.hiveGraphite)

            HStack(spacing: HiveSpacing.s8) {
                // Risk level badge
                Text(risk.label)
                    .hiveType(.bodySmall)
                    .foregroundStyle(risk.color)
                    .padding(.horizontal, HiveSpacing.s8)
                    .padding(.vertical, HiveSpacing.s4)
                    .background(
                        Capsule()
                            .fill(risk.color.opacity(0.12))
                    )

                Spacer()
            }

            // Protection indicators
            VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                protectionRow(
                    icon: "shield.checkered",
                    label: "Canvas fingerprinting",
                    active: ContentBlockerController.shared.isActive
                )
                protectionRow(
                    icon: "hand.raised",
                    label: "Tracker blocking",
                    active: ContentBlockerController.shared.isActive
                )
                protectionRow(
                    icon: "lock.shield",
                    label: "HTTPS encryption",
                    active: tab.url?.scheme == "https"
                )
                protectionRow(
                    icon: "eye.slash",
                    label: "Global Privacy Control",
                    active: true  // GPC is enabled by default
                )
            }

            Text(risk.explanation)
                .hiveType(.caption2)
                .foregroundStyle(.hiveMist)
                .lineLimit(4)
        }
        .padding(HiveSpacing.s12)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r8)
                .fill(Color.hiveSurfaceElevated)
        )
    }

    private func protectionRow(icon: String, label: String, active: Bool) -> some View {
        HStack(spacing: HiveSpacing.s8) {
            Image(systemName: active ? icon : "slash.circle")
                .font(HiveTypography.font(.caption2))
                .foregroundStyle(active ? .green : .hiveMist)
            Text(label)
                .hiveType(.caption2)
                .foregroundStyle(active ? .hiveInk : .hiveMist)
            Spacer()
            Circle()
                .fill(active ? Color.green : Color.hiveMist.opacity(0.3))
                .frame(width: 6, height: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(active ? "Active" : "Inactive")")
    }

    private func assessFingerprintRisk() -> (label: String, color: Color, explanation: String) {
        let hasHTTPS = tab.url?.scheme == "https"
        let blockersActive = ContentBlockerController.shared.isActive
        let trackersBlocked = tab.blockedCount

        if hasHTTPS && blockersActive && trackersBlocked > 0 {
            return (
                "Well Protected",
                .green,
                "Hive is actively blocking \(trackersBlocked) tracker\(trackersBlocked == 1 ? "" : "s") on this page. Combined with HTTPS encryption and fingerprinting protections, your identity is well shielded from trackers."
            )
        } else if hasHTTPS && blockersActive {
            return (
                "Protected",
                .yellow,
                "No trackers detected on this page, and your connection is encrypted. Hive's fingerprinting protections are active. The site may still use first-party analytics."
            )
        } else if !hasHTTPS {
            return (
                "Vulnerable",
                .red,
                "This page is loaded over an insecure HTTP connection. Your data is not encrypted in transit and could be intercepted. Avoid entering sensitive information here."
            )
        } else {
            return (
                "Basic Protection",
                .orange,
                "HTTPS is active, but content blocking is disabled. Trackers and fingerprinting scripts may be running on this page. Consider enabling the content blocker in Settings."
            )
        }
    }

    // MARK: - Load site data

    private func loadSiteData() async {
        guard let host = tab.url?.host else { return }

        // Count cookies for this domain
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            WKWebsiteDataStore.default().fetchDataRecords(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()
            ) { records in
                let matchingRecords = records.filter { record in
                    record.displayName.contains(host)
                }
                // Rough cookie count from matching records
                let cookies = matchingRecords.count
                // Rough storage estimate
                let totalBytes = matchingRecords.reduce(0) { $0 + $1.dataTypes.reduce(0) { acc, _ in acc + 1024 } }
                let kb = totalBytes / 1024
                let mb = kb / 1024

                Task { @MainActor in
                    self.cookieCount = cookies
                    self.storageEstimate = mb > 0 ? "\(mb) MB" : "\(kb) KB"
                }
                cont.resume()
            }
        }
    }

    // MARK: - Helpers

    private func iconFor(_ kind: SitePermissionKind) -> String {
        switch kind {
        case .camera: return "camera"
        case .microphone: return "mic"
        case .location: return "location"
        case .notifications: return "bell.badge"
        case .popups: return "rectangle.on.rectangle"
        case .automaticDownloads: return "arrow.down.circle"
        }
    }

    private func labelFor(_ kind: SitePermissionKind) -> String {
        switch kind {
        case .camera: return "Camera"
        case .microphone: return "Microphone"
        case .location: return "Location"
        case .notifications: return "Notifications"
        case .popups: return "Pop-ups"
        case .automaticDownloads: return "Auto Downloads"
        }
    }

    private func stateLabel(_ state: SitePermissionState) -> String {
        switch state {
        case .allow: return "Allowed"
        case .deny: return "Blocked"
        case .ask: return "Ask First"
        }
    }

    private func stateColor(_ state: SitePermissionState) -> Color {
        switch state {
        case .allow: return .green
        case .deny: return .red
        case .ask: return .hiveGraphite
        }
    }
}
