import SwiftUI
import CefSwiftUI

// MARK: - MiniPlayerView
//
// Arc-style auto mini-player: when the user switches away from a tab whose
// page is playing audio/video, a compact player floats in the bottom-right
// corner of the window. It is a CONTROL SURFACE over the real page — play,
// pause, and mute drive the tab's actual media elements via injected JS (no
// fake rendering, no second renderer). Clicking the card returns to the tab.
//
// Honest state: the card shows the tab's real title/favicon and a live
// playing indicator from the media probe. When the page's media stops, the
// probe reports it and the card dismisses itself.

struct MiniPlayerView: View {
    @Environment(ChromiumBrowserState.self) private var state
    @State private var isHovered: Bool = false

    var body: some View {
        if let tab = state.miniPlayerTab, state.isMiniPlayerVisible {
            card(tab)
                .padding(16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func card(_ tab: ChromiumBrowserState.Tab) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            if state.isMiniPlayerPiPUnavailable {
                Text("Picture-in-Picture isn't available on this page")
                    .font(HiveDesign.Typography.microLabelMedium)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 220, alignment: .trailing)
                    .transition(.opacity)
            }
            controlsRow(tab)
        }
        // Card chrome wraps BOTH the hint and the controls row — wrapping only
        // controlsRow would leave the hint floating outside the material card.
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(HiveDesign.Surface.level1, in: RoundedRectangle(cornerRadius: HiveDesign.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HiveDesign.Radius.md, style: .continuous)
                .stroke(HiveDesign.Surface.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 3)
        .onHover { isHovered = $0 }
    }

    private func controlsRow(_ tab: ChromiumBrowserState.Tab) -> some View {
        HStack(spacing: 10) {
            // Return target: click anywhere on the card to go back to the tab.
            Button(action: { state.returnToMiniPlayerTab() }) {
                HStack(spacing: 10) {
                    tabIcon(tab)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tab.model.title.isEmpty ? (tab.savedURL?.host ?? "Playing") : tab.model.title)
                            .font(HiveDesign.Typography.sidebarItemSemiBold)
                            .foregroundStyle(HiveDesign.Text.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(HiveDesign.Accent.primary)
                                .frame(width: 6, height: 6)
                                .opacity(isHovered ? 1 : 0.55)
                            Text("Playing")
                                .font(HiveDesign.Typography.buttonCaption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: 140, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Return to playing tab")
            .accessibilityHint("Shows the tab that is currently playing")
            .help("Return to tab")

            Divider().frame(height: 22)

            // Play / pause — drives the page's real media element.
            Button(action: { state.toggleMiniPlayerPlayback() }) {
                Image(systemName: "playpause.fill")
                    .font(HiveDesign.Typography.sectionHeader)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play or pause playback")
            .accessibilityHint("Controls playback in the original tab")
            .help("Play / pause")

            // Mute / unmute — drives the page's real media element.
            Button(action: { state.toggleMiniPlayerMute() }) {
                Image(systemName: "speaker.slash.fill")
                    .font(HiveDesign.Typography.sectionHeader)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mute or unmute playback")
            .accessibilityHint("Toggles audio in the original tab; muting may dismiss this player")
            .help("Mute")

            // Float as OS Picture-in-Picture. Only for tabs with a playing
            // VIDEO (requestVideoPiP no-ops on audio-only tabs — a dead button
            // is a slop marker). Best-effort: a button click is a real gesture,
            // but CEF's embedder-injected executeJavaScript may not carry
            // transient activation into the page, so the promise can reject;
            // the card stays either way (HIVE_PIP|failed falls back cleanly).
            if let tabID = state.miniPlayerTabID,
               state.mediaVideoPlayingTabIDs.contains(tabID) {
                Button(action: { state.requestVideoPiP(tabID: tabID, userInitiated: true) }) {
                    Image(systemName: "pip.enter")
                        .font(HiveDesign.Typography.sectionHeader)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Float as Picture-in-Picture")
                .accessibilityHint("Opens the playing video in the system Picture-in-Picture window")
                .help("Float as Picture-in-Picture")
            }

            // Dismiss (playback continues in the tab).
            Button(action: { state.closeMiniPlayer() }) {
                Image(systemName: "xmark")
                    .font(HiveDesign.Typography.captionSemiBold)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss mini-player")
            .accessibilityHint("Playback continues in the original tab")
            .help("Dismiss")
        }
    }

    @ViewBuilder
    private func tabIcon(_ tab: ChromiumBrowserState.Tab) -> some View {
        if let favicon = tab.model.faviconURL {
            FaviconImage(url: favicon)
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: "play.rectangle.fill")
                .font(HiveDesign.Typography.subHeading)
                .foregroundStyle(HiveDesign.Accent.primary)
        }
    }
}
