import SwiftUI
import HiveCore

// MARK: - ArchivedRowView
//
// One archived-tab row with a hover wash (the shelf previously rendered static rows
// with no feedback). Restore = click. Time-ago uses a shared static formatter — the
// per-call RelativeDateTimeFormatter construction was the same perf anti-pattern
// fixed on StartPage / SwarmHome / TabOverview.

private struct ArchivedRowView: View {
    let record: ArchivedTab
    @Environment(ChromeState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        Button {
            state.restoreArchivedTab(record.id).flatMap { state.selectTab($0.id) }
        } label: {
            HStack(spacing: HiveSpacing.s8) {
                Group {
                    if let faviconURL = record.faviconURL {
                        FaviconView(url: faviconURL)
                            .frame(width: HiveDimension.favicon, height: HiveDimension.favicon)
                    } else {
                        Image(systemName: "globe")
                            .font(HiveTypography.font(.caption2))
                            .foregroundStyle(.hiveGraphite)
                    }
                }
                .frame(width: HiveDimension.favicon)

                VStack(alignment: .leading, spacing: 1) {
                    Text(record.title.isEmpty ? (record.url?.host ?? "Untitled") : record.title)
                        .hiveType(.chromeTitle)
                        .foregroundStyle(.hiveInk)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(timeAgo(record.archivedAt))
                        .hiveType(.chromeLabel)
                        .foregroundStyle(.hiveMist)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.counterclockwise.circle")
                    .font(HiveTypography.font(.caption3Medium))
                    .foregroundStyle(.hiveAccent.opacity(0.6))
            }
            .padding(.leading, HiveSpacing.s8 + HiveSpacing.s16)
            .padding(.trailing, HiveSpacing.s4)
            .frame(height: 32)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r6)
                    .fill(Color.hiveSurface.opacity(isHovered ? 0.55 : 0.3))
            )
            .contentShape(Rectangle())
            .animation(reduceMotion ? nil : .hiveMicro, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Restore \(record.title)")
        .accessibilityLabel("Restore archived tab: \(record.title)")
    }

    private func timeAgo(_ date: Date) -> String {
        Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - ArchivedShelfView
//
// A collapsible shelf at the bottom of the vertical tab bar showing recently archived tabs.
// Provides one-click restore for archived tabs directly from the sidebar.
// The shelf is collapsed by default and animates open to show archived tab rows.
// Each row displays favicon, title, and time-ago label. Clicking restores and selects.

struct ArchivedShelfView: View {

    @Environment(ChromeState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isShelfExpanded = false
    @State private var hoveringHeader = false

    private var isExpanded: Bool { state.prefs.sidebarOpen }

    /// Archived tabs filtered to the active space (or global if sourceSpaceID is nil).
    /// Shows most recently archived first, capped at 10.
    private var archivedTabs: [ArchivedTab] {
        state.archivedTabs
            .filter { $0.sourceSpaceID == nil || $0.sourceSpaceID == state.activeSpace.id }
            .suffix(10)
            .reversed()
    }

    var body: some View {
        if state.archivedTabs.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.hiveBorderSubtle)
                    .frame(height: 1)
                    .padding(.horizontal, isExpanded ? HiveSpacing.s8 : 0)

                shelfContent
            }
        }
    }

    @ViewBuilder
    private var shelfContent: some View {
        VStack(spacing: 2) {
            shelfHeader

            if isShelfExpanded && isExpanded {
                ForEach(archivedTabs) { record in
                    ArchivedRowView(record: record)
                }
            }
        }
        .padding(.vertical, HiveSpacing.s4)
        .padding(.horizontal, isExpanded ? 0 : HiveSpacing.s4)
        .animation(reduceMotion ? nil : .hiveMicro, value: isShelfExpanded)
    }

    private var shelfHeader: some View {
        Button {
            withAnimation(reduceMotion ? nil : .hiveMicro) { isShelfExpanded.toggle() }
        } label: {
            HStack(spacing: HiveSpacing.s8) {
                if isExpanded {
                    Image(systemName: isShelfExpanded ? "chevron.down" : "chevron.right")
                        .font(HiveTypography.font(.microTinyMedium))
                        .foregroundStyle(.hiveGraphite)

                    Image(systemName: "tray.full")
                        .font(HiveTypography.font(.captionMedium))
                        .foregroundStyle(.hiveGraphite)

                    Text("Archived")
                        .hiveType(.chromeTitle)
                        .foregroundStyle(.hiveGraphite)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                } else {
                    Image(systemName: "tray.full")
                        .font(HiveTypography.font(.captionMedium))
                        .foregroundStyle(.hiveGraphite)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.leading, isExpanded ? HiveSpacing.s8 : 0)
            .padding(.trailing, isExpanded ? HiveSpacing.s4 : 0)
            .frame(height: isExpanded ? 32 : 24)
            .frame(maxWidth: .infinity)
            // Hover wash matching the rail's tab-row treatment.
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r6)
                    .fill(Color.hiveSurface.opacity(hoveringHeader ? 0.45 : 0))
            )
            .contentShape(Rectangle())
            .animation(reduceMotion ? nil : .hiveMicro, value: hoveringHeader)
        }
        .buttonStyle(.plain)
        .onHover { hoveringHeader = $0 }
        .help("Recently archived tabs")
        .accessibilityLabel("Recently archived tabs. \(state.archivedTabs.count) archived.")
    }
}
