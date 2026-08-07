import SwiftUI
import HiveCore

// MARK: - TabPill (horizontal tab cell)
//
// A single horizontal tab pill (SPEC §8.1). Favicon + truncated title + close-on-hover;
// pinned → favicon-only at 48pt; active/hover/inactive visual states; a 2pt accent loading
// bar at the bottom while loading. Close button: 16×16 hit, 9×9 visual, 120ms fade, always
// visible when active.
//
// Animation philosophy (Hive signature):
//   - Active tab: the pill background fades in with a micro spring (0.18s response, 0.90 damping);
//     the bottom corners go square and the backdrop tucks into the omnibar below — the
//     Chrome/Brave/Zen merged-tab look (see `pillShape` + `activeTabTuck`).
//   - Hover: background opacity transitions at 120ms — quick enough to feel responsive.
//   - Close button: appears/disappears with a 120ms opacity + scale(0.8→1) combo.
//   - Tab switch: the active pill's background smoothly transfers via a subtle crossfade
//     (no matched geometry on the whole pill — that would cause layout jumps). The square
//     bottom + tuck appear with the same micro spring as the background.
//
// Drag-and-drop reorder is driven by the hosting TabBarView (drag is a tab-strip concern,
// not a pill concern). The pill exposes a stable identity via `.id(tab.id)`.
//
// All animations honor reduce-motion (micro spring → 0.12s linear fallback).

struct TabPill: View {

    @Environment(ChromeState.self) private var state
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let tab: BrowserTab
    let density: TabDensity
    @Binding var isHovered: Bool        // synthesized by the strip to coordinate hover/drag states

    @State private var localHover = false
    @State private var resolvingFavicon: Data?

    // Shared state — computed so every sibling sub-view (favicon / title / closeButton / …)
    // can reach them. `body`-local `let`s don't propagate into those separate scopes.
    private var isActive: Bool { tab.isActive }
    private var isPinned: Bool { tab.isPinned }
    private var hovered: Bool { isHovered || localHover }
    private var showClose: Bool { isActive || hovered || tab.isLoading }

