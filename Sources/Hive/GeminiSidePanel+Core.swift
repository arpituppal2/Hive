//
//  GeminiSidePanel+Core.swift
//  Hive
//
//  Carved out of GeminiSidePanel.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: 
//

import SwiftUI
import HiveCore

// MARK: - GeminiSidePanel + Core

@MainActor
extension GeminiSidePanel {


    var lastMessageID: UUID? { state.geminiMessages.last?.id }


    var body: some View {
        VStack(spacing: 0) {
            header
            contextModeControl
            Divider()

            // Context scope preview — Dia-style diagnostics showing what context the AI used
            if let diag = state.lastContextDiagnostics {
                contextScopePreview(diag)
            }

            if state.geminiMessages.isEmpty {
                emptyState
            } else {
                messageList
            }

            councilVerdictSection
            deepResearchProgress
            modelFooter
            inputArea
        }
        .frame(width: 340)
        .background(HiveDesign.Material.panel)
        .overlay(alignment: .leading) {
            Divider().opacity(0.35)
        }
        .onAppear {
            voiceOutput.onFinished = { @MainActor in
                state.voiceCoordinator.finishSpeaking()
            }
            refreshHeadsUp()
        }
        // Keep the related-memory strip live: it must follow tab switches,
        // in-tab navigations, and new captures/notes.
        .onChange(of: state.activeTabID) { _, _ in refreshHeadsUp() }
        .onChange(of: state.activePageContext?.url?.absoluteString) { _, _ in refreshHeadsUp() }
        .onChange(of: state.memoryRevision) { _, _ in refreshHeadsUp() }
        .onDisappear {
            voiceTurnTask?.cancel()
            voiceOutput.stop()
            state.cancelVoiceCommand()
        }
    }
}
