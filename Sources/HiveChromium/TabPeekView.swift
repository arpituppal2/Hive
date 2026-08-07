import SwiftUI
import CefSwiftUI

// MARK: - Shared peek-anchor capture
//
// Both tab layouts (horizontal pills, vertical rows, and the pinned/Essential
// icon tiles) report their window-space frame as the peek card's anchor. This
// is single-sourced here — never copy the GeometryReader plumbing into another
// view again.

extension ChromiumBrowserState {

    /// Shared hover-dwell scheduling for every peek trigger (pills, rows, and
    /// Essential tiles). On hover-in: re-arms `beginPeek` after a 220ms dwell
    /// so the card doesn't flash while the cursor sweeps across adjacent tabs.
    /// On hover-out: schedules the 260ms dismissal grace so the cursor can
    /// travel onto the card before it disappears (Arc dwell behavior).
    static func schedulePeek(
        _ hovering: Bool,
        task: Binding<Task<Void, Never>?>,
        tabID: String,
        anchorRect: CGRect,
        state: ChromiumBrowserState
    ) {
        task.wrappedValue?.cancel()
        if hovering {
            task.wrappedValue = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled else { return }
                state.beginPeek(tabID: tabID, anchorRect: anchorRect)
            }
        } else {
            state.scheduleEndPeek()
        }
    }
}

/// Reports a view's frame (in the window's peek coordinate space) into a
/// binding, so the peek card can anchor next to the hovered element.
struct TabPeekAnchorCapture: ViewModifier {
    @Binding var frame: CGRect

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { frame = geo.frame(in: .named(ChromiumBrowserState.peekCoordinateSpaceName)) }
                    .onChange(of: geo.frame(in: .named(ChromiumBrowserState.peekCoordinateSpaceName))) { _, newFrame in
                        frame = newFrame
                    }
            }
        )
    }
}

extension View {
    /// Captures this view's window-space frame for peek-card anchoring.
    func tabPeekAnchor(into frame: Binding<CGRect>) -> some View {
        modifier(TabPeekAnchorCapture(frame: frame))
    }
}

// MARK: - TabPeekOverlay
//
// Arc-style tab peek: hovering a tab floats a card over the page showing a
// LIVE preview of that tab's content — without leaving the current tab.
//
// The preview is a pooled, independent CEF renderer of the tab's URL: the
// tab's own browser is already hosted by the main surface (or the MRU
// keepalive cache), and CEF cannot attach one browser to two views, so each
// peeked tab gets its own lightweight second renderer from
// ChromiumBrowserState.previewPool (MRU, capped). The CefWebViews for every
// pooled tab live in this view PERMANENTLY — the overlay is always in the
// window hierarchy and merely fades when no peek is active — so pooled
// browsers stay alive between peeks and re-peeking a known tab is instant.
//
// The card is non-interactive (hover is transient); clicking it switches to
// the peeked tab, matching Arc. Tabs that can't be previewed (hibernated —
// waking them just to peek would waste memory — or the web start page) show
// an honest placeholder instead of a fake preview.
//
// Layout:
//   Header:  favicon 16px + host (12px medium) + lock when https
//   Preview: 320×200 live CEF view (or a placeholder)
//   Footer:  title · URL · hibernation badge · ⌘N shortcut · group color dot

