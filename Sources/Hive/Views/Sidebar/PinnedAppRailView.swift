import SwiftUI
import HiveCore

// MARK: - PinnedAppRailView
//
// A collapsible app rail for pinned web apps — Sidekick/Arc-style. When collapsed,
// shows a thin vertical strip of favicon tiles. When expanded, shows app names
// alongside icons and a WKWebView for the active app.
//
// Integrates into BrowserWindow's leading rail area alongside the tab bar.

struct PinnedAppRailView: View {

    @Environment(ChromeState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var apps: [PinnedWebApp] {
        state.prefs.pinnedWebApps.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Which app tile is hovered, for the Chrome-class hover wash.
    @State private var hoveredAppID: String? = nil
    @State private var addButtonHovered = false

    var body: some View {
        if !apps.isEmpty {
            VStack(spacing: 0) {
                // App icon tiles
                ForEach(apps) { app in
                    appTile(app)
                }
                // Add app button
                addButton
            }
            .padding(.vertical, HiveSpacing.s4)
            .frame(width: state.isPinnedAppsExpanded ? 200 : 44)
            .background(.hiveMist.opacity(0.08))
            .animation(.hiveCollapse, value: state.isPinnedAppsExpanded)
        }
    }

    // MARK: - App Tile

    private func appTile(_ app: PinnedWebApp) -> some View {
        let isActive = state.activePinnedAppID == app.id
        let isHovered = hoveredAppID == app.id
        return Button {
            if isActive {
                state.isPinnedAppsExpanded = false
                state.activePinnedAppID = nil
            } else {
                state.selectPinnedApp(id: app.id)
            }
        } label: {
            HStack(spacing: HiveSpacing.s8) {
                // Icon
                if let favicon = app.faviconURL {
                    FaviconView(url: favicon)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: app.fallbackIcon)
                        .font(HiveTypography.font(.panelTitleRegular))
                        .foregroundStyle(.hiveGraphite)
                        .frame(width: 20, height: 20)
                }

                // Unread badge
                if app.unreadCount > 0 {
                    Text("\\(app.unreadCount)")
                        .hiveType(.caption2)
                        .foregroundStyle(.hiveBackground)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.hiveAccent, in: Capsule())
                        .fixedSize()
                }

                // Name (only when expanded)
                if state.isPinnedAppsExpanded {
                    Text(app.name)
                        .hiveType(.caption1)
                        .foregroundStyle(isActive ? .hiveAccent : .hiveInk)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, state.isPinnedAppsExpanded ? HiveSpacing.s8 : HiveSpacing.s12)
            .padding(.vertical, HiveSpacing.s8)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r6)
                    .fill(isActive ? Color.hiveAccent.opacity(0.1) : Color.hiveSurface.opacity(isHovered ? 0.45 : 0))
            )
            .contentShape(Rectangle())
            .animation(.hiveMicro, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredAppID = hovering ? app.id : nil
        }
        .contextMenu {
            Button(role: .destructive) {
                state.unpinApp(id: app.id)
            } label: {
                Label("Unpin", systemImage: "pin.slash")
            }
        }
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            state.pinActiveTabAsApp()
        } label: {
            HStack(spacing: HiveSpacing.s8) {
                Image(systemName: "plus")
                    .font(HiveTypography.font(.caption1Medium))
                    .foregroundStyle(.hiveGraphite)
                    .frame(width: 20, height: 20)
                if state.isPinnedAppsExpanded {
                    Text("Pin Current Tab")
                        .hiveType(.caption1)
                        .foregroundStyle(.hiveGraphite)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, state.isPinnedAppsExpanded ? HiveSpacing.s8 : HiveSpacing.s12)
            .padding(.vertical, HiveSpacing.s8)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r6)
                    .fill(Color.hiveSurface.opacity(addButtonHovered ? 0.45 : 0))
            )
            .contentShape(Rectangle())
            .animation(.hiveMicro, value: addButtonHovered)
        }
        .buttonStyle(.plain)
        .onHover { addButtonHovered = $0 }
    }
}
