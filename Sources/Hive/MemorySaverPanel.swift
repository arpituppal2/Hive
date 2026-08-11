import SwiftUI
import HiveCore

// MARK: - MemorySaverPanel
//
// Chrome-parity performance surface: see every tab's sleep state at a glance,
// manually put tabs to sleep or wake them, and toggle the automatic Memory
// Saver pass. Hibernation uses the same lifecycle as the periodic pass
// (HibernationAdapter-approved, private/pinned/essential/active/MRU guards
// respected), so a manual sleep can never cross the safety boundary.

struct MemorySaverPanel: View {
    @Environment(BrowserState.self) private var state
    @State private var query: String = ""

    private var visibleTabs: [BrowserState.Tab] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all = state.tabs
        guard !q.isEmpty else { return all }
        return all.filter { tab in
            tab.model.title.lowercased().contains(q)
            || (tab.model.url?.host?.lowercased().contains(q) ?? false)
        }
    }

    private var sleepingCount: Int {
        state.tabs.filter(\.isHibernated).count
    }

    private var wakeableCount: Int { sleepingCount }

    private var sleepableCount: Int {
        state.tabs.filter { !$0.isHibernated && canManuallySleep($0) }.count
    }

    /// Same derivation as the auto pass: an in-flight download still owns its
    /// browser context, so a tab hosting one must never be torn down.
    private var activeDownloadTabIDs: Set<String> {
        Set(state.downloads.lazy
            .filter { !$0.isComplete && !$0.isCanceled && !$0.isInterrupted }
            .compactMap(\.originatingTabID))
    }

    /// Mirrors the auto-pass guards: private, pinned, and essential tabs, the
    /// active tab, split panes, media-playing tabs, and tabs with active
    /// downloads never sleep. MRU keepalive is deliberately NOT enforced here
    /// — a user clicking Sleep on a row is explicit intent, and the bulk
    /// action applies the MRU guard on top.
    private func canManuallySleep(_ tab: BrowserState.Tab) -> Bool {
        guard !tab.isPrivate, !tab.isHibernated,
              !tab.isPinned, !tab.isEssential,
              tab.id != state.activeTabID,
              tab.id != state.splitSecondaryTabID,
              !state.mediaPlayingTabIDs.contains(tab.id),
              !activeDownloadTabIDs.contains(tab.id),
              HibernationAdapter.effectiveWakeURL(
                  currentURL: tab.model.url,
                  savedURL: tab.savedURL
              ) != nil
        else { return false }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "leaf.fill")
                    .font(HiveDesign.Typography.panelTitleMedium)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Memory Saver")
                        .font(HiveDesign.Typography.subHeadingBold)
                    Text(statsLine)
                        .font(HiveDesign.Typography.buttonCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: { state.isMemorySaverPanelOpen = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(HiveDesign.Typography.bodyLarge)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            // Actions row
            @Bindable var state = state
            HStack(spacing: 8) {
                Button(action: sleepAllManual) {
                    Label("Sleep Inactive", systemImage: "moon.zzz.fill")
                        .font(HiveDesign.Typography.smallLabelBold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(HiveDesign.Accent.primary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(sleepableCount == 0)
                .help(sleepableCount == 0 ? "No tabs can be slept right now" : "Put all eligible tabs to sleep")

                Button(action: wakeAll) {
                    Label("Wake All", systemImage: "sun.max.fill")
                        .font(HiveDesign.Typography.smallLabelBold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(wakeableCount == 0)

                Spacer()

                Toggle("Auto", isOn: $state.isMemorySaverEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .help("Automatically sleep inactive tabs (Settings → Performance)")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(HiveDesign.Typography.sidebarItem)
                TextField("Filter tabs...", text: $query)
                    .textFieldStyle(.plain)
                    .font(HiveDesign.Typography.body)
                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(HiveDesign.Surface.level1)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            // List
            if visibleTabs.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(visibleTabs) { tab in
                            MemoryTabRow(tab: tab, canSleep: canManuallySleep(tab))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(HiveDesign.Material.panel)
        .frame(width: 460, height: 440)
    }

    private var statsLine: String {
        let total = state.tabs.count
        return "\(sleepingCount) of \(total) tab\(total == 1 ? "" : "s") sleeping"
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No matching tabs")
                .font(HiveDesign.Typography.bodyMedium)
                .foregroundStyle(.secondary)
            Text("Try a different title or host")
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
    }

    // MARK: - Actions

    private func sleepAllManual() {
        // The bulk action mirrors the auto pass, which keeps the most-recently
        // used tabs' renderers alive for fast switching. Row-level Sleep
        // remains available for explicit intent on any eligible tab.
        let targets = state.tabs.filter {
            canManuallySleep($0) && !state.mruTabIDs.contains($0.id)
        }
        for tab in targets {
            state.hibernateTab(tab)
        }
        if !targets.isEmpty { state.scheduleAutosave() }
    }

    private func wakeAll() {
        let targets = state.tabs.filter(\.isHibernated)
        for tab in targets {
            state.wakeTab(tab)
        }
    }
}

// MARK: - MemoryTabRow

private struct MemoryTabRow: View {
    let tab: BrowserState.Tab
    let canSleep: Bool
    @Environment(BrowserState.self) private var state
    @State private var isHovered: Bool = false

    private var isActive: Bool { state.activeTabID == tab.id }

    var body: some View {
        HStack(spacing: 10) {
            // Favicon / moon for sleeping
            if tab.isHibernated {
                Image(systemName: "moon.zzz.fill")
                    .font(HiveDesign.Typography.panelTitle)
                    .foregroundStyle(.green)
                    .frame(width: 24, height: 24)
                    .background(Color.green.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else if tab.model.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 24, height: 24)
            } else if let favicon = tab.model.faviconURL {
                FaviconImage(url: favicon)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "globe")
                    .font(HiveDesign.Typography.panelTitle)
                    .foregroundStyle(HiveDesign.Text.tertiary)
                    .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(tab.model.title.isEmpty ? (tab.model.url?.host ?? "New Tab") : tab.model.title)
                        .font(HiveDesign.Typography.bodyMedium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if isActive {
                        Text("ACTIVE")
                            .font(HiveDesign.Typography.microTinyBold)
                            .foregroundStyle(HiveDesign.Accent.primary)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(HiveDesign.Accent.muted)
                            .clipShape(Capsule())
                    }
                    if tab.isPinned {
                        Image(systemName: "pin.fill")
                            .font(HiveDesign.Typography.microTinyBold)
                            .foregroundStyle(.secondary)
                    }
                    if tab.isEssential {
                        Image(systemName: "bolt.fill")
                            .font(HiveDesign.Typography.microTinyBold)
                            .foregroundStyle(.orange)
                    }
                }
                Text(tab.model.url?.host ?? "No page")
                    .font(HiveDesign.Typography.buttonCaption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            if isActive {
                Text("In use")
                    .font(HiveDesign.Typography.buttonCaption)
                    .foregroundStyle(.tertiary)
            } else if tab.isHibernated {
                Button(action: { state.wakeTab(tab) }) {
                    Label("Wake", systemImage: "sun.max.fill")
                        .font(HiveDesign.Typography.smallLabelBold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.3)))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
            } else if canSleep {
                Button(action: { state.hibernateTab(tab) }) {
                    Label("Sleep", systemImage: "moon.fill")
                        .font(HiveDesign.Typography.smallLabelBold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.3)))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Text("Protected")
                    .font(HiveDesign.Typography.buttonCaption)
                    .foregroundStyle(.tertiary)
                    .help("Private, pinned, essential, media, download, split, or active tabs can't be slept")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous)
                .fill(isHovered ? HiveDesign.Surface.level1 : Color.clear)
        )
        .onHover { isHovered = $0 }
        .opacity(tab.isHibernated ? 0.75 : 1)
    }
}
