//
//  BrowserState+Peek.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Tab Peek (Arc-style live preview) | - Link hover peek (Arc-style link preview) | - Media mini-player (Arc-style auto player)
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Peek

@MainActor
extension BrowserState {


    /// Pooled tab IDs in MRU order, for the overlay's always-present
    /// CefWebView stack (keeps pooled browsers alive between peeks).
    var previewPoolTabIDs: [String] {
        previewPool.map(\.tabID)
    }


    /// Returns the pooled preview model for a tab, creating it (and evicting
    /// the LRU) as needed. Returns nil for tabs that can't preview:
    /// hibernated tabs (waking them just to peek would waste memory) and the
    /// web start page (chrome, not content).
    @discardableResult
    func previewModel(for tab: Tab) -> CefWebViewModel? {
        guard !tab.isHibernated,
              let url = tab.model.url ?? tab.savedURL,
              url.absoluteString != "about:blank",
              url.scheme?.lowercased() != "hive"
        else { return nil }
        if let idx = previewPool.firstIndex(where: { $0.tabID == tab.id }) {
            var entry = previewPool.remove(at: idx)
            entry.lastUsed = Date()
            previewPool.insert(entry, at: 0)
            return entry.model
        }
        if previewPool.count >= Self.maxPreviewPoolSize {
            previewPool.removeLast()
        }
        var opts = CefBrowserOptions()
        opts.profile = tab.isPrivate ? CefProfile.incognito() : cefProfile(for: tab.workspaceID)
        let entry = TabPreviewEntry(
            tabID: tab.id,
            model: CefWebViewModel(url: url, options: opts),
            lastUsed: Date()
        )
        previewPool.insert(entry, at: 0)
        return entry.model
    }


    func peekModel(for tabID: String) -> CefWebViewModel? {
        previewPool.first(where: { $0.tabID == tabID })?.model
    }


    /// Drops a tab's pooled preview (stale content) — called on close and on
    /// navigation so the next peek reloads the current page.
    func invalidatePreview(for tabID: String) {
        previewPool.removeAll { $0.tabID == tabID }
        if activePeekTabID == tabID {
            activePeekTabID = nil
        }
    }


    /// Shows the peek card for a tab, anchored to its pill's window-space rect.
    /// Skips the active tab — hovering the current tab's pill previews nothing.
    func beginPeek(tabID: String, anchorRect: CGRect) {
        guard let tab = tabs.first(where: { $0.id == tabID }), tabID != activeTabID else { return }
        peekEndTask?.cancel()
        isPeekCardHovered = false
        peekAnchorRect = anchorRect
        // Mutual exclusion with link peeks (the two never overlap, but be safe).
        activePeekLinkURL = nil
        linkPreviewModel = nil
        activePeekTabID = tabID
        previewModel(for: tab)   // ensure an entry exists (nil → placeholder card)
    }


