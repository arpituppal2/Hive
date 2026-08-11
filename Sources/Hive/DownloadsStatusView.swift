import SwiftUI
import AppKit

// MARK: - DownloadsStatusView
//
// Chrome-parity downloads indicator: a compact arrow-down button that fills
// with the aggregate progress of active downloads. Clicking opens the
// Downloads panel; hovering shows a mini popover with the active transfers.
// Idle state matches the old static button, so the toolbar stays quiet until
// a download actually starts.

struct DownloadsStatusView: View {
    @Environment(BrowserState.self) private var state
    @State private var isPopoverPresented: Bool = false
    @State private var isHovered: Bool = false

    private var activeDownloads: [DownloadItem] {
        state.downloads.filter { !$0.isComplete && !$0.isCanceled && !$0.isInterrupted }
    }

    /// Average progress of active downloads, 0...1.
    private var aggregateProgress: Double {
        guard !activeDownloads.isEmpty else { return 0 }
        return activeDownloads.reduce(0) { $0 + $1.progress } / Double(activeDownloads.count)
    }

    private var hasActive: Bool { !activeDownloads.isEmpty }
    private var hasFinished: Bool {
        state.downloads.contains { $0.isComplete }
    }

    /// Small delay so the popover doesn't flicker when the cursor crosses
    /// from the button onto the popover itself.
    @State private var popoverDismissTask: Task<Void, Never>?

    var body: some View {
        Button(action: {
            state.isDownloadsPanelOpen = true
            dismissPopover()
        }) {
            ZStack {
                if hasActive {
                    // Progress ring + count badge while transfers run.
                    Circle()
                        .stroke(HiveDesign.Surface.level2, lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: aggregateProgress)
                        .stroke(
                            Color.hiveAccent,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(HiveDesign.Text.primary)
                } else {
                    Image(systemName: hasFinished ? "arrow.down.circle.fill" : "arrow.down.circle")
                        .font(.system(size: HiveDesign.Icon.small))
                        .foregroundStyle(hasFinished ? Color.green : HiveDesign.Text.secondary)
                }
            }
            .frame(width: 22, height: 22)
            .overlay(alignment: .topTrailing) {
                if hasActive {
                    Text("\(activeDownloads.count)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(minWidth: 12, minHeight: 12)
                        .background(Color.hiveAccent)
                        .clipShape(Circle())
                        .offset(x: 3, y: -3)
                }
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? HiveDesign.Surface.level2 : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                popoverDismissTask?.cancel()
                if hasActive { isPopoverPresented = true }
            } else {
                // Give the cursor time to reach the popover before dismissing.
                popoverDismissTask?.cancel()
                popoverDismissTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(220))
                    guard !Task.isCancelled else { return }
                    isPopoverPresented = false
                }
            }
        }
        .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
            DownloadsStatusPopover(activeDownloads: activeDownloads) {
                dismissPopover()
            }
        }
        .onDisappear { popoverDismissTask?.cancel() }
        .help(hasActive
              ? "\(activeDownloads.count) download\(activeDownloads.count == 1 ? "" : "s") — \(Int(aggregateProgress * 100))%"
              : "Downloads")
        .accessibilityLabel("Downloads")
        .accessibilityValue(hasActive
                            ? "\(activeDownloads.count) active, \(Int(aggregateProgress * 100)) percent"
                            : (hasFinished ? "Recent downloads available" : "No active downloads"))
    }

    private func dismissPopover() {
        popoverDismissTask?.cancel()
        isPopoverPresented = false
    }
}

// MARK: - DownloadsStatusPopover

private struct DownloadsStatusPopover: View {
    let activeDownloads: [DownloadItem]
    /// Called when the popover's own "Open Downloads" action fires, so the
    /// parent can dismiss the popover alongside opening the panel.
    let onOpenDownloads: () -> Void
    @Environment(BrowserState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Downloads")
                .font(HiveDesign.Typography.smallLabelBold)
                .foregroundStyle(.secondary)

            ForEach(activeDownloads.prefix(3)) { download in
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(Color.hiveAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(download.suggestedName)
                            .font(HiveDesign.Typography.bodyMedium)
                            .lineLimit(1)
                        Text(progressLabel(for: download))
                            .font(HiveDesign.Typography.buttonCaption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 8)
                }
            }

            if activeDownloads.count > 3 {
                Text("+ \(activeDownloads.count - 3) more…")
                    .font(HiveDesign.Typography.buttonCaption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button(action: {
                state.isDownloadsPanelOpen = true
                onOpenDownloads()
            }) {
                Label("Open Downloads", systemImage: "arrow.down.circle")
                    .font(HiveDesign.Typography.smallLabelBold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.hiveAccent)
        }
        .padding(12)
        .frame(width: 240)
    }

    private func progressLabel(for download: DownloadItem) -> String {
        switch download.controlState.state {
        case .paused:
            let base = download.progress > 0 && download.progress < 1
                ? "\(Int(download.progress * 100))%" : "0%"
            return "Paused — \(base)"
        case .pauseRequested: return "Pausing…"
        case .resumeRequested: return "Resuming…"
        case .active:
            if download.progress > 0 && download.progress < 1 {
                return "\(Int(download.progress * 100))%"
            }
            return "Downloading…"
        }
    }
}
