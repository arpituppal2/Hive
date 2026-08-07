import SwiftUI
import HiveCore

// MARK: - DownloadBubbleIndicator
//
// Chrome-class download affordance (Chrome 2023+ "download bubble" pattern, from
// PITCH/competitive-ui-ledger.md): a toolbar-anchored icon that mirrors download state
// without opening a panel.
//
//   - Idle:      plain `arrow.down.circle`, graphite.
//   - Active:    a 1.5pt accent progress ring drawn over the icon, animating with
//                aggregate progress; the icon pulses once when a download starts.
//   - Click:     toggles the ⌘⇧J downloads panel (DownloadsView).
//
// Observes `DownloadManager.shared` directly (same pattern as DownloadsView) so the
// indicator stays live even when the panel is closed. Hidden while the omnibox is
// focused — the same rule as Chrome's toolbar, which recesses on focus.

struct DownloadBubbleIndicator: View {

    @Environment(ChromeState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var downloads: [BrowserDownload] = []
    @State private var pulse = false

    // MARK: Computed

    private var active: [BrowserDownload] {
        downloads.filter { $0.state == .inProgress || $0.state == .pending }
    }

    private var hasActive: Bool { !active.isEmpty }

    /// Mean progress across active downloads (0...1). Only read while `hasActive` is
    /// true (the ring renders conditionally), so returning 0 for an empty set is safe.
    private var aggregateProgress: Double {
        let list = active
        guard !list.isEmpty else { return 0 }
        return list.reduce(0) { $0 + $1.progress } / Double(list.count)
    }

    var body: some View {
        Button {
            state.toggleDownloadsPanel()
        } label: {
            ZStack {
                Image(systemName: "arrow.down.circle")
                    .font(HiveTypography.font(.bodyMedium))
                    .foregroundStyle(hasActive ? state.activeAccentColor : Color.hiveGraphite)

                if hasActive {
                    Circle()
                        .trim(from: 0, to: CGFloat(aggregateProgress))
                        .stroke(state.activeAccentColor,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 19, height: 19)
                        .scaleEffect(pulse ? 1.18 : 1.0)
                        .animation(reduceMotion ? nil : .hiveMicro, value: aggregateProgress)
                }
            }
            .frame(width: HiveSpacing.s24, height: HiveDimension.omnibarInputH)
        }
        .buttonStyle(.plain)
        .help(hasActive ? "Downloads — \(Int(aggregateProgress * 100))%" : "Downloads (⌘⇧J)")
        .accessibilityLabel(hasActive
                            ? "Downloads, \(Int(aggregateProgress * 100)) percent"
                            : "Downloads")
        .task { await observeDownloads() }
        .onChange(of: hasActive) { _, nowActive in
            guard nowActive else { return }
            // Chrome-class start pulse: the ring pops in when a download begins.
            withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.6)) { pulse = true }
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.6)) { pulse = false }
            }
        }
    }

    // MARK: Observation (same pattern as DownloadsView)

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
}
