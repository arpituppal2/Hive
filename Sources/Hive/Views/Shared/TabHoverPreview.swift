import SwiftUI
import AppKit
import HiveCore

// MARK: - TabHoverPreview
//
// A popover-style card that appears when the user hovers over a tab for 500ms.
// Shows the page title, URL domain, and favicon. Positioned above the tab pill
// (horizontal layout) or beside the tab row (vertical layout) via an alignment
// parameter. Uses a DispatchWorkItem delay pattern so quick cursor sweeps never
// flash the preview; a sustained 500ms hold triggers the card.
//
// Design: compact media-first card (260px wide with a fixed 128px preview frame),
// rounded corners, subtle shadow, and the Hive warm palette. Title truncated at 2
// lines, domain extracted from URL, favicon displayed at 32×32. Uses the browser's
// cached in-memory thumbnail when available; hover never triggers a fresh snapshot.

struct TabHoverPreview: View {

    let tab: BrowserTab

    /// Which edge the preview appears relative to (above for horizontal tabs,
    /// trailing for vertical tabs).
    enum Edge { case above, trailing }
    let edge: Edge

    @Environment(\.colorScheme) private var scheme
    @Environment(ChromeState.self) private var state

    /// The browser already captures lightweight in-memory page snapshots on load.
    /// Reuse that data here; hover must never trigger a fresh WKWebView snapshot.
    private var thumbnail: NSImage? {
        guard let data = state.thumbnailData[tab.id] else { return nil }
        return NSImage(data: data)
    }

    // MARK: Computed

    private var domain: String {
        tab.url?.host?.replacingOccurrences(of: "www.", with: "") ?? ""
    }

    private var fullURL: String {
        tab.url?.absoluteString ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fixed media frame keeps the card geometry stable while a snapshot
            // becomes available; no hover-induced layout jump.
            previewMedia

            // Header: favicon + title
            HStack(alignment: .top, spacing: 10) {
                faviconBlock
                VStack(alignment: .leading, spacing: 4) {
                    Text(tab.displayTitle)
                        .hiveType(.body)
                        .foregroundStyle(Color.hiveInk)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                    if !domain.isEmpty {
                        Text(domain)
                            .hiveType(.chromeLabel)
                            .foregroundStyle(Color.hiveGraphite)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)

            Divider().overlay(Color.hiveBorderSubtle)

            // URL footer
            HStack(spacing: 6) {
                Image(systemName: tab.isPrivate ? "lock.fill" : "globe")
                    .font(HiveTypography.font(.caption3Medium))
                    .foregroundStyle(tab.isPrivate ? Color.hiveAccent : Color.hiveGraphite)
                Text(fullURL.isEmpty ? "New Tab" : fullURL)
                    .hiveType(.chromeLabel)
                    .foregroundStyle(Color.hiveGraphite)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                // Loading indicator
                if tab.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Promise badge if present
            if let promise = tab.promise, !promise.isEmpty {
                Divider().overlay(Color.hiveBorderSubtle)
                HStack(spacing: 6) {
                    let token = HiveColorToken(rawValue: tab.promiseColor ?? "accent") ?? .accent
                    Circle()
                        .fill(Color(token))
                        .frame(width: 8, height: 8)
                    Text(promise)
                        .hiveType(.chromeLabel)
                        .foregroundStyle(Color.hiveGraphite)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
        .frame(width: 260)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r12))
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.r12)
                .stroke(Color.hiveBorderSubtle, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .transition(.opacity.combined(with: .scale(0.96, anchor: edge == .above ? .bottom : .leading)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Preview for \(tab.displayTitle)")
    }

    // MARK: Preview media

    private var previewMedia: some View {
        ZStack {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 260, height: 128)
                    .clipped()
                    .overlay(alignment: .bottomTrailing) {
                        Text("Preview")
                            .hiveType(.caption2)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, HiveSpacing.s4)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.45), in: Capsule())
                            .padding(HiveSpacing.s8)
                    }
                    .accessibilityHidden(true)
            } else {
                LinearGradient(
                    colors: [Color.hiveSurfaceElevated, Color.hiveSurface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: "rectangle.dashed.badge.record")
                        .font(HiveTypography.font(.featureTitle))
                        .foregroundStyle(Color.hiveGraphite.opacity(0.7))
                }
                .frame(width: 260, height: 128)
                .accessibilityHidden(true)
            }
        }
        .frame(width: 260, height: 128)
        .clipShape(
            RoundedRectangle(cornerRadius: HiveRadius.r12)
        )
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.22)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 42)
            .allowsHitTesting(false)
        }
    }

    // MARK: Favicon

    @ViewBuilder
    private var faviconBlock: some View {
        if let favURL = tab.faviconURL {
            FaviconView(url: favURL)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r6))
        } else {
            RoundedRectangle(cornerRadius: HiveRadius.r6)
                .fill(Color.hiveSurface)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "globe")
                        .font(HiveTypography.font(.panelTitleRegular))
                        .foregroundStyle(Color.hiveGraphite)
                )
        }
    }
}

// MARK: - TabHoverPreviewModifier
//
// A ViewModifier that drives the *window-level* tab hover preview by setting
// `ChromeState.previewTabID` after a sustained 500ms hover. The actual card renders
// in BrowserWindow's ZStack above all chrome, avoiding ScrollView clipping.
// Quick sweeps (< 500ms) never trigger it. Hover exit or tab close clears instantly.

struct TabHoverPreviewModifier: ViewModifier {

    let tab: BrowserTab

    @Environment(ChromeState.self) private var state
    @State private var delayWorkItem: DispatchWorkItem?

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if hovering {
                    schedulePreview()
                } else {
                    dismissPreview()
                }
            }
            .onDisappear { dismissPreview() }
    }

    private func schedulePreview() {
        dismissPreview()
        let tabID = tab.id
        let work = DispatchWorkItem {
            state.previewTabID = tabID
        }
        delayWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50, execute: work)
    }

    private func dismissPreview() {
        delayWorkItem?.cancel()
        delayWorkItem = nil
        if state.previewTabID == tab.id {
            state.previewTabID = nil
        }
    }
}

extension View {
    /// Drives the window-level tab hover preview via ChromeState. After a 500ms
    /// sustained hover, sets `state.previewTabID`; BrowserWindow renders the card.
    func tabHoverPreview(for tab: BrowserTab) -> some View {
        modifier(TabHoverPreviewModifier(tab: tab))
    }
}
