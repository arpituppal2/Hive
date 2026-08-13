import SwiftUI

// MARK: - SyncStatusView

/// Small sync status indicator for the chrome bottom bar. Shows an icon
/// matching the current sync state (green = available, blue = syncing,
/// orange = error, gray = unavailable) with a tooltip on hover.
struct SyncStatusView: View {
    @Environment(BrowserState.self) private var state
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.syncState.iconName)
                .font(HiveDesign.Typography.microLabel)
                .foregroundStyle(state.syncState.color)
                .symbolEffect(.pulse, isActive: state.syncState == .syncing)
                .help(syncTooltip)
        }
        .frame(width: 20, height: 20)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .popover(isPresented: $isHovered, arrowEdge: .top) {
            syncPopover
        }
    }

    private var syncTooltip: String {
        switch state.syncState {
        case .unavailable: return "Sync is not configured or available"
        case .available: return "Sync is available"
        case .syncing: return "Syncing with iCloud…"
        case .error(let msg): return msg
        }
    }

    @ViewBuilder
    private var syncPopover: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(state.syncState.color)
                    .frame(width: 8, height: 8)
                Text(state.syncState.label)
                    .font(HiveDesign.Typography.smallLabelBold)
            }

            if let lastSync = state.lastSyncDate {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(HiveDesign.Typography.microLabel)
                    Text("Last sync: " + lastSync.formatted(.relative(presentation: .named)))
                        .font(HiveDesign.Typography.microLabel)
                }
                .foregroundStyle(.secondary)
            }

            if state.syncState.isActive {
                Text("Tabs, bookmarks, and history are encrypted end-to-end.")
                    .font(HiveDesign.Typography.microLabel)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: 180)
            }
        }
        .padding(10)
    }
}