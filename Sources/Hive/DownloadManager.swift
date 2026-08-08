import SwiftUI
import AppKit
import CefKit

// MARK: - DownloadManagerSheet
//
// Chrome/Safari-style download manager. Shows native progress snapshots and
// completed history with Finder reveal. CefKit currently exposes no supported
// active-download control API, so the active row is intentionally observational.

struct DownloadManagerSheet: View {
    @Environment(BrowserState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmClear: Bool = false

    private var activeDownloads: [DownloadItem] {
        state.downloads.filter { !$0.isComplete && !$0.isCanceled && !$0.isInterrupted }
    }
    private var completedDownloads: [DownloadItem] {
        state.downloads.filter { $0.isComplete || $0.isCanceled || $0.isInterrupted }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle")
                    .font(HiveDesign.Typography.dialogTitle)
                    .foregroundStyle(.blue)

                Text("Downloads")
                    .font(HiveDesign.Typography.subHeadingBold)

                Spacer()

                if !completedDownloads.isEmpty {
                    Button(action: { confirmClear = true }) {
                        Text("Clear finished")
                            .font(HiveDesign.Typography.sidebarItemMedium)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .alert("Clear finished downloads?", isPresented: $confirmClear) {
                        Button("Clear", role: .destructive) { _ = state.clearFinishedDownloads() }
                        Button("Cancel", role: .cancel) {}
                    }
                }

                Button(action: { state.isDownloadsPanelOpen = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(HiveDesign.Typography.bodyLarge)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            if state.downloads.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.dotted")
                        .font(HiveDesign.Typography.heroDisplay)
                        .foregroundStyle(.tertiary)
                    Text("No downloads")
                        .font(HiveDesign.Typography.panelTitleMedium)
                        .foregroundStyle(.secondary)
                    Text("Downloaded files will appear here")
                        .font(HiveDesign.Typography.sidebarItem)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if !activeDownloads.isEmpty {
                            Section {
                                ForEach(activeDownloads) { download in
                                    ActiveDownloadRow(download: download)
                                    Divider().opacity(0.4).padding(.leading, 52)
                                }
                            } header: {
                                sectionHeader("Active", count: activeDownloads.count)
                            }
                        }

                        if !completedDownloads.isEmpty {
                            Section {
                                ForEach(completedDownloads) { download in
                                    CompletedDownloadRow(download: download)
                                    Divider().opacity(0.4).padding(.leading, 52)
                                }
                            } header: {
                                sectionHeader("Completed", count: completedDownloads.count)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 440, height: 400)
        .background(HiveDesign.Material.panel)
        .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 6)
        .padding(24)
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(HiveDesign.Typography.smallLabelBold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(HiveDesign.Material.panel)
    }
}

// MARK: - ActiveDownloadRow

private struct ActiveDownloadRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let download: DownloadItem
    @State private var isHovered: Bool = false

    private var statusIcon: String { "arrow.down.circle.fill" }
    private var statusColor: Color { .blue }

    private var progressText: String {
        if download.progress > 0 && download.progress < 1 {
            return "\(Int(download.progress * 100))%"
        }
        return "Downloading…"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: statusIcon)
                .font(HiveDesign.Typography.subHeadingMedium)
                .foregroundStyle(statusColor)
                .frame(width: 28, height: 28)
                .background(statusColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(download.suggestedName)
                    .font(HiveDesign.Typography.bodyMedium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.blue)
                            .frame(width: max(0, geo.size.width * download.progress), height: 4)
                    }
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: download.progress)
                }
                .frame(height: 4)

                Text(progressText)
                    .font(HiveDesign.Typography.buttonCaption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if isHovered {
                Text("Native controls unavailable")
                    .font(HiveDesign.Typography.buttonCaption)
                    .foregroundStyle(.tertiary)
                    .help("CefKit currently reports download progress but does not expose pause, resume, or cancel controls")
                    .accessibilityLabel("Download controls unavailable")
                    .accessibilityHint("The download is being monitored by the browser; controls will appear when the engine exposes them")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .onHover { isHovered = $0 }
    }
}

// MARK: - CompletedDownloadRow

private struct CompletedDownloadRow: View {
    let download: DownloadItem
    @Environment(BrowserState.self) private var state
    @State private var isHovered: Bool = false

    private var isCanceled: Bool { download.isCanceled }
    private var isInterrupted: Bool { download.isInterrupted }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isInterrupted ? "exclamationmark.triangle.fill" : (isCanceled ? "xmark.circle.fill" : "checkmark.circle.fill"))
                .font(HiveDesign.Typography.subHeadingMedium)
                .foregroundColor(isInterrupted ? .orange : (isCanceled ? .secondary : .green))
                .frame(width: 28, height: 28)
                .background((isInterrupted ? Color.orange : (isCanceled ? Color.secondary : Color.green)).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(download.suggestedName)
                    .font(HiveDesign.Typography.bodyMedium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if isInterrupted {
                    Text("Interrupted — can’t resume")
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundColor(.orange)
                } else {
                    Text(isCanceled ? "Canceled" : "Complete")
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isHovered {
                HStack(spacing: 8) {
                    if isInterrupted {
                        Button(action: { state.openDownloadSource(id: download.id) }) {
                            Image(systemName: "arrow.up.right.square")
                                .font(HiveDesign.Typography.sidebarItem)
                                .foregroundStyle(Color.hiveAccent)
                        }
                        .buttonStyle(.plain)
                        .help("Open download source in a new tab")
                        .accessibilityLabel("Open download source")
                        .accessibilityHint("The interrupted transfer cannot resume; opens its source in a new tab")
                    }

                    if !isCanceled, !isInterrupted, download.destinationURL != nil {
                        Button(action: { showInFinder() }) {
                            Image(systemName: "folder")
                                .font(HiveDesign.Typography.sidebarItem)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Show in Finder")

                        Button(action: { openFile() }) {
                            Image(systemName: "eye")
                                .font(HiveDesign.Typography.sidebarItem)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Open file")
                    }

                    // Remove from list
                    Button(action: {
                        _ = state.removeDownloadFromHistory(id: download.id)
                    }) {
                        Image(systemName: "trash")
                            .font(HiveDesign.Typography.sidebarItem)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove from list")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .onHover { isHovered = $0 }
    }

    private func showInFinder() {
        if let dest = download.destinationURL {
            NSWorkspace.shared.activateFileViewerSelecting([dest])
        }
    }

    private func openFile() {
        if let dest = download.destinationURL {
            NSWorkspace.shared.open(dest)
        }
    }
}
