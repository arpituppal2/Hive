//
//  GeminiSidePanel+Voice.swift
//  Hive
//
//  Carved out of GeminiSidePanel.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Voice turn disclosure
//

import SwiftUI
import HiveCore

// MARK: - GeminiSidePanel + Voice

@MainActor
extension GeminiSidePanel {





    // MARK: - Voice turn disclosure

    /// Explains the current voice lifecycle without rendering the transcript,
    /// classifier reason, page data, URLs, tab IDs, or model output.
    @ViewBuilder
    var voiceTurnDisclosure: some View {
        if let disclosure = VoiceTurnDisclosure.make(
            state: state.voiceCoordinator.state,
            pendingDecision: state.voiceCoordinator.pendingDecision
        ) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: disclosure.iconName)
                    .font(HiveDesign.Typography.sectionHeader)
                    .foregroundStyle(disclosure.isBlocking
                                     ? HiveDesign.State.warning
                                     : Color.hiveAccent)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(disclosure.title)
                        .font(HiveDesign.Typography.captionSemiBold)
                        .foregroundStyle(.primary)
                    Text(disclosure.detail)
                        .font(HiveDesign.Typography.microLabelSecondary)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let instruction = disclosure.instruction {
                        Text(instruction)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(disclosure.isBlocking
                                             ? HiveDesign.State.warning
                                             : HiveDesign.Text.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 4)

                if disclosure.isBlocking {
                    Button("Cancel") {
                        voiceTurnTask?.cancel()
                        voiceOutput.stop()
                        state.cancelVoiceCommand()
                    }
                    .buttonStyle(.plain)
                    .font(HiveDesign.Typography.microLabel)
                    .foregroundStyle(HiveDesign.State.warning)
                    .accessibilityLabel("Cancel voice request")
                    .help("Stop this voice request without running an action")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                disclosure.isBlocking
                    ? HiveDesign.State.warning.opacity(0.08)
                    : HiveDesign.Surface.level1
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(disclosure.isBlocking
                          ? HiveDesign.State.warning.opacity(0.18)
                          : Color.white.opacity(0.04))
                    .frame(height: 1)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Voice turn: \(disclosure.title)")
            .accessibilityValue(
                [disclosure.detail, disclosure.instruction]
                    .compactMap { $0 }
                    .joined(separator: " ")
            )
        }
    }


    var voiceStatusLabel: String {
        switch state.voiceCoordinator.state {
        case .listening: return "LISTENING"
        case .transcribing: return "TRANSCRIBING"
        case .classifying: return "ROUTING"
        case .clarifying: return "CLARIFYING"
        case .executing: return "WORKING"
        case .speaking: return "SPEAKING"
        case .failed: return "VOICE ERROR"
        case .cancelled: return "CANCELLED"
        case .unsupported: return "UNAVAILABLE"
        case .completed: return "READY"
        case .idle: return "READY"
        }
    }


    func toggleVoiceRecording() {
        if speechRecognizer.isRecording {
            let finalText = speechRecognizer.transcribedText
            speechRecognizer.stopRecording()
            Task { @MainActor in
                state.voiceCoordinator.markTranscribing()
                await submitVoiceTranscript(finalText)
            }
            return
        }

        voiceTurnTask?.cancel()
        voiceOutput.stop()
        state.resetVoiceCommand()
        voiceTurnTask = Task { @MainActor in
            state.voiceCoordinator.beginListening()
            if !speechRecognizer.isAuthorized {
                guard await speechRecognizer.requestAuthorization() else {
                    state.cancelVoiceCommand()
                    return
                }
            }
            guard !Task.isCancelled else { return }
            do {
                try speechRecognizer.startRecording()
            } catch {
                state.cancelVoiceCommand()
                state.geminiMessages.append(GeminiMessage(
                    role: .assistant,
                    text: "Voice input is unavailable: \(error.localizedDescription)"
                ))
            }
        }
    }


