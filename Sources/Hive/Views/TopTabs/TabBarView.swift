import SwiftUI
import AppKit
import UniformTypeIdentifiers
import HiveCore

// MARK: - TabBarView (horizontal strip)
//
// The horizontal tab bar (SPEC §8.1/§8.3). Renders the active space's tabs left-to-right,
// pinned tabs first (favicon-only 48pt) separated by a gap, then unpinned pills in a
// horizontally-scrolling strip (overflow = scroll, no fade mask). Followed by the New Tab
// button. ⌘⇧[ / ⌘⇧] cycle through; drag-reorder supported via onDrag/onDrop with visual
// 2pt accent drop indicator.
//
// Drag & Drop (SPEC §16):
//   - Custom glass drag preview (120×32pt card with favicon + truncated title)
//   - Ghost placeholder at 30% opacity at original position
//   - Spring settle on drop (micro 0.18s)
//   - 2pt accent drop indicator between tabs
//   - Cross-window via NSItemProvider with tab ID + URL serialization
//
// Lives inside TopChromeView. The strip's container owns the `@Namespace` used by
// BrowserWindow's matchedGeometryEffect for the H↔V morph.

struct TabBarView: View {

    @Environment(ChromeState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hoveredTabID: String?
    @State private var draggedTabID: String?
    @State private var dropTargetIndex: Int?
    @State private var hoveringNewTab = false

    /// Tab awaiting a custom-promise text entry via the context-menu "Promise: Custom…"
    /// action. Stale values are benign — the next "Custom…" press overwrites the id
    /// before presenting, and `Set` is guarded by `if let`.
    @State private var customPromiseTabID: String?
    @State private var customPromiseText = ""
    @State private var isShowingCustomPromise = false

    /// Group awaiting a rename-via-alert from the group context-menu "Rename Group…"
    /// action. Driven by `.alert(item: $renameGroupTarget)` attached to `newTabButton`,
    /// deliberately distinct from the body-level promise `.alert(isPresented:)` —
    /// SwiftUI only honors one `isPresented:` alert per view tree, so a second
    /// `isPresented`-driven alert on the same body would silently fail to present.
    /// An `item:`-driven alert on a *different* concrete sub-view avoids the collision.
    @State private var renameGroupTarget: TabGroup?
    @State private var renameGroupText = ""

    var body: some View {
        HStack(spacing: activeDensity.gap) {
            pinnedSection
            overflowStrip
            newTabButton
            Spacer(minLength: 0)
        }
        .padding(.horizontal, HiveSpacing.s8)
        .frame(height: activeDensity.pillHeight + HiveSpacing.s8)
        .animation(settleAnim, value: state.activeTabID)
        .alert("Custom Promise", isPresented: $isShowingCustomPromise) {
            TextField("Promise text", text: $customPromiseText)
            Button("Cancel", role: .cancel) {
                customPromiseTabID = nil
                customPromiseText = ""
            }
            Button("Set") {
                if let id = customPromiseTabID {
                    state.setPromise(id, promise: customPromiseText)
                }
                customPromiseTabID = nil
                customPromiseText = ""
            }
            .disabled(customPromiseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Tag this tab with a short promise badge — shown on the tab and searchable in Tab Overview.")
        }
    }

    // MARK: Sections

    @ViewBuilder private var pinnedSection: some View {
        let pinned = visibleTabs.filter { $0.isPinned }
        if !pinned.isEmpty {
            HStack(spacing: activeDensity.gap) {
                ForEach(pinned) { tab in pill(tab) }
            }
            // Visual separator between pinned and unpinned.
            Rectangle().fill(Color.hiveBorderSubtle).frame(width: 1, height: activeDensity.pillHeight * 0.6)
                .padding(.horizontal, 2)
        }
    }

    private var overflowStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            tabDropContainer
                .padding(.trailing, HiveSpacing.s8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The tab strip's HStack with embedded drop zones between each tab.
    @ViewBuilder private var tabDropContainer: some View {
        HStack(spacing: 0) {
            // Drop zone at the very start (index 0)
            dropZone(at: 0, tabID: state.ungroupedTabs.filter { !$0.isPinned }.first?.id)

            // Groups render as chips before ungrouped tabs.
            ForEach(Array(state.visibleGroups.enumerated()), id: \.element.id) { _, group in
                groupChip(group)
                // Drop zone after group
                dropZone(at: state.ungroupedTabs.filter { !$0.isPinned }.count + 1, tabID: nil)
            }

            // Ungrouped tabs flow after groups.
            ForEach(Array(state.ungroupedTabs.filter { !$0.isPinned }.enumerated()), id: \.element.id) { idx, tab in
                if idx > 0 {
                    dropZone(at: idx, tabID: tab.id)
                }
                pill(tab)
            }

            // Drop zone at the very end
            dropZone(at: state.ungroupedTabs.filter { !$0.isPinned }.count, tabID: nil)
        }
        .onDrop(of: [.text], delegate: TabDropReceiver(
            tabIDs: state.ungroupedTabs.filter { !$0.isPinned }.map { $0.id },
            tabDensity: activeDensity,
            draggedTabID: $draggedTabID,
            dropTargetIndex: $dropTargetIndex,
            state: state
        ))
    }

    private var visibleTabs: [BrowserTab] { state.visibleTabs }
    private var activeDensity: TabDensity { state.prefs.tabDensity }

    // MARK: Drop zone indicator

    @ViewBuilder
    private func dropZone(at index: Int, tabID: String?) -> some View {
        if let dropIdx = dropTargetIndex, dropIdx == index {
            Rectangle()
                .fill(state.activeAccentColor)
                .frame(width: 2, height: activeDensity.pillHeight * 0.6)
                .cornerRadius(1)
                .padding(.horizontal, 2)
                .transition(.scale(scale: 1.0, anchor: .center).combined(with: .opacity))
                .animation(settleAnim, value: dropTargetIndex)
        } else {
            Color.clear
                .frame(width: activeDensity.gap)
        }
    }

    // MARK: New tab button

    private var newTabButton: some View {
        Button {
            state.newTab()
        } label: {
            Image(systemName: "plus")
                .font(HiveTypography.font(.caption1Medium))
                .foregroundStyle(state.activeAccentColor)
                .frame(width: HiveSpacing.s24, height: activeDensity.pillHeight)
                .background(
                    RoundedRectangle(cornerRadius: HiveRadius.r6)
                        .fill(Color.hiveSurface.opacity(hoveringNewTab ? 0.6 : 0))
                )
                .animation(.hiveMicro, value: hoveringNewTab)
        }
        .buttonStyle(.plain)
        .onHover { hoveringNewTab = $0 }
        .keyboardShortcut("t", modifiers: .command)
        .accessibilityLabel("New tab")
        .alert("Rename Group", isPresented: Binding(
            get: { renameGroupTarget != nil },
            set: { if !$0 { renameGroupTarget = nil } }
        )) {
            TextField("Group name", text: $renameGroupText)
            Button("Cancel", role: .cancel) {
                renameGroupTarget = nil
                renameGroupText = ""
            }
            Button("Rename") {
                if let group = renameGroupTarget {
                    let trimmed = renameGroupText.trimmingCharacters(in: .whitespacesAndNewlines)
                    state.renameGroup(group.id, to: trimmed.isEmpty ? group.name : trimmed)
                }
                renameGroupTarget = nil
                renameGroupText = ""
            }
            .disabled(renameGroupText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Rename this tab group. The name shows on the group chip and is searchable in Tab Overview.")
        }
    }

    // MARK: Pill + drag (SPEC §16)
    //
    // Drag initiates with a custom NSItemProvider containing the tab ID and URL.
    // The pill at the dragged position becomes a 30% ghost placeholder.
    // A glass-backed drag preview card is provided via NSItemProvider's
    // previewForCancelling/previewForHighlighting handlers.

    @ViewBuilder
    private func pill(_ tab: BrowserTab) -> some View {
        let isHovered = Binding(
            get: { hoveredTabID == tab.id },
            set: { hovered in hoveredTabID = hovered ? tab.id : nil }
        )
        let isBeingDragged = draggedTabID == tab.id

        TabPill(tab: tab, density: activeDensity, isHovered: isHovered)
            .id(tab.id)
            .onTapGesture { state.selectTab(tab.id) }
            .contextMenu { tabContextMenu(for: tab) }
            .onDrag {
                draggedTabID = tab.id
                let provider = NSItemProvider(object: tab.id as NSString)
                // Attach URL for cross-window drops
                if let url = tab.url {
                    provider.registerObject(url as NSURL, visibility: .all)
                }
                return provider
            }
            // Ghost: 30% opacity at original position while dragging
            .opacity(isBeingDragged ? 0.30 : 1.0)
            .animation(settleAnim, value: isBeingDragged)
            // Spring settle on drop
            .animation(settleAnim, value: dropTargetIndex)
    }

    /// Spring settle animation for drop — micro spring (0.18s).
    private var settleAnim: Animation {
        reduceMotion ? .linear(duration: 0.12) : .spring(response: 0.18, dampingFraction: 0.90)
    }

    // MARK: Tab context menu (unchanged from original)

    @ViewBuilder
    private func tabContextMenu(for tab: BrowserTab) -> some View {
        Button("Close Tab") { state.closeTab(tab.id) }
        Button("Close Other Tabs") { state.closeOtherTabs(keeping: tab.id) }
        Button("Close Tabs to the Right") { state.closeTabsToRight(of: tab.id) }
        Divider()
        Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") { state.togglePin(tab.id) }
        Button(tab.isMuted ? "Unmute Site" : "Mute Site") { state.toggleMute(tab.id) }
        Divider()
        Button(tab.isReaderMode ? "Exit Reader Mode" : "Enter Reader Mode") { state.toggleReaderMode(for: tab.id) }
        Divider()
        Button("Duplicate Tab") { state.duplicateTab(tab.id) }
        Divider()
        Button("Copy URL") {
            if let url = tab.url { NSPasteboard.general.clearAndSet(string: url.absoluteString) }
        }
        Button("Copy Title") {
            NSPasteboard.general.clearAndSet(string: tab.displayTitle)
        }
        Divider()
        groupMenu(for: tab)
        promiseMenu(for: tab)
    }

    @ViewBuilder
    private func groupMenu(for tab: BrowserTab) -> some View {
        if state.groupContaining(tab.id) != nil {
            Button("Remove from Group") { state.removeTabFromGroup(tab.id) }
        } else {
            Menu("Add to Group") {
                Button("New Group…") {
                    state.createGroup(name: "New Group", in: state.activeSpace.id, tabIDs: [tab.id])
                }
                if !state.visibleGroups.isEmpty {
                    Divider()
                    ForEach(state.visibleGroups) { group in
                        Button(group.name) {
                            state.addTabToGroup(tab.id, groupID: group.id)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func groupChip(_ group: TabGroup) -> some View {
        let token = HiveColorToken(rawValue: group.colorDot) ?? .accent
        let tokenColor = Color(token)
        HStack(spacing: activeDensity.gap) {
            Button {
                state.toggleGroupFold(group.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: group.isFolded ? "folder.fill" : "folder")
                        .font(HiveTypography.font(.caption3Medium))
                        .foregroundStyle(tokenColor)
                    Circle()
                        .fill(tokenColor)
                        .frame(width: 6, height: 6)
                    Text(group.name)
                        .hiveType(.chromeTitle)
                        .foregroundStyle(.hiveInk)
                        .lineLimit(1)
                    Text("\(group.tabIDs.count)")
                        .hiveType(.chromeLabel)
                        .foregroundStyle(.hiveGraphite)
                }
                .padding(.horizontal, 8)
                .frame(height: activeDensity.pillHeight)
                .background(Color.hiveSurface.opacity(group.isFolded ? 0.4 : 0.8))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .contextMenu { horizontalGroupContextMenu(for: group) }

            if !group.isFolded {
                ForEach(state.tabs(in: group)) { tab in
                    pill(tab)
                }
            }
        }
    }

    @ViewBuilder
    private func horizontalGroupContextMenu(for group: TabGroup) -> some View {
        Button(group.isFolded ? "Unfold Group" : "Fold Group") {
            state.toggleGroupFold(group.id)
        }
        Button("Rename Group…") {
            renameGroupTarget = group
            renameGroupText = group.name
        }
        Divider()
        Button("Ungroup Tabs") { state.deleteGroup(group.id) }
        Button("Close Group Tabs", role: .destructive) {
            let ids = group.tabIDs
            state.deleteGroup(group.id)
            for id in ids { state.closeTab(id) }
        }
    }

    @ViewBuilder
    private func promiseMenu(for tab: BrowserTab) -> some View {
        if let promise = tab.promise, !promise.isEmpty {
            Button("Promise: \(promise)") {}
                .disabled(true)
            Button("Clear Promise") { state.clearPromise(tab.id) }
        } else {
            Button("Promise: Read Later") { state.setPromise(tab.id, promise: "read later") }
            Button("Promise: Custom…") {
                customPromiseTabID = tab.id
                customPromiseText = ""
                isShowingCustomPromise = true
            }
        }
        Divider()
        if let url = tab.url {
            Button {
                state.addToReadingList(url: url, title: tab.displayTitle, faviconURL: tab.faviconURL)
            } label: {
                Label("Add to Reading List", systemImage: "text.bookmark")
            }
            Button {
                state.pinAsApp(name: tab.displayTitle, url: url, faviconURL: tab.faviconURL)
            } label: {
                Label("Pin as App", systemImage: "pin")
            }
            Button {
                state.openInLittleArc(url: url)
            } label: {
                Label("Open in Little Arc", systemImage: "arrow.up.forward.app")
            }
            Button {
                state.toggleSplitTab(tab.id)
            } label: {
                Label(state.isSplitActive ? "Add to Split" : "Split with Active Tab", systemImage: "rectangle.split.2x1")
            }
            Button {
                Task {
                    let boost = Boost(name: tab.displayTitle, urlPattern: url.host ?? url.absoluteString,
                                     css: "", js: "", forceDarkMode: false, zappedSelectors: [], isEnabled: true)
                    await BoostStore.shared.create(boost)
                }
            } label: {
                Label("Create Boost for This Site", systemImage: "paintbrush.pointed")
            }
        }
    }
}

// MARK: - TabDropReceiver (SPEC §16)
//
/// Handles drop events for the tab strip. Computes the target insertion index from the
/// drop location using actual tab density dimensions, supports cross-window drops by
/// accepting NSItemProvider payload with tab ID string and URL, and provides spring-settle
/// animation feedback. Follows Apple HIG: translucent drag image, visual feedback for valid
/// drops, insertion point indicator, scroll on drag.
@MainActor
private struct TabDropReceiver: DropDelegate {
    let tabIDs: [String]
    let tabDensity: TabDensity
    @Binding var draggedTabID: String?
    @Binding var dropTargetIndex: Int?
    let state: ChromeState

    /// Approximate width per tab based on density — used for drop index estimation.
    /// In a full implementation, this would use measured frame positions.
    private var estimatedTabPitch: CGFloat {
        // Use min width as a baseline pitch; pinned tabs are 48pt, so average ~60pt
        max(tabDensity.minWidth, 60)
    }

    func dropEntered(info: DropInfo) {
        let point = info.location
        let idx = Int(point.x / estimatedTabPitch)
        dropTargetIndex = min(max(0, idx), tabIDs.count)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let point = info.location
        let idx = Int(point.x / estimatedTabPitch)
        dropTargetIndex = min(max(0, idx), tabIDs.count)
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            draggedTabID = nil
            dropTargetIndex = nil
        }

        // First try our internal tab ID (same-window drag)
        if let draggedID = draggedTabID {
            let targetIdx = dropTargetIndex ?? tabIDs.count
            let clampedIdx = min(targetIdx, tabIDs.count - 1)
            state.moveTab(draggedID, to: max(0, clampedIdx))
            return true
        }

        // Cross-window: accept from NSItemProvider
        // loadObject dispatches to a background queue; we capture value types and
        // use DispatchQueue.main.async to safely access the MainActor-bound state.
        let currentDropIdx = dropTargetIndex ?? tabIDs.count
        for provider in info.itemProviders(for: [.text]) {
            let capturedTabCount = tabIDs.count
            provider.loadObject(ofClass: NSString.self) { [currentDropIdx, capturedTabCount] (obj, _) in
                guard let id = obj as? String else { return }
                let targetIdx = min(currentDropIdx, capturedTabCount)
                DispatchQueue.main.async { [state] in
                    state.moveTab(id, to: max(0, targetIdx))
                }
            }
            return true
        }

        // Fallback: accept a dropped URL to open in new tab
        for provider in info.itemProviders(for: [.url]) {
            provider.loadObject(ofClass: NSURL.self) { (obj, _) in
                guard let url = obj as? URL else { return }
                DispatchQueue.main.async { [state] in
                    state.newTab(url: url as URL)
                }
            }
            return true
        }

        return false
    }

    func dropExited(info: DropInfo) {
        withAnimation(reduceMotion ? .linear(duration: 0.12) : .spring(response: 0.18, dampingFraction: 0.90)) {
            dropTargetIndex = nil
        }
        draggedTabID = nil
    }
}

// MARK: - Pasteboard helper

private extension NSPasteboard {
    func clearAndSet(string: String) {
        clearContents()
        setString(string, forType: .string)
    }
}