    var body: some View {
        HStack(spacing: HiveSpacing.s8) {
            favicon
            if !isPinned {
                title
            }
            if showClose && !isPinned {
                closeButton
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.6)),
                        removal: .opacity
                    ))
            }
        }
        .padding(.leading, isPinned ? 0 : HiveSpacing.s8)
        .padding(.trailing, isPinned ? 0 : (showClose ? HiveSpacing.s4 : HiveSpacing.s8))
        .frame(height: density.pillHeight)
        .frame(minWidth: isPinned ? HiveDimension.tabPillPinnedW : density.minWidth,
               maxWidth: isPinned ? HiveDimension.tabPillPinnedW : density.maxWidth)
        .background(
            pillBackground(isActive: isActive, hovered: hovered)
                .animation(hoverAnim, value: hovered)
                .animation(hoverAnim, value: isActive)
        )
        .overlay(alignment: .bottomTrailing) { audioBadge }
        .overlay(alignment: .bottom) { loadingBar }
        .clipShape(pillShape)
        .contentShape(pillShape)
        // Chrome/Brave/Zen verbatim: the active tab's square bottom tucks into the
        // omnibar's top edge so tab strip + address bar read as one continuous surface.
        .background(alignment: .top) { activeTabTuck }
        .onHover { localHover = $0; isHovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tab.displayTitle)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .accessibilityHint("Tab. Double tap to switch.")
        .tabHoverPreview(for: tab)
        .contextMenu { contextMenu }
    }

    @ViewBuilder private var contextMenu: some View {
        Button("Close Tab") { state.closeTab(tab.id) }
        Button("Close Other Tabs") { state.closeOtherTabs(keeping: tab.id) }
        Button("Close Tabs to the Right") { state.closeTabsToRight(of: tab.id) }
        Divider()
        Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") { state.togglePin(tab.id) }
        Button(tab.isMuted ? "Unmute Site" : "Mute Site") { state.toggleMute(tab.id) }
        Divider()
        Button("Duplicate Tab") { state.duplicateTab(tab.id) }
        Divider()
        Button("Reload Tab") { state.selectTab(tab.id); state.requestNav(.reload) }
    }

    // MARK: Subviews

    @ViewBuilder private var favicon: some View {
        if isPinned {
            faviconImage.frame(width: HiveDimension.faviconVertical, height: HiveDimension.faviconVertical)
                .frame(width: HiveDimension.tabPillPinnedW, height: density.pillHeight)
        } else {
            faviconImage.frame(width: HiveDimension.favicon, height: HiveDimension.favicon)
        }
    }

    @ViewBuilder private var faviconImage: some View {
        if let url = tab.faviconURL {
            FaviconView(url: url)
        } else {
            Image(systemName: "globe")
                .font(.system(size: tab.isPinned ? 14 : 11, weight: .regular))
                .foregroundStyle(foregroundColor(tab: tab, scheme: scheme))
        }
    }

    private var title: some View {
        HStack(spacing: HiveSpacing.s4) {
            Text(tab.displayTitle)
                .hiveType(.chromeTitle)
                .foregroundStyle(foregroundColor(tab: tab, scheme: scheme))
                .lineLimit(1)
                .truncationMode(.tail)
            if let promise = tab.promise, !promise.isEmpty {
                promiseBadge(promise, color: tab.promiseColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Promise badge (slice 8): a small colored dot/pill next to the tab title.
    private func promiseBadge(_ text: String, color: String?) -> some View {
        let token = HiveColorToken(rawValue: color ?? "accent") ?? .accent
        let tokenColor = Color(token)
        return HStack(spacing: 2) {
            Circle()
                .fill(tokenColor)
                .frame(width: 6, height: 6)
            if !tab.isPinned {
                Text(text)
                    .hiveType(.chromeLabel)
                    .foregroundStyle(foregroundColor(tab: tab, scheme: scheme))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 3)
        .frame(height: 14)
        .background(tokenColor.opacity(0.15))
        .clipShape(Capsule())
        .accessibilityLabel("Promise: \(text)")
    }

    private var closeButton: some View {
        Button {
            state.closeTab(tab.id)
        } label: {
            Image(systemName: "xmark")
                .font(HiveTypography.font(.microBold))
                .foregroundStyle(.hiveGraphite)
                .frame(width: HiveDimension.closeButtonHit, height: HiveDimension.closeButtonHit)
        }
        .buttonStyle(.plain)
        .opacity(hovered || tab.isActive ? 1 : 0)
        .animation(reduceMotion ? nil : .hiveCloseButtonFade, value: hovered || tab.isActive)
        .accessibilityLabel("Close tab")
    }

    // MARK: Per-pill loading bar — reintroduced (2026-07-29)
    //
    // "Brand Guidelines v1.0" removed the per-pill 2pt load bar in favor of an amber
    // hexagon *pulse* alone (visible only on the active tab's omnibar). That left
    // BACKGROUND tabs loading completely invisibly — switch to a tab and "it just
    // appears done," the most disorienting kind of clunky. Every browser (Safari's
    // per-tab bar, Chrome's, Arc's, Comet's) shows background-tab load progress.
    // This renders the already-plumbed `tab.loadProgress` (0..1) as a 2pt amber line
    // at the pill's bottom edge — fingers the active-tab omnibar bar but distinct,
    // so background loads register at a glance. Spec-legal: SPEC §29.2 rule-1 calls
    // for "progress bar, not a chrome spinner." See PITCH/browser-feel-fixes.md fix #5.

    private var loadingBar: some View {
        GeometryReader { geo in
            let progress = tab.isLoading ? max(0.05, tab.loadProgress) : 0
            state.activeAccentColor
                .frame(width: geo.size.width * progress, height: 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(tab.isLoading ? 1 : 0)
        }
        .frame(height: 2)
        .allowsHitTesting(false)
        .animation(reduceMotion ? .linear(duration: 0.12) : .hiveMicro, value: tab.loadProgress)
        .animation(reduceMotion ? .linear(duration: 0.12) : .hiveCloseButtonFade, value: tab.isLoading)
        .accessibilityHidden(true)
    }

    // MARK: Audio badge (peaker icon when audible)

    @ViewBuilder private var audioBadge: some View {
        if tab.isPlayingAudio || tab.isMuted {
            Button {
                state.toggleMute(tab.id)
            } label: {
                Image(systemName: tab.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(HiveTypography.font(.microMedium))
                    .foregroundStyle(tab.isMuted ? .hiveGraphite : state.activeAccentColor)
                    .padding(2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tab.isMuted ? "Unmute tab" : "Mute tab")
        }
    }

    // MARK: Chrome/Brave/Zen verbatim pill shape
    //
    // Unified 8px radius everywhere EXCEPT the active tab's bottom corners, which go
    // square so the tab tucks into the omnibar — the signature merged look (no floating
    // pill, no top accent bar). Brave/Chrome/Arc/Zen all distinguish the active tab by
    // this connection, not by a painted indicator.

    private var pillShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: density.cornerRadius,
            bottomLeadingRadius: isActive ? 0 : density.cornerRadius,
            bottomTrailingRadius: isActive ? 0 : density.cornerRadius,
            topTrailingRadius: density.cornerRadius
        )
    }

    /// Downward extension of the active tab's backdrop into the omnibar's top edge.
    /// Applied AFTER `.clipShape`, so it is not clipped to the pill bounds. It is
    /// pillHeight + 8pt tall; the strip's bottom margin is 4pt, so the tuck lands
    /// 4pt into the omnibar's empty top margin (its 26pt input is centered in the
    /// 34pt bar) — zero content overlap, one continuous surface.
    @ViewBuilder private var activeTabTuck: some View {
        if isActive {
            Color.hiveSurface
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: density.cornerRadius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: density.cornerRadius
                ))
                .frame(height: density.pillHeight + HiveSpacing.s8)
        }
    }

    // MARK: Background (active / hover / inactive)

    private func pillBackground(isActive: Bool, hovered: Bool) -> some View {
        Group {
            if isActive {
                Color.hiveSurface
            } else if hovered {
                Color.hiveSurface.opacity(0.5)
            } else {
                Color.clear
            }
        }
    }

    // SF Pro Rounded requires System Rounded for chrome text — but here we use the typography
    // helper. Resolve active vs inactive foreground color per SPEC §8.1.
    private func foregroundColor(tab: BrowserTab, scheme: ColorScheme) -> Color {
        if tab.isActive { return Color.hiveInk }
        return Color.hiveGraphite
    }
}

// MARK: - Animation helpers

private extension TabPill {
    /// Hover/active state animation — micro spring by default, 0.12s linear with reduce motion.
    var hoverAnim: Animation {
        reduceMotion ? .linear(duration: 0.12) : .hiveMicro
    }
}

// MARK: - Reduce-motion animation helper
//
// When the OS accessibility "Reduce Motion" is on, motion falls back to 0.12s linear per
// SPEC §5 / HiveMotion. This modifier flips any spring to the linear fallback.

private extension Animation {
    /// Reduce-motion fallback: maps a chosen animation to the 0.12s linear fallback when
    /// `reduceMotion` is true. Usage: `.animation(reduceMotion ? nil/fallback : .hiveMicro, …)`.
    func disabledWhenReduceMotion(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.12) : self
    }
}
