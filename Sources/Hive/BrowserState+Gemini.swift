//
//  BrowserState+Gemini.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Gemini Side Panel
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Gemini

@MainActor
extension BrowserState {


    // MARK: - Gemini Side Panel

    func toggleGeminiPanel() {
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.spring) {
            isGeminiPanelOpen.toggle()
        }
    }
}
