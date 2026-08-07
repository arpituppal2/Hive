import SwiftUI
import WebKit
import HiveCore

// MARK: - PinnedAppPanelView
//
// A persistent WKWebView panel showing the selected pinned web app's content.
// Uses WebPanelManager.shared for persistent webviews so JavaScript sessions,
// WebSockets, and audio contexts survive panel switches.

struct PinnedAppPanelView: View {

    @Environment(ChromeState.self) private var state
    @Environment(\.webPanelManager) private var panelManager

    private var activeApp: PinnedWebApp? {
        guard let id = state.activePinnedAppID else { return nil }
        return state.prefs.pinnedWebApps.first { $0.id == id }
    }

    var body: some View {
        if let app = activeApp {
            VStack(spacing: 0) {
                // Mini header with app name, reload, and close button
                HStack(spacing: HiveSpacing.s8) {
                    if let favicon = app.faviconURL {
                        FaviconView(url: favicon)
                            .frame(width: 14, height: 14)
                    }
                    Text(app.name)
                        .hiveType(.caption1)
                        .foregroundStyle(.hiveInk)
                        .lineLimit(1)
                    Spacer(minLength: 0)

                    // Reload button
                    Button {
                        panelManager.reload(panelID: app.id)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(HiveTypography.font(.microMedium))
                            .foregroundStyle(.hiveGraphite)
                    }
                    .buttonStyle(.plain)
                    .help("Reload panel")

                    // Close button
                    Button {
                        state.activePinnedAppID = nil
                        state.isPinnedAppsExpanded = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(HiveTypography.font(.microMedium))
                            .foregroundStyle(.hiveGraphite)
                    }
                    .buttonStyle(.plain)
                    .help("Close panel")
                }
                .padding(.horizontal, HiveSpacing.s8)
                .padding(.vertical, HiveSpacing.s4)
                .background(.hiveMist.opacity(0.12))

                // Persistent WebView from the panel manager
                PersistentPanelWebView(appID: app.id, url: app.url)
            }
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
            .background(Color.hiveBackground)
        }
    }
}

// MARK: - PersistentPanelWebView (NSViewRepresentable)
//
// Bridges the WebPanelManager's persistent WKWebView into the SwiftUI view
// hierarchy. Unlike the old approach that created a fresh WKWebView each time,
// this retrieves the existing instance from the manager so session state
// (cookies, JS context, WebSockets) is preserved across panel switches.

private struct PersistentPanelWebView: NSViewRepresentable {

    let appID: String
    let url: URL

    @Environment(\.webPanelManager) private var panelManager

    func makeNSView(context: Context) -> WKWebView {
        panelManager.webView(for: appID, url: url)
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // The panel manager handles navigation internally — no need to
        // reload here unless the URL changed externally.
    }
}