struct TabPeekOverlay: View {
    @Environment(ChromiumBrowserState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let cardWidth: CGFloat = 320
    private static let previewHeight: CGFloat = 200
    /// Header + footer + padding above/below the preview region.
    private static let chromeHeight: CGFloat = 128

    /// Window size for clamping the card. Measured by a dedicated transparent
    /// GeometryReader so the card itself can own hit testing (a full-window
    /// GeometryReader would swallow page clicks while a peek is showing).
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        ZStack {
            // Measurement-only: reports the window size for card clamping.
            // Never intercepts hits — the card below is the only interactive
            // region while a peek is showing.
            GeometryReader { geo in
                Color.clear
                    .onAppear { canvasSize = geo.size }
                    .onChange(of: geo.size) { _, newSize in canvasSize = newSize }
            }
            .allowsHitTesting(false)

            card
                .position(cardCenter(canvas: canvasSize))
                .opacity((state.activePeekTabID == nil && state.activePeekLinkURL == nil) ? 0 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: state.activePeekTabID)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: state.activePeekLinkURL)
        }
    }

    /// The peek card. Hit-testable only while a peek is active, so the rest of
    /// the window stays fully interactive.
    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let linkURL = state.activePeekLinkURL {
                linkHeader(urlString: linkURL)
            } else if let activeID = state.activePeekTabID, let tab = state.tabs.first(where: { $0.id == activeID }) {
                header(tab)
            }
            previewRegion(activeID: state.activePeekTabID, linkURL: state.activePeekLinkURL)
                .frame(height: Self.previewHeight)
                .padding(.top, 8)
            if let linkURL = state.activePeekLinkURL {
                linkFooter(urlString: linkURL)
            } else if let activeID = state.activePeekTabID, let tab = state.tabs.first(where: { $0.id == activeID }) {
                footer(tab)
            }
        }
        .padding(12)
        .frame(width: Self.cardWidth, alignment: .leading)
        .background(HiveDesign.Surface.level1, in: RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous)
                .stroke(HiveDesign.Surface.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous))
        .allowsHitTesting(state.activePeekTabID != nil || state.activePeekLinkURL != nil)
        .onHover { hovering in
            // Dwell: moving from the pill onto the card cancels the pending
            // dismissal so the preview stays reachable for click-to-switch.
            if hovering { state.holdPeek() } else { state.releasePeek() }
        }
        .onTapGesture {
            if let linkURL = state.activePeekLinkURL {
                state.openLinkFromPeek(linkURL)
            } else if let activeID = state.activePeekTabID {
                state.selectTab(id: activeID)
            }
        }
    }

    // MARK: - Preview region

    /// The pooled preview renderers, stacked. Only the active peek's renderer
    /// is visible; the others stay mounted (and alive) beneath it. A link peek
    /// shows its own transient renderer instead of a pooled tab renderer.
    @ViewBuilder
    private func previewRegion(activeID: String?, linkURL: String?) -> some View {
        ZStack {
            if linkURL != nil {
                // Link peek: the dedicated transient renderer of the hovered
                // link's destination. No placeholder — CEF shows its own
                // loading state until the page commits.
                if let model = state.linkPreviewModel {
                    CefWebView(model: model)
                        .allowsHitTesting(false)
                }
            } else if let activeID {
                let tab = state.tabs.first(where: { $0.id == activeID })
                placeholder(for: tab)
            }
            if linkURL == nil {
                ForEach(state.previewPoolTabIDs, id: \.self) { tabID in
                    if let model = state.peekModel(for: tabID) {
                        CefWebView(model: model)
                            .opacity(tabID == activeID ? 1 : 0)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .background(Color(white: 0.055))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(HiveDesign.Surface.hairline, lineWidth: 1)
        )
    }

    /// Honest empty states: a preview that can't exist is shown as one, not
    /// faked. Falls back to a clear background (the live renderer covers it).
    @ViewBuilder
    private func placeholder(for tab: ChromiumBrowserState.Tab?) -> some View {
        if let tab, tab.isHibernated {
            emptyState("moon.zzz.fill", "Sleeping", "Wake this tab to preview", .green)
        } else if let tab, tab.model.url?.scheme?.lowercased() == "hive" || tab.model.url == nil || tab.model.url?.absoluteString == "about:blank" {
            emptyState("plus.rectangle.on.rectangle", "New tab", "Nothing to preview yet", .secondary)
        } else {
            Color.clear
        }
    }

    private func emptyState(_ icon: String, _ title: String, _ subtitle: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(color)
            Text(title)
                .font(HiveDesign.Typography.sidebarItemSemiBold)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(HiveDesign.Typography.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    /// Link-peek header: destination host + HTTPS lock + a "Peek" label so the
    /// user knows this is a preview of a link, not the current page.
    private func linkHeader(urlString: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.right.square")
                .font(HiveDesign.Typography.smallLabelMedium)
                .foregroundStyle(HiveDesign.Accent.primary)
            Text(URL(string: urlString)?.host ?? "Link")
                .font(HiveDesign.Typography.sidebarItemMedium)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            if URL(string: urlString)?.scheme == "https" {
                Image(systemName: "lock.fill")
                    .font(HiveDesign.Typography.microTiny)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 4)
            Text("Peek")
                .font(HiveDesign.Typography.microLabel)
                .foregroundStyle(.tertiary)
        }
    }

    private func header(_ tab: ChromiumBrowserState.Tab) -> some View {
        HStack(spacing: 6) {
            tabIcon(for: tab).frame(width: 16, height: 16)
            Text(host(for: tab))
                .font(HiveDesign.Typography.sidebarItemMedium)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            if isSecure(tab) {
                Image(systemName: "lock.fill")
                    .font(HiveDesign.Typography.microTiny)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 4)
        }
    }

    // MARK: - Footer

    /// Link-peek footer: title + destination URL, with a hint that clicking
    /// opens the link in a new tab.
    private func linkFooter(urlString: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Open in new tab")
                .font(HiveDesign.Typography.bodySemiBold)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(urlString)
                .font(HiveDesign.Typography.monoSmall)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func footer(_ tab: ChromiumBrowserState.Tab) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(displayTitle(for: tab))
                .font(HiveDesign.Typography.bodySemiBold)
                .foregroundStyle(.primary)
                .lineLimit(1)
            if !urlString(for: tab).isEmpty {
                Text(urlString(for: tab))
                    .font(HiveDesign.Typography.monoSmall)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.top, 2)
            }
            HStack(spacing: 6) {
                if tab.isHibernated {
                    HStack(spacing: 3) {
                        Image(systemName: "moon.zzz.fill")
                            .font(HiveDesign.Typography.microTiny)
                        Text("Sleeping")
                            .font(HiveDesign.Typography.microLabelMedium)
                    }
                    .foregroundStyle(.green)
                }
                Spacer(minLength: 4)
                if let idx = tabIndex(for: tab) {
                    Text("\u{2318}\(idx)")
                        .font(HiveDesign.Typography.monoMicroMedium)
                        .foregroundStyle(.tertiary)
                }
                if let groupColor = state.tabGroupColor(tab) {
                    Circle()
                        .fill(groupColor)
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.top, 8)
        }
        .padding(.top, 10)
    }

    // MARK: - Metadata helpers

    private func host(for tab: ChromiumBrowserState.Tab) -> String {
        if let url = tab.model.url, let h = url.host { return h }
        return tab.savedURL?.host ?? "new tab"
    }

    private func isSecure(_ tab: ChromiumBrowserState.Tab) -> Bool {
        tab.model.url?.scheme == "https" || tab.savedURL?.scheme == "https"
    }

    private func displayTitle(for tab: ChromiumBrowserState.Tab) -> String {
        if tab.isHibernated { return "\(tab.model.title.isEmpty ? host(for: tab) : tab.model.title) · sleeping" }
        if !tab.model.title.isEmpty { return tab.model.title }
        return host(for: tab)
    }

    private func urlString(for tab: ChromiumBrowserState.Tab) -> String {
        tab.model.url?.absoluteString ?? tab.savedURL?.absoluteString ?? ""
    }

    private func tabIndex(for tab: ChromiumBrowserState.Tab) -> Int? {
        let all = state.visibleTabs
        guard let idx = all.firstIndex(where: { $0.id == tab.id }), idx < 9 else { return nil }
        return idx + 1
    }

    @ViewBuilder
    private func tabIcon(for tab: ChromiumBrowserState.Tab) -> some View {
        if tab.isHibernated { Image(systemName: "moon.zzz.fill").font(HiveDesign.Typography.sidebarItem).foregroundStyle(.green) }
        else if tab.model.isLoading { ProgressView().controlSize(.small).scaleEffect(0.6) }
        else if let favicon = tab.model.faviconURL { FaviconImage(url: favicon) }
        else { Image(systemName: "globe").font(HiveDesign.Typography.bodyMedium).foregroundStyle(.tertiary) }
    }

    // MARK: - Positioning

    /// Anchors the card near the hovered pill: below it in the horizontal
    /// layout, to its right in the vertical layout. Clamped inside the window.
    private func cardCenter(canvas: CGSize) -> CGPoint {
        let width = Self.cardWidth
        let height = Self.previewHeight + Self.chromeHeight
        let anchor = state.peekAnchorRect
        let isVertical = state.layout == .vertical
        var x: CGFloat
        var y: CGFloat
        if isVertical {
            x = anchor.maxX + 10 + width / 2
            y = anchor.midY
        } else {
            x = anchor.midX
            y = anchor.maxY + 10 + height / 2
        }
        let margin: CGFloat = 8
        x = min(max(x, width / 2 + margin), max(canvas.width - width / 2 - margin, width / 2 + margin))
        y = min(max(y, height / 2 + margin), max(canvas.height - height / 2 - margin, height / 2 + margin))
        return CGPoint(x: x, y: y)
    }
}