    func submitVoiceTranscript(_ transcript: String) async {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            state.cancelVoiceCommand()
            return
        }
        let outcome = await state.submitVoiceCommand(text, referencedTabIDs: referencedTabIDs)
        switch outcome {
        case .clarification(let prompt, _):
            state.geminiMessages.append(GeminiMessage(role: .assistant, text: prompt))
            voiceOutput.speak(prompt)
        case .executed(let result, _):
            if result.shouldSpeak {
                voiceOutput.speak(result.text)
            } else {
                state.voiceCoordinator.finishSpeaking()
            }
        case .unsupported(let message, _):
            state.geminiMessages.append(GeminiMessage(role: .assistant, text: message))
            voiceOutput.speak(message)
        case .failed(let message, _):
            state.geminiMessages.append(GeminiMessage(role: .assistant, text: message))
            voiceOutput.speak(message)
        case .cancelled:
            break
        }
    }


    func send() {
        guard !input.isEmpty else { return }
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let tabIDs = referencedTabIDs
        input = ""
        referencedTabIDs = []
        showTabAutocomplete = false

        // /research <query> → live web research through the user's Vane
        // (Perplexica) instance, with cited sources (honest "vane" provider).
        // Requires the space so "/researcher" or "/researching" never collide.
        if trimmedInput == "/research" || trimmedInput.hasPrefix("/research ") {
            let query = String(trimmedInput.dropFirst("/research".count))
                .trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else {
                state.geminiMessages.append(GeminiMessage(role: .user, text: trimmedInput))
                state.geminiMessages.append(GeminiMessage(
                    role: .assistant,
                    text: "Usage: `/research <query>` — runs a live web research query through your Vane (Perplexica) instance and returns a cited answer. Configure the URL in Settings → Performance → Web Research."))
                return
            }
            state.geminiMessages.append(GeminiMessage(role: .user, text: "/research \(query)"))
            state.performResearch(query: query)
            return
        }

        // /deep <query> → multi-step deep research: plan sub-queries → search →
        // read top sources → synthesize → refine. 15+ sources, iterative.
        if trimmedInput == "/deep" || trimmedInput.hasPrefix("/deep ") {
            let query = String(trimmedInput.dropFirst("/deep".count))
                .trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else {
                state.geminiMessages.append(GeminiMessage(role: .user, text: trimmedInput))
                state.geminiMessages.append(GeminiMessage(
                    role: .assistant,
                    text: "Usage: `/deep <query>` — runs multi-step deep research across 15+ sources with iterative refinement. Results include a full synthesis with cited sources and a table of contents."))
                return
            }
            state.geminiMessages.append(GeminiMessage(role: .user, text: "/deep \(query)"))
            state.performDeepResearch(query: query)
            return
        }

        let text = stripTabReferences(from: trimmedInput)
        state.sendGeminiMessage(text, referencedTabIDs: tabIDs)
    }


    /// Strips @tab-name references from the display text while preserving
    /// the referenced tab IDs for the AI context.
    func stripTabReferences(from text: String) -> String {
        var result = text
        for tabID in referencedTabIDs {
            if let tab = state.tabs.first(where: { $0.id == tabID }) {
                let title = tab.model.title.isEmpty ? (tab.model.url?.host ?? "tab") : tab.model.title
                let ref = "@\(title)"
                result = result.replacingOccurrences(of: ref, with: "")
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }


    /// Detects @tab references in the current input and updates autocomplete state.
    func detectTabReferences() {
        guard let lastAt = input.lastIndex(of: "@") else {
            showTabAutocomplete = false
            tabAutocompleteFilter = ""
            return
        }
        let afterAt = String(input[input.index(after: lastAt)...])
        // Show all tabs when @ is typed with nothing after it
        if afterAt.isEmpty {
            tabAutocompleteFilter = ""
            showTabAutocomplete = true
            autocompleteIndex = 0
            return
        }
        // Split by spaces: only the first "word" after @ is the filter
        let words = afterAt.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        let filterWord = String(words[0])
        // If there's more text after a space following the filter word,
        // the user has moved on — hide autocomplete. Otherwise show it.
        if words.count > 1 && !words[1].isEmpty {
            showTabAutocomplete = false
        } else {
            tabAutocompleteFilter = filterWord.lowercased()
            showTabAutocomplete = true
            autocompleteIndex = 0
        }
    }


    /// Tabs matching the current @filter (current workspace, not active tab).
    var matchingTabs: [BrowserState.Tab] {
        let candidates = state.tabs.filter {
            $0.workspaceID == state.currentWorkspaceID && $0.id != state.activeTabID
        }
        guard !tabAutocompleteFilter.isEmpty else { return Array(candidates.prefix(8)) }
        return candidates.filter { tab in
            let title = tab.model.title.isEmpty ? (tab.model.url?.host ?? "") : tab.model.title
            return title.lowercased().contains(tabAutocompleteFilter)
        }
    }


    /// Inserts an @tab reference into the input text, preserving any text
    /// that follows the @filter word (e.g., "compare @goo prices" → "compare @Google prices").
    func insertTabReference(_ tab: BrowserState.Tab) {
        referencedTabIDs.insert(tab.id)
        guard let lastAt = input.lastIndex(of: "@") else { return }
        let title = tab.model.title.isEmpty ? (tab.model.url?.host ?? "tab") : tab.model.title
        let displayTitle = title.count > 30 ? String(title.prefix(27)) + "..." : title
        let beforeAt = String(input[..<lastAt])
        let afterAt = String(input[input.index(after: lastAt)...])
        // Find where the filter word ends (first space or end of string)
        let filterEnd: String.Index
        if let spaceIdx = afterAt.firstIndex(of: " ") {
            filterEnd = spaceIdx
        } else {
            filterEnd = afterAt.endIndex
        }
        // Everything after the filter word (including the space separator)
        let trailing = String(afterAt[filterEnd...])
        input = beforeAt + "@" + displayTitle + trailing
        showTabAutocomplete = false
    }


    /// Removes a tab from the referenced set.
    func removeTabReference(_ tabID: String) {
        referencedTabIDs.remove(tabID)
        // Also remove @tab-name from input text
        if let tab = state.tabs.first(where: { $0.id == tabID }) {
            let title = tab.model.title.isEmpty ? (tab.model.url?.host ?? "tab") : tab.model.title
            let displayTitle = title.count > 30 ? String(title.prefix(27)) + "..." : title
            input = input.replacingOccurrences(of: "@" + displayTitle, with: "")
        }
    }
}
