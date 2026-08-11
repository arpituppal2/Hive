import SwiftUI
import HiveCore

// MARK: - SiteSettingsSheet
//
// Per-site Settings hub (Chrome chrome://settings/content/all parity): one
// searchable list of every host with a remembered decision — zoom, mute,
// HTTPS-Only exception, or permission grant. Rows expand inline to edit each
// decision; a per-host reset returns the site to defaults.

struct SiteSettingsSheet: View {
    @Environment(BrowserState.self) private var state
    @State private var searchText = ""
    @State private var expandedHosts: Set<String> = []
    /// Host pending a destructive "Reset all site settings" confirmation.
    @State private var resetHost: String? = nil
    /// Host pending a destructive "Delete data for this site" confirmation.
    @State private var deleteDataHost: String? = nil
    /// The host scrolled to when the sheet opens from the Site Security
    /// popover (read once in onAppear).
    @State private var initialFocusHost: String? = nil

    private var entries: [SiteSettingsEntry] {
        let all = state.siteSettingsEntries()
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter { $0.host.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchField
            Divider()
            content
        }
        .frame(width: 480, height: 520)
        .background(HiveDesign.Material.panel)
        .onAppear {
            // Capture the focus host once; scrolling after the list exists.
            initialFocusHost = state.siteSettingsFocusHost
            if let host = state.siteSettingsFocusHost {
                expandedHosts.insert(host)
            }
            DispatchQueue.main.async {
                if let host = state.siteSettingsFocusHost {
                    state.siteSettingsFocusHost = nil
                }
            }
        }
        .confirmationDialog(
            "Reset settings for \(resetHost ?? "")?",
            isPresented: Binding(
                get: { resetHost != nil },
                set: { if !$0 { resetHost = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                if let host = resetHost {
                    state.resetAllSiteSettings(forHost: host)
                }
                resetHost = nil
            }
            Button("Cancel", role: .cancel) { resetHost = nil }
        } message: {
            Text("This returns zoom, mute, HTTPS-Only, and permission decisions for this site to their defaults. Browsing history is not affected.")
        }
        .confirmationDialog(
            "Delete data for \(deleteDataHost ?? "")?",
            isPresented: Binding(
                get: { deleteDataHost != nil },
                set: { if !$0 { deleteDataHost = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let host = deleteDataHost {
                    state.deleteSiteData(forHost: host)
                }
                deleteDataHost = nil
            }
            Button("Cancel", role: .cancel) { deleteDataHost = nil }
        } message: {
            Text("This removes browsing history and cookies for this site. Browser cache is shared and can't be removed per site.")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: HiveDesign.Space.md) {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: HiveDesign.Icon.medium, weight: .semibold))
                .foregroundStyle(HiveDesign.Accent.primary)
                .frame(width: 26, height: 26)
                .background(HiveDesign.Accent.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.md, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Site Settings")
                    .font(.system(size: HiveDesign.Typography.sizeBody, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Per-site zoom, mute, and permissions")
                    .font(.system(size: HiveDesign.Typography.sizeMD))
                    .foregroundStyle(HiveDesign.Text.secondary)
            }

            Spacer()

            Button(action: { state.isSiteSettingsPanelOpen = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: HiveDesign.Icon.large))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, HiveDesign.Space.xl)
        .padding(.top, HiveDesign.Space.xl)
        .padding(.bottom, HiveDesign.Space.lg)
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: HiveDesign.Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: HiveDesign.Typography.sizeBody))
                .foregroundStyle(.secondary)
            TextField("Filter sites", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: HiveDesign.Typography.sizeBody))
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, HiveDesign.Space.md)
        .padding(.vertical, HiveDesign.Space.xs)
        .background(HiveDesign.Surface.level1)
        .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.md, style: .continuous))
        .padding(.horizontal, HiveDesign.Space.xl)
        .padding(.vertical, HiveDesign.Space.md)
        .accessibilityLabel("Filter sites")
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if entries.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                List {
                    ForEach(entries) { entry in
                        row(entry)
                            .id(entry.host)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .onAppear {
                    if let host = initialFocusHost {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(HiveDesign.Animation.springQuick) {
                                proxy.scrollTo(host, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: HiveDesign.Space.md) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "globe" : "magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty ? "No site settings yet" : "No sites match “\(searchText)”")
                .font(.system(size: HiveDesign.Typography.sizeBody, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Zoom, mute, HTTPS-Only exceptions, and permission decisions appear here as you make them.")
                .font(.system(size: HiveDesign.Typography.sizeMD))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, HiveDesign.Space.xl)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Row

    private func row(_ entry: SiteSettingsEntry) -> some View {
        let isExpanded = expandedHosts.contains(entry.host)
        return VStack(spacing: 0) {
            Button(action: {
                withAnimation(HiveDesign.Animation.springQuick) {
                    if isExpanded {
                        expandedHosts.remove(entry.host)
                    } else {
                        expandedHosts.insert(entry.host)
                    }
                }
            }) {
                HStack(spacing: HiveDesign.Space.md) {
                    Image(systemName: "globe")
                        .font(.system(size: HiveDesign.Icon.medium))
                        .foregroundStyle(HiveDesign.Accent.primary)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.host)
                            .font(.system(size: HiveDesign.Typography.sizeBody, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(entry.summary)
                            .font(.system(size: HiveDesign.Typography.sizeMD))
                            .foregroundStyle(HiveDesign.Text.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(HiveDesign.Typography.captionBold)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, HiveDesign.Space.lg)
                .padding(.vertical, HiveDesign.Space.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(entry.host), \(entry.summary)")

            if isExpanded {
                detail(entry)
                    .padding(.horizontal, HiveDesign.Space.lg)
                    .padding(.bottom, HiveDesign.Space.lg)
                    .transition(.opacity)
            }
        }
    }

    // MARK: Expanded detail

    private func detail(_ entry: SiteSettingsEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().padding(.bottom, HiveDesign.Space.sm)

            // Zoom
            HStack(spacing: HiveDesign.Space.md) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: HiveDesign.Icon.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                Text("Zoom")
                    .font(.system(size: HiveDesign.Typography.sizeBody, weight: .medium))
                Spacer()
                Menu {
                    ForEach(BrowserState.zoomLadder, id: \.self) { pct in
                        Button("\(Int(pct))%") { state.setSiteZoom(forHost: entry.host, percent: pct) }
                    }
                    Divider()
                    Button("Default (100%)") { state.resetSiteZoom(forHost: entry.host) }
                } label: {
                    Text(entry.zoomPercent.map { "\($0)%" } ?? "Default")
                        .font(.system(size: HiveDesign.Typography.sizeMD, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("Zoom for \(entry.host)")
            }
            .padding(.vertical, HiveDesign.Space.md)

            Divider().padding(.leading, 36)

            // Mute
            HStack(spacing: HiveDesign.Space.md) {
                Image(systemName: "speaker.slash.fill")
                    .font(.system(size: HiveDesign.Icon.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                Text("Mute site")
                    .font(.system(size: HiveDesign.Typography.sizeBody, weight: .medium))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { entry.isMuted },
                    set: { _ in state.toggleSiteMute(host: entry.host) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityLabel("Mute \(entry.host)")
            }
            .padding(.vertical, HiveDesign.Space.md)

            Divider().padding(.leading, 36)

            // HTTPS-Only exception
            HStack(spacing: HiveDesign.Space.md) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: HiveDesign.Icon.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Allow HTTP")
                        .font(.system(size: HiveDesign.Typography.sizeBody, weight: .medium))
                    if !state.isHTTPSOnlyEnabled {
                        Text("HTTPS-Only is off — this exception has no effect until it's turned on")
                            .font(.system(size: HiveDesign.Typography.sizeSM))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { entry.isHTTPSException },
                    set: { _ in state.toggleHTTPSException(forHost: entry.host) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityLabel("Allow HTTP for \(entry.host)")
            }
            .padding(.vertical, HiveDesign.Space.md)

            // Permissions
            ForEach(SitePermissionKind.allCases, id: \.self) { kind in
                Divider().padding(.leading, 36)
                permissionRow(entry, kind: kind)
            }

            Divider().padding(.vertical, HiveDesign.Space.sm)

            Button(action: { resetHost = entry.host }) {
                HStack(spacing: HiveDesign.Space.md) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: HiveDesign.Icon.medium))
                    Text("Reset all site settings")
                        .font(.system(size: HiveDesign.Typography.sizeBody, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(.red)
                .padding(.vertical, HiveDesign.Space.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset settings for \(entry.host)")

            Button(action: { deleteDataHost = entry.host }) {
                HStack(spacing: HiveDesign.Space.md) {
                    Image(systemName: "trash")
                        .font(.system(size: HiveDesign.Icon.medium))
                    Text("Delete data for this site")
                        .font(.system(size: HiveDesign.Typography.sizeBody, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(.red)
                .padding(.vertical, HiveDesign.Space.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete browsing data for \(entry.host)")
        }
    }

    private func permissionRow(_ entry: SiteSettingsEntry, kind: SitePermissionKind) -> some View {
        HStack(spacing: HiveDesign.Space.md) {
            Image(systemName: kind.iconName)
                .font(.system(size: HiveDesign.Icon.medium))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
            Text(kind.displayName)
                .font(.system(size: HiveDesign.Typography.sizeBody, weight: .medium))
            Spacer()
            Menu {
                Button("Ask") { state.setSitePermission(.ask, forHost: entry.host, kind: kind, isPrivate: false) }
                Button("Allow") { state.setSitePermission(.allow, forHost: entry.host, kind: kind, isPrivate: false) }
                Button("Block") { state.setSitePermission(.deny, forHost: entry.host, kind: kind, isPrivate: false) }
            } label: {
                Text(permissionLabel(entry, kind: kind))
                    .font(.system(size: HiveDesign.Typography.sizeMD, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("\(kind.displayName) for \(entry.host): \(permissionLabel(entry, kind: kind))")
        }
        .padding(.vertical, HiveDesign.Space.md)
    }

    private func permissionLabel(_ entry: SiteSettingsEntry, kind: SitePermissionKind) -> String {
        switch state.permissionState(forHost: entry.host, kind: kind, isPrivate: false) {
        case .ask: return "Ask"
        case .allow: return "Allow"
        case .deny: return "Block"
        }
    }
}
