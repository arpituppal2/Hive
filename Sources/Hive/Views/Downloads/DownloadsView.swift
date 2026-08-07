import SwiftUI
import AppKit
import HiveCore

// MARK: - DownloadsView

/// A panel listing the browser's active and completed downloads. Rendered as an overlay from
/// the chrome so the content behind it stays intact.
struct DownloadsView: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var downloads: [BrowserDownload] = []

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, HiveSpacing.s16)
                .padding(.vertical, HiveSpacing.s12)

            Divider().overlay(Color.hiveBorderSubtle)

            if downloads.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(downloads) { download in
                        DownloadRow(download: download)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.hiveSurface)
        .frame(width: 420, height: 360)
        .task { await observeDownloads() }
    }

    private func observeDownloads() async {
        let initial = await DownloadManager.shared.allDownloads()
        downloads = initial

        let (stream, token) = await DownloadManager.shared.observe()
        await withTaskCancellationHandler {
            for await download in stream {
                if let idx = downloads.firstIndex(where: { $0.id == download.id }) {
                    downloads[idx] = download
                } else {
                    downloads.insert(download, at: 0)
                }
            }
        } onCancel: {
            Task { await DownloadManager.shared.finishObservation(token) }
        }
    }

    private var header: some View {
        HStack {
            Text("Downloads")
                .hiveType(.chromeTitle)
                .foregroundStyle(.hiveInk)
            Spacer()
            Button("Clear Finished") {
                Task { await DownloadManager.shared.clearFinished() }
            }
            .buttonStyle(.borderless)
            .disabled(downloads.allSatisfy { $0.state == .inProgress || $0.state == .pending })
        }
    }

    private var emptyState: some View {
        VStack(spacing: HiveSpacing.s8) {
            Image(systemName: "arrow.down.circle")
                .font(HiveTypography.font(.display2))
                .foregroundStyle(.hiveGraphite)
            Text("No downloads")
                .hiveType(.bodySmall)
                .foregroundStyle(.hiveGraphite)
        }
    }
}

// MARK: - DownloadRow

private struct DownloadRow: View {

    @Environment(ChromeState.self) private var state
    @State private var isHovered = false
    let download: BrowserDownload

    var body: some View {
        HStack(spacing: HiveSpacing.s12) {
            Image(systemName: iconName)
                .foregroundStyle(.hiveGraphite)
                .frame(width: HiveDimension.toolbarButton)

            VStack(alignment: .leading, spacing: 2) {
                Text(download.displayName)
                    .hiveType(.body)
                    .foregroundStyle(.hiveInk)
                    .lineLimit(1)

                if !statusText.isEmpty {
                    Text(statusText)
                        .hiveType(.caption2)
                        .foregroundStyle(.hiveGraphite)
                }
            }

            Spacer()

if download.state == .inProgress || download.state == .pending {
                 HStack(spacing: HiveSpacing.s4) {
                     Button(action: { pause() }) {
                         Image(systemName: "pause.circle.fill")
                             .foregroundStyle(.orange)
                     }
                     .buttonStyle(.borderless)
                     .help("Pause download")
                     .accessibilityLabel("Pause download")
                     Button(action: { cancel() }) {
                         Image(systemName: "xmark")
                             .foregroundStyle(.hiveGraphite)
                     }
                     .buttonStyle(.borderless)
                     .help("Cancel download")
                     .accessibilityLabel("Cancel download")
                 }
             } else if download.state == .paused {
                 HStack(spacing: HiveSpacing.s4) {
                     Button(action: { resume() }) {
                         Image(systemName: "play.circle.fill")
                             .foregroundStyle(.green)
                     }
                     .buttonStyle(.borderless)
                     .help("Resume download")
                     .accessibilityLabel("Resume download")
                     Button(action: { cancel() }) {
                         Image(systemName: "xmark")
                             .foregroundStyle(.hiveGraphite)
                     }
                     .buttonStyle(.borderless)
                     .help("Cancel download")
                     .accessibilityLabel("Cancel download")
                 }
             } else if download.state == .failed, download.resumeData != nil {
                Button(action: { retry() }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.hiveGraphite)
                }
                .buttonStyle(.borderless)
                .help("Retry download")
                .accessibilityLabel("Retry download")
            } else if download.state == .completed, download.destinationURL != nil {
                Button(action: { reveal() }) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.hiveGraphite)
                }
                .buttonStyle(.borderless)
                .help("Reveal in Finder")
                .accessibilityLabel("Reveal in Finder")
            }
        }
        .padding(.vertical, HiveSpacing.s8)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r8)
                .fill(isHovered ? Color.hiveSurface : Color.clear)
        )
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .hiveMicro) { isHovered = hovering }
        }
        .overlay(alignment: .bottom) {
            if download.state == .inProgress || download.state == .pending {
                GeometryReader { g in
                    Rectangle()
                        .fill(state.activeAccentColor.opacity(0.25))
                        .frame(width: g.size.width * download.progress)
                }
                .frame(height: 2)
            }
        }
    }

    private var iconName: String {
        switch download.state {
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .inProgress, .pending: return "arrow.down.circle"
        case .paused: return "pause.circle"
        }
    }

    private var statusText: String {
        switch download.state {
        case .inProgress, .pending: return "\(Int(download.progress * 100))% · \(download.progressText)"
        case .completed: return "Done"
        case .failed: return download.errorDescription ?? "Failed"
        case .cancelled: return "Cancelled"
        case .paused: return "Paused"
        }
    }

    private func cancel() {
        Task { await WebKitDownloadCoordinator.shared.cancel(downloadID: download.id) }
    }

    private func pause() {
        Task { await WebKitDownloadCoordinator.shared.pause(downloadID: download.id) }
    }

    private func resume() {
        Task { await WebKitDownloadCoordinator.shared.resume(downloadID: download.id) }
    }

    private func retry() {
        Task { await WebKitDownloadCoordinator.shared.retry(downloadID: download.id) }
    }

    private func reveal() {
        guard let url = download.destinationURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
