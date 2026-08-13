//
//  BrowserState+Studio.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Studio Panel | - Sheets Panel (SHEET-002)
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Studio

@MainActor
extension BrowserState {


    /// Rolls back the last applied Studio edit. For git repos this uses
    /// `git restore` (stronger); otherwise it uses the .hivebak fallback.
    /// Clears `lastAppliedEdit` on success so the panel goes back to idle.
    func rollbackLastEdit() async {
        guard let edit = lastAppliedEdit else { return }
        // Clear immediately to prevent double-tap, but restore on failure
        // so the undo button remains available for retry.
        lastAppliedEdit = nil
        do {
            if await studioWorkspace.isGitRepository() {
                _ = try await studioWorkspace.gitRestore(file: edit.relativePath)
            } else {
                try await studioWorkspace.rollback(edit)
            }
            studioCheckResult = nil
            studioCheckError = nil
        } catch {
            // Rollback failed — the edit is still applied on disk.
            // Restore lastAppliedEdit so the user can retry.
            lastAppliedEdit = edit
            studioCheckError = (error as? StudioWorkspace.StudioError)?.errorDescription ?? error.localizedDescription
        }
    }


    func toggleStudioPanel() {
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.spring) {
            isStudioPanelOpen.toggle()
        }
    }


    func toggleSheetsPanel() {
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.spring) {
            isSheetsPanelOpen.toggle()
        }
    }
}
