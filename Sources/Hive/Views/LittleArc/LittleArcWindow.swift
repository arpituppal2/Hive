import SwiftUI
import WebKit
import HiveCore

// MARK: - LittleArcWindow
//
// A lightweight, frameless popup browser window for quick link previews — Arc's
// "Little Arc" pattern. Launched by ⌘⇧⌥-clicking a link, ⌘⇧A keyboard shortcut,
// or from context menus. Designed for "look at this quickly" moments without
// cluttering the tab bar.
//
// Architecture: NSPanel (floating, non-activating) hosting a SwiftUI view with
// a compact omnibar + WKWebView. Dismisses on Escape or click-outside.

final class LittleArcWindow: NSObject {

    private var panel: NSPanel?
    private var webView: WKWebView?

    /// Shows a Little Arc popup for the given URL, positioned near the mouse cursor.
    /// - Parameter url: The URL to open in the popup.
    @MainActor
    func show(url: URL) {
        // Dismiss any existing panel first.
        dismiss()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = true
        panel.hasShadow = true
        panel.backgroundColor = NSColor.controlBackgroundColor
        panel.delegate = self

        let hostingView = NSHostingView(rootView: LittleArcContentView(
            url: url,
            onOpenInMainWindow: { [weak self] in
                self?.promoteToTab(url: url)
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        ))
        panel.contentView = hostingView
        // Ensure the hosting view fills the panel's content area.
        hostingView.frame = panel.contentView?.bounds ?? NSRect(origin: .zero, size: NSSize(width: 520, height: 360))

        // Position near the mouse cursor.
        positionNearMouse(panel)

        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(hostingView)

        self.panel = panel
    }

    /// Dismisses the current Little Arc popup.
    @MainActor
    func dismiss() {
        if let panel {
            panel.orderOut(nil)
            panel.contentView = nil
        }
        panel = nil
        webView = nil
    }

    /// Promotes the Little Arc URL to a new tab in the main browser window.
    /// Called from the SwiftUI view's "Open in Main Window" button.
    @MainActor
    private func promoteToTab(url: URL) {
        // Open the URL as a new tab in the main window by posting a notification.
        NotificationCenter.default.post(
            name: .littleArcPromoteToTab,
            object: nil,
            userInfo: ["url": url]
        )
        dismiss()
    }

    /// Positions the panel near the current mouse cursor, clamped to the target display.
    private func positionNearMouse(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let windowSize = panel.frame.size

        let targetScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main ?? NSScreen.screens.first

        guard let screen = targetScreen else { return }
        let screenRect = screen.frame

        var originX = mouseLocation.x - (windowSize.width / 2)
        var originY = mouseLocation.y - windowSize.height - 16

        // Clamp to display bounds.
        if originX + windowSize.width > screenRect.maxX {
            originX = screenRect.maxX - windowSize.width - 12
        }
        if originX < screenRect.minX {
            originX = screenRect.minX + 12
        }
        if originY < screenRect.minY {
            originY = mouseLocation.y + 20
        }

        panel.setFrame(NSRect(origin: NSPoint(x: originX, y: originY), size: windowSize), display: true)
    }
}

// MARK: - NSWindowDelegate

extension LittleArcWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        panel?.contentView = nil
        panel = nil
        webView = nil
    }
}

// MARK: - NSNotification

extension Notification.Name {
    static let littleArcPromoteToTab = Notification.Name("com.hive.littleArcPromoteToTab")
}

// MARK: - LittleArcContentView (SwiftUI)

private struct LittleArcContentView: View {

    let url: URL
    let onOpenInMainWindow: () -> Void
    let onDismiss: () -> Void

    @State private var currentURL: URL
    @State private var isLoading = true

    init(url: URL, onOpenInMainWindow: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.url = url
        self.currentURL = url
        self.onOpenInMainWindow = onOpenInMainWindow
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 0) {
            // Mini omnibar
            miniOmnibar
            Divider()
            // Web content
            ZStack {
                LittleArcWebView(url: currentURL, isLoading: $isLoading)
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(maxWidth: .infinity, maxHeight: 2, alignment: .top)
                        .offset(y: -1)
                }
            }
        }
        .background(Color(.controlBackgroundColor))
        .onExitCommand { onDismiss() }
    }

    // MARK: - Mini Omnibar

    private var miniOmnibar: some View {
        HStack(spacing: 6) {
            // Favicon / lock icon
            Image(systemName: currentURL.scheme == "https" ? "lock.fill" : "globe")
                .font(HiveTypography.font(.micro))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            // URL text (compact, not editable for v1)
            Text(currentURL.host ?? currentURL.absoluteString)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Open in main window button
            Button(action: onOpenInMainWindow) {
                Image(systemName: "arrow.up.forward.square")
                    .font(HiveTypography.font(.captionMedium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open in Main Window (⌘O)")

            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(HiveTypography.font(.microMedium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .help("Close (Esc)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

// MARK: - LittleArcWebView (NSViewRepresentable)

private struct LittleArcWebView: NSViewRepresentable {

    let url: URL
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url?.absoluteString != url.absoluteString {
            nsView.load(URLRequest(url: url))
        }
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.stopLoading()
        nsView.navigationDelegate = nil
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        nonisolated func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in self.isLoading = true }
        }

        nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in self.isLoading = false }
        }

        nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in self.isLoading = false }
        }

        nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in self.isLoading = false }
        }
    }
}