    /// Dismisses the peek after a short grace period — unless the cursor has
    /// moved onto the card, in which case the peek stays (click-to-switch).
    /// Clears whichever peek kind is active (tab or link).
    func scheduleEndPeek() {
        peekEndTask?.cancel()
        peekEndTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled, let self else { return }
            guard !self.isPeekCardHovered else { return }
            if self.activePeekLinkURL != nil {
                self.endLinkPeek()
            } else {
                self.activePeekTabID = nil
            }
        }
    }


    /// Called when the cursor enters the peek card: cancels any pending
    /// dismissal so the card doesn't vanish under the cursor.
    func holdPeek() {
        peekEndTask?.cancel()
        isPeekCardHovered = true
    }


    /// Called when the cursor leaves the peek card: dismisses after the same
    /// short grace as leaving the pill, so moving card → back onto the pill
    /// doesn't flicker (dismiss-then-re-show). If the cursor instead lands on
    /// another pill, its beginPeek cancels this before it fires.
    func releasePeek() {
        isPeekCardHovered = false
        scheduleEndPeek()
    }


    /// Hides the peek card immediately (tab switch/close/navigation). Pooled
    /// preview renderers stay alive (the overlay's CefWebViews never leave the
    /// window hierarchy) for instant re-peeks. The transient link-preview
    /// renderer is destroyed (it's recreated per link hover).
    func endPeek() {
        peekEndTask?.cancel()
        isPeekCardHovered = false
        activePeekTabID = nil
        activePeekLinkURL = nil
        linkPreviewModel = nil
    }


    /// Shows the peek card for a hovered link, anchored near the link's
    /// position in the page. The page's injected probe reports link hovers via
    /// console messages; this creates the dedicated transient renderer.
    func beginLinkPeek(urlString: String, anchorRect: CGRect, sourceModel: CefWebViewModel? = nil) {
        guard let url = URL(string: urlString),
              url.scheme == "http" || url.scheme == "https",
              activePeekTabID == nil else { return }
        let sourceIsPrivate = sourceModel.flatMap { model in
            tabs.first(where: { $0.model === model })?.isPrivate
        } ?? activeTab?.isPrivate ?? false
        peekEndTask?.cancel()
        isPeekCardHovered = false
        peekAnchorRect = anchorRect
        activePeekLinkURL = url.absoluteString
        if let model = linkPreviewModel {
            model.load(url)
        } else {
            var opts = CefBrowserOptions()
            opts.profile = sourceIsPrivate ? CefProfile.incognito() : cefProfile(for: currentWorkspaceID)
            linkPreviewModel = CefWebViewModel(url: url, options: opts)
        }
    }


    /// Hides the link peek and destroys its transient renderer.
    func endLinkPeek() {
        activePeekLinkURL = nil
        linkPreviewModel = nil
    }


    /// Clicking a link-peek card opens the link in a new tab (Arc-style
    /// "keep open" behavior without leaving the page first).
    func openLinkFromPeek(_ urlString: String) {
        guard let url = URL(string: urlString),
              url.scheme == "http" || url.scheme == "https" else { return }
        endPeek()
        newTab(url: url, activate: true)
    }


    /// Parses the page probe's console bridge. Strict gate: only the exact
    /// magic prefix, only http(s) destinations, only from the visible page's
    /// model. A page can spam console.log; nothing outside the gate is acted
    /// on, and a forged peek can at worst preview a URL the page could already
    /// navigate to — no privilege is gained.
    func handlePageConsoleMessage(_ message: String, from model: CefWebViewModel) {
        // Gate on a VISIBLE page: the active tab, or the split-secondary pane
        // when split view is live (both panes are under the cursor).
        guard let paneFrame = peekPaneFrame(for: model) else { return }
        if message == "HIVE_LINK_CLEAR" {
            scheduleEndPeek()
            return
        }
        guard message.hasPrefix("HIVE_LINK_PEEK|") else { return }
        let parts = message.split(separator: "|", maxSplits: 3)
        guard parts.count == 4,
              let x = Double(parts[2]),
              let y = Double(parts[3]),
              let decoded = parts[1].removingPercentEncoding,
              let url = URL(string: decoded),
              url.scheme == "http" || url.scheme == "https"
        else { return }
        // Viewport coords → window coords via the pane that rendered the page.
        // (In split view the secondary pane's viewport origin is offset from
        // the content area's origin by the primary pane's extent.)
        let anchor = CGRect(
            x: paneFrame.minX + CGFloat(x) - 4,
            y: paneFrame.minY + CGFloat(y) - 4,
            width: 8, height: 8
        )
        beginLinkPeek(urlString: url.absoluteString, anchorRect: anchor, sourceModel: model)
    }


    /// The window-space frame of the pane that hosts a given model, or nil if
    /// the model isn't visible (background tab, pooled preview, closed tab).
    /// In split view the panes are derived from the content area frame plus
    /// orientation and ratio; otherwise the whole content area is the pane.
    func peekPaneFrame(for model: CefWebViewModel) -> CGRect? {
        let isActive = model === activeTab?.model
        let isSecondary = model === splitSecondaryTab?.model
        guard isActive || isSecondary else { return nil }
        guard isSplitViewActive else { return contentAreaFrame }
        // Split view: carve the secondary pane out of the content area. Note:
        // the draggable divider's ~8pt hit area is not subtracted, so the
        // anchor is a hair off the true pane edge — harmless, the card clamps
        // to the window.
        let base = contentAreaFrame
        let ratio = CGFloat(min(max(splitRatio, 0.1), 0.9))
        switch splitOrientation {
        case .sideBySide:
            let primaryWidth = base.width * ratio
            if isSecondary {
                return CGRect(x: base.minX + primaryWidth, y: base.minY,
                              width: base.width - primaryWidth, height: base.height)
            }
            return CGRect(x: base.minX, y: base.minY, width: primaryWidth, height: base.height)
        case .topBottom:
            let primaryHeight = base.height * ratio
            if isSecondary {
                return CGRect(x: base.minX, y: base.minY + primaryHeight,
                              width: base.width, height: base.height - primaryHeight)
            }
            return CGRect(x: base.minX, y: base.minY, width: base.width, height: primaryHeight)
        }
    }


    /// The tab the mini-player currently controls.
    var miniPlayerTab: Tab? {
        guard let id = miniPlayerTabID else { return nil }
        return tabs.first { $0.id == id }
    }


    /// True while the mini-player should be visible: a tab is designated, it
    /// isn't the one being viewed (switching back hides it), and it isn't
    /// hibernated (a sleeping tab's browser is closed — controls would no-op).
    var isMiniPlayerVisible: Bool {
        guard let id = miniPlayerTabID, let tab = miniPlayerTab, !tab.isHibernated else { return false }
        return id != activeTabID
    }


    /// Shared auto-trigger for tab selection: leaving a playing tab surfaces
    /// the mini-player; returning to it hides the player. Workspace switches
    /// call the same rule inline (the active tab changes without selectTab).
    /// VIDEO tabs get the OS-level Picture-in-Picture window first (a real
    /// always-on-top player); audio-only tabs get the in-window control
    /// surface directly. PiP rejection falls back to the in-window player.
    func updateMiniPlayerAfterSwitch(from oldID: String?, to newID: String) {
        if let oldID, oldID != newID, mediaPlayingTabIDs.contains(oldID) {
            if mediaVideoPlayingTabIDs.contains(oldID) {
                requestVideoPiP(tabID: oldID)
            } else {
                miniPlayerTabID = oldID
            }
        } else if miniPlayerTabID == newID {
            miniPlayerTabID = nil
        }
    }


    /// Returns the active tab's ID and model for PIP auto-triggering.
    /// Used by the mini-player's Float button to target the currently
    /// visible page for OS-level Picture-in-Picture.
    func getActiveTab() -> (id: String, model: CefWebViewModel)? {
        guard let tab = tabs.first(where: { $0.id == activeTabID }) else { return nil }
        return (tab.id, tab.model)
    }


    func requestVideoPiP(tabID: String, userInitiated: Bool = false) {
        guard let tab = tabs.first(where: { $0.id == tabID }), !tab.isHibernated else { return }
        lastPiPWasUserInitiated = userInitiated
        // Note: from the auto-trigger this usually falls back (HIVE_PIP|failed)
        // because requestPictureInPicture requires transient activation, which
        // the tab-switch click consumes. From the mini-player's explicit
        // "Float" button it succeeds — that button click is the gesture. No
        // leavepictureinpicture tracking, so re-requesting on every switch-away
        // from the same video tab is accepted; the OS window's own close
        // control covers exit.
        tab.model.executeJavaScript("""
        (function(){
          var v = null;
          var els = document.querySelectorAll('video');
          for (var i = 0; i < els.length; i++){
            if (!els[i].paused && !els[i].ended && els[i].readyState > 2) { v = els[i]; break; }
          }
          if (!v || typeof v.requestPictureInPicture !== 'function') {
            console.log('HIVE_PIP|failed');
            return;
          }
          v.requestPictureInPicture().then(function(){
            console.log('HIVE_PIP|entered');
          }).catch(function(){
            console.log('HIVE_PIP|failed');
          });
        })();
        """)
    }


    /// Handles the PiP attempt result from the page: entered → the OS window
    /// took over, so no in-window player is needed; failed → fall back to the
    /// in-window control surface, but only if the user has actually left the
    /// tab (otherwise the player would pop over the page they're viewing).
    func handlePiPConsoleMessage(_ message: String, from model: CefWebViewModel) {
        guard let tabID = tabs.first(where: { $0.model === model })?.id else { return }
        if message == "HIVE_PIP|entered" {
            if miniPlayerTabID == tabID { miniPlayerTabID = nil }
        } else if message == "HIVE_PIP|failed", tabID != activeTabID {
            miniPlayerTabID = tabID
            // Honest feedback gated to explicit intent: the auto-trigger's
            // rejection is expected (activation consumed by the tab click) and
            // the in-window card is the fallback — no error chrome. Only an
            // explicit Float-button failure surfaces the brief inline hint.
            if lastPiPWasUserInitiated {
                showMiniPlayerPiPUnavailable()
            }
        }
    }


    func showMiniPlayerPiPUnavailable() {
        piPUnavailableTask?.cancel()
        // Animated so the hint's .transition(.opacity) actually plays.
        withAnimation(isReduceMotionEnabled ? nil : .easeInOut(duration: 0.15)) {
            isMiniPlayerPiPUnavailable = true
        }
        piPUnavailableTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, !Task.isCancelled else { return }
            withAnimation(isReduceMotionEnabled ? nil : .easeInOut(duration: 0.15)) {
                isMiniPlayerPiPUnavailable = false
            }
        }
    }


    /// Handles the media-state probe's console messages from any tab — a
    /// background tab's playback state matters (that's what drives the
    /// mini-player). Keeps the speaker indicators honest: only playing,
    /// unmuted, non-ended media counts.
    func handleMediaConsoleMessage(_ message: String, from model: CefWebViewModel) {
        guard let tabID = tabs.first(where: { $0.model === model })?.id else { return }
        switch message {
        case "HIVE_MEDIA|video":
            mediaPlayingTabIDs.insert(tabID)
            mediaVideoPlayingTabIDs.insert(tabID)
        case "HIVE_MEDIA|audio":
            mediaPlayingTabIDs.insert(tabID)
            mediaVideoPlayingTabIDs.remove(tabID)
        default: // "HIVE_MEDIA|stopped" (and any unknown HIVE_MEDIA noise)
            mediaPlayingTabIDs.remove(tabID)
            mediaVideoPlayingTabIDs.remove(tabID)
            // The player's tab stopped — hide the player rather than showing a
            // dead card.
            if miniPlayerTabID == tabID { miniPlayerTabID = nil }
        }
    }


    /// Pauses or resumes the mini-player's tab playback via the page's own
    /// media element (real control, not a mock). No-op when the tab is
    /// hibernated (its browser is closed) or the page has no media.
    func toggleMiniPlayerPlayback() {
        guard let tab = miniPlayerTab, !tab.isHibernated else { return }
        tab.model.executeJavaScript("""
        (function(){
          var els = document.querySelectorAll('video,audio');
          for (var i = 0; i < els.length; i++){
            if (!els[i].paused) { els[i].pause(); return; }
          }
          for (var i = 0; i < els.length; i++){
            if (els[i].paused && !els[i].ended) { els[i].play(); return; }
          }
        })();
        """)
    }


    /// Mutes or unmutes the mini-player's tab via the page's own media
    /// element. Muting stops the speaker indicator (probe reports stopped)
    /// and hides the player — matching the "no mini-player for muted media"
    /// behavior Arc uses.
    func toggleMiniPlayerMute() {
        guard let tab = miniPlayerTab, !tab.isHibernated else { return }
        tab.model.executeJavaScript("""
        (function(){
          var els = document.querySelectorAll('video,audio');
          for (var i = 0; i < els.length; i++){
            if (!els[i].paused) { els[i].muted = !els[i].muted; return; }
          }
        })();
        """)
    }


    /// Dismisses the mini-player (playback in the tab continues).
    func closeMiniPlayer() {
        miniPlayerTabID = nil
    }


    /// Returns the tab to the foreground and hides the mini-player.
    func returnToMiniPlayerTab() {
        guard let id = miniPlayerTabID else { return }
        miniPlayerTabID = nil
        selectTab(id: id)
    }
}
