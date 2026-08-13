import SwiftUI

// MARK: - AddressBar
//
// Premium address bar with proper design tokens. Chrome/Safari-quality:
//   - URL display with favicon + security indicator
//   - Inline loading progress bar
//   - Bookmark star with bounce animation
//   - Reload/stop toggle
//   - Tracker shield with count
//   - @shortcut suggestions (Ask Hive, Bookmarks)
//   - Clean suggestion dropdown
//
// All colors/spacing/typography/radius use HiveDesign tokens.

struct AddressBar: View {

    @Environment(BrowserState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    /// Set when ⌘L (or the Focus Address command) demands select-all-on-focus
    /// (Chrome convention: typing replaces the URL). Cleared once applied so a
    /// plain mouse click never nukes the caret position.
    @State private var pendingSelectAll = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: HiveDesign.Space.xxs) {
                faviconView
                securityIcon

                TextField("Search or enter address", text: $text)
                    .textFieldStyle(.plain)
                    .font(HiveDesign.Typography.addressBar)
                    .focused($isFocused)
                    .contentTransition(.numericText())
                    .onKeyPress(.escape) {
                        if text != state.addressDisplayString {
                            text = state.addressDisplayString
                        } else {
                            isFocused = false
                        }
                        return .handled
                    }
                    // P2.4 dual-mode URL bar: ⇧⏎ routes the text to the AI
                    // panel instead of navigating/searching (Dia parity).
                    // Plain ⏎ is left .ignored so onSubmit still fires.
                    .onKeyPress(keys: [.return], phases: .down) { press in
                        if press.modifiers.contains(.shift) {
                            submitToAgent()
                            return .handled
                        }
                        return .ignored
                    }
                    .onSubmit { submit() }
                    .onChange(of: state.addressFocusTrigger) { _, _ in
                        // ⌘L convention: focus AND select all so typing replaces
                        // the current URL (matches the web chrome's ⌘L handler).
                        if isFocused {
                            // Already focused — select-all now (the flag path
                            // below only fires on a focus transition, so a
                            // second ⌘L would otherwise silently no-op and
                            // leak the flag into the next focus event).
                            selectAllInField()
                        } else {
                            pendingSelectAll = true
                            isFocused = true
                        }
                    }
                    .onChange(of: isFocused) { _, focused in
                        guard focused, pendingSelectAll else { return }
                        pendingSelectAll = false
                        // The field's NSTextView becomes the first responder
                        // after SwiftUI commits focus; select all on the next
                        // main-queue turn so the selection lands on the URL.
                        selectAllInField()
                    }

                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(HiveDesign.Text.tertiary)
                            .font(.system(size: HiveDesign.Typography.sizeLG))
                    }
                    .buttonStyle(.plain)
                }

                if isFocused && !text.isEmpty { aiModeHint }
                if !state.isNewTab { bookmarkStar }
                actionButton
                HostContextPolicyMenu()
                privacyShield
            }
            .padding(.horizontal, HiveDesign.AddressBar.horizontalPadding)
            .padding(.vertical, 0)
            .frame(height: HiveDesign.AddressBar.height)
            .background(
                RoundedRectangle(cornerRadius: HiveDesign.AddressBar.radius, style: .continuous)
                    .fill(isFocused ? HiveDesign.Surface.level2 : HiveDesign.Surface.level1)
                    .animation(HiveDesign.Animation.snap, value: isFocused)
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: HiveDesign.AddressBar.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: HiveDesign.AddressBar.radius, style: .continuous)
                    .stroke(isFocused ? HiveDesign.Accent.primary : HiveDesign.Surface.hairline, lineWidth: isFocused ? 2 : 1)
                    .animation(HiveDesign.Animation.snap, value: isFocused)
            )
            .overlay(alignment: .bottomLeading) {
                loadingProgressBar
            }
            .onChange(of: state.activeTabID) { _, _ in
                if !isFocused { text = state.addressDisplayString }
            }
            .onChange(of: state.activeModel?.url) { _, _ in
                if !isFocused { text = state.addressDisplayString }
            }
            .onAppear {
                if !isFocused { text = state.addressDisplayString }
            }

            // Suggestion dropdown
            if isFocused && (text.hasPrefix("/") ? !text.hasPrefix("//") : text.count >= 2) {
                OmniboxSuggestionPanel(
                    query: text,
                    onSubmit: { suggestion in
                        isFocused = false
                        if suggestion.kind == .command, let command = suggestion.command {
                            state.executeOmniboxCommand(command)
                        } else if suggestion.kind == .tab, let tabID = suggestion.tabID {
                            state.selectTab(id: tabID)
                        } else {
                            state.navigateToAddress(suggestion.url?.absoluteString ?? suggestion.text)
                        }
                    },
                    onDismiss: { isFocused = false }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(reduceMotion ? nil : HiveDesign.Animation.springQuick, value: text.count >= 2)
            }

            // @shortcut suggestions
            if isFocused && text.hasPrefix("@") {
                atShortcutSuggestions
            }
        }
    }

    // MARK: - AI mode hint (P2.4)

    /// Discoverability affordance for the dual-mode bar: shows the ⇧⏎
    /// gesture that sends the typed text to the AI panel instead of
    /// searching. Mirrors the web chrome's `addressbar__aihint` pill.
    @ViewBuilder private var aiModeHint: some View {
        HStack(spacing: HiveDesign.Space.xxs) {
            Image(systemName: "sparkles")
                .font(.system(size: HiveDesign.Typography.sizeXS, weight: .semibold))
            Text("⇧⏎ Ask Hive")
                .font(HiveDesign.Typography.smallLabel)
        }
        .foregroundStyle(HiveDesign.Accent.primary)
        .padding(.horizontal, HiveDesign.Space.xs)
        .padding(.vertical, HiveDesign.Space.xxs)
        .background(
            RoundedRectangle(cornerRadius: HiveDesign.Radius.xs, style: .continuous)
                .fill(HiveDesign.Accent.primary.opacity(0.12))
        )
        .transition(.opacity)
    }

    // MARK: - AI submit (P2.4)

    /// Sends the bar's text to the AI panel as a chat message, opening the
    /// panel if needed. No-op on empty text.
    private func submitToAgent() {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        isFocused = false
        state.submitGeminiQuery(q)
    }

    /// Selects the whole URL once the field's NSTextView is the first
    /// responder (deferred a main-queue turn so SwiftUI's focus commit
    /// lands first). Used by the ⌘L select-all path.
    private func selectAllInField() {
        DispatchQueue.main.async {
            if let editor = NSApp.keyWindow?.firstResponder as? NSTextView {
                editor.selectAll(nil)
            }
        }
    }

    // MARK: - Favicon

    @ViewBuilder private var faviconView: some View {
        if let faviconURL = state.activeModel?.faviconURL {
            FaviconImage(url: faviconURL).frame(width: HiveDesign.AddressBar.iconSize, height: HiveDesign.AddressBar.iconSize)
        } else if let host = state.activeModel?.url?.host {
            Text(String(host.prefix(1)).uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(HiveDesign.Text.tertiary)
                .frame(width: HiveDesign.AddressBar.iconSize, height: HiveDesign.AddressBar.iconSize)
                .background(HiveDesign.Surface.level2)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    // MARK: - Security Icon

    @ViewBuilder private var securityIcon: some View {
        if let url = state.activeModel?.url, url.scheme == "https" {
            Button(action: { withAnimation(reduceMotion ? nil : HiveDesign.Animation.spring) { state.isSiteSecurityPanelOpen.toggle() } }) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: HiveDesign.Typography.sizeSM, weight: .bold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Site security — encrypted connection")
            .help("Site security — encrypted connection")
        } else if state.activeModel?.url != nil {
            Button(action: { withAnimation(reduceMotion ? nil : HiveDesign.Animation.spring) { state.isSiteSecurityPanelOpen.toggle() } }) {
                Image(systemName: "info.circle")
                    .foregroundStyle(HiveDesign.State.warning)
                    .font(.system(size: HiveDesign.Typography.sizeMD, weight: .medium))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Site security — not encrypted")
            .help("Site security — not encrypted")
        }
    }

    // MARK: - Bookmark Star

    @ViewBuilder private var bookmarkStar: some View {
        Button(action: { state.toggleCurrentPageBookmark() }) {
            Image(systemName: state.isCurrentPageBookmarked ? "star.fill" : "star")
                .font(.system(size: HiveDesign.Icon.medium, weight: .semibold))
                .foregroundStyle(state.isCurrentPageBookmarked ? HiveDesign.Accent.primary : HiveDesign.Text.tertiary)
                .symbolEffect(.bounce, value: state.isCurrentPageBookmarked)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state.isCurrentPageBookmarked ? "Remove bookmark" : "Bookmark this page")
        .help(state.isCurrentPageBookmarked ? "Remove bookmark" : "Bookmark this page")
    }

    // MARK: - Reload / Stop

    @ViewBuilder private var actionButton: some View {
        // Secondary foreground, not accent: reload/stop is a routine control,
        // and the design system keeps accent below ~5% of pixels (reserved for
        // active states and primary CTAs).
        if state.isLoading {
            Button(action: { state.stop() }) {
                Image(systemName: "xmark")
                    .font(.system(size: HiveDesign.Typography.sizeLG, weight: .bold))
                    .foregroundStyle(HiveDesign.Text.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop loading")
            .help("Stop loading")
        } else {
            Button(action: { state.reload() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: HiveDesign.Typography.sizeLG, weight: .bold))
                    .foregroundStyle(HiveDesign.Text.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reload page")
            .help("Reload page")
        }
    }

    // MARK: - Tracker Shield

    @ViewBuilder private var privacyShield: some View {
        Button(action: { state.openPrivacyReport() }) {
            HStack(spacing: 3) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: HiveDesign.Typography.sizeMD, weight: .semibold))
                    .foregroundStyle(.green)
                Text("\(state.trackerBlockedCount)")
                    .font(.system(size: HiveDesign.Typography.sizeSM, weight: .bold))
                    .foregroundStyle(.green)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Privacy report")
        .accessibilityValue("\(state.trackerBlockedCount) trackers blocked")
        .help("\(state.trackerBlockedCount) trackers blocked")
    }

    // MARK: - Loading Progress Bar

    private var loadingProgressBar: some View {
        GeometryReader { geo in
            if state.isLoading {
                Rectangle()
                    .fill(Color.hiveAccent)
                    .frame(width: max(0, geo.size.width * state.loadingProgress), height: 2)
            }
        }
        .frame(height: 2)
    }

    // MARK: - @shortcut Suggestions

    @ViewBuilder private var atShortcutSuggestions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Shortcuts")
                .font(HiveDesign.Typography.sectionHeader)
                .foregroundStyle(HiveDesign.Text.secondary)
            HStack(spacing: HiveDesign.Space.xs) {
                AtShortcutChip(label: "Ask Hive", icon: "sparkles", action: {
                    text = ""; state.toggleGeminiPanel()
                })
                AtShortcutChip(label: "Bookmarks", icon: "bookmark", action: {
                    text = ""; state.openBookmarksManager()
                })
            }
        }
        .padding(.horizontal, HiveDesign.Space.sm)
        .padding(.vertical, HiveDesign.Space.xs)
        .background(HiveDesign.Material.panel)
        .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    // MARK: - Submit

    private func submit() {
        isFocused = false
        if let command = state.omniboxCommand(for: text) {
            state.executeOmniboxCommand(command)
        } else {
            state.navigateToAddress(text)
        }
    }
}

// MARK: - AtShortcutChip

struct AtShortcutChip: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: HiveDesign.Space.xxs) {
                Image(systemName: icon)
                    .font(.system(size: HiveDesign.Typography.sizeSM, weight: .semibold))
                Text(label)
                    .font(HiveDesign.Typography.smallLabel)
            }
            .foregroundStyle(HiveDesign.Text.primary)
            .padding(.horizontal, HiveDesign.Space.xs)
            .padding(.vertical, HiveDesign.Space.xxs)
            .background(HiveDesign.Surface.level2)
            .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.xs + 2, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CompactAddressBar

struct CompactAddressBar: View {
    @Environment(BrowserState.self) private var state

    var body: some View {
        HStack(spacing: HiveDesign.Space.sm) {
            navigationButtons
            AddressBar()
            layoutToggle
        }
        .padding(.horizontal, HiveDesign.Space.sm)
        .padding(.vertical, HiveDesign.Space.xs)
        .background(HiveDesign.Material.sidebar)
    }

    private var navigationButtons: some View {
        HStack(spacing: HiveDesign.Space.xs) {
            navButton("chevron.left", enabled: state.canGoBack) { state.goBack() }
            navButton("chevron.right", enabled: state.canGoForward) { state.goForward() }
        }
    }

    private var layoutToggle: some View {
        Button(action: { state.toggleLayout() }) {
            Image(systemName: state.layout == .horizontal ? "rectangle.lefthalf.inset.filled" : "rectangle.topthird.inset.filled")
                .foregroundStyle(HiveDesign.Text.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Toggle tab layout")
        .help("Toggle tab layout")
    }

    private func navButton(_ systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(enabled ? HiveDesign.Text.primary : HiveDesign.Text.tertiary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName == "chevron.left" ? "Go back" : "Go forward")
        .disabled(!enabled)
    }
}
