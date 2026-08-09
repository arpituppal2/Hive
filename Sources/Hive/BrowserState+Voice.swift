//
//  BrowserState+Voice.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Voice Mode (Comet)
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Voice

@MainActor
extension BrowserState {


    func toggleVoiceMode() {
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.spring) {
            isVoiceModeActive.toggle()
        }
    }


    /// Cancels the shared trusted turn lifecycle, including any pending
    /// confirmation request retained by the gateway.
    func cancelVoiceCommand() {
        voiceTurnGeneration &+= 1
        stopGeminiGeneration()
        if let trustedTurnGateway {
            trustedTurnGateway.cancel()
        } else {
            voiceCoordinator.cancel()
        }
    }


    /// Resets the shared trusted turn lifecycle before a new recording.
    func resetVoiceCommand() {
        voiceTurnGeneration &+= 1
        stopGeminiGeneration()
        if let trustedTurnGateway {
            trustedTurnGateway.reset()
        } else {
            voiceCoordinator.reset()
        }
    }


    /// Routes one completed transcript through the same Swarm context and
    /// approval surfaces used by text chat. The recognizer never executes work
    /// directly; this is the only browser-shell entry point for voice commands.
    func submitVoiceCommand(_ transcript: String,
                            referencedTabIDs: Set<String> = []) async -> VoiceCommandOutcome {
        voiceTurnGeneration &+= 1
        let turnGeneration = voiceTurnGeneration
        let pageAvailable = !isPrivateBrowsing && buildPageContext() != nil
        let request = TrustedTurnRequest(
            text: transcript,
            scope: contextMode == .workspace ? .workspace : .pageOnly,
            pageText: nil,
            isPrivate: isPrivateBrowsing,
            aiContextAllowed: pageAvailable,
            hasActivePage: pageAvailable,
            hasResearchProvider: activeResearchProvider() != nil
        )
        guard let gateway = trustedTurnGateway else {
            return .failed(message: "Swarm voice routing is unavailable.", decision: nil)
        }
        let outcome = await gateway.submit(request) { [weak self] decision, trustedRequest in
            guard let self else {
                return TrustedTurnExecution(text: "Hive is no longer available.", providerLabel: "unavailable")
            }
            let execution = try await self.executeVoiceRoute(
                decision,
                command: trustedRequest.text,
                referencedTabIDs: referencedTabIDs
            )
            return TrustedTurnExecution(
                text: execution.text,
                providerLabel: execution.providerLabel,
                shouldSpeak: execution.shouldSpeak
            )
        }
        guard voiceTurnGeneration == turnGeneration else {
            return .cancelled
        }
        switch outcome {
        case .clarification(let prompt, let decision, _):
            return .clarification(prompt: prompt, decision: decision)
        case .executed(let result, let decision, _):
            return .executed(
                result: VoiceExecutionResult(
                    text: result.text,
                    providerLabel: result.providerLabel,
                    shouldSpeak: result.shouldSpeak
                ),
                decision: decision
            )
        case .queued(let message, let decision, _):
            return .executed(
                result: VoiceExecutionResult(
                    text: message,
                    providerLabel: "approval-pending",
                    shouldSpeak: true
                ),
                decision: decision
            )
        case .unsupported(let message, let decision, _):
            return .unsupported(message: message, decision: decision)
        case .failed(let message, let decision, _):
            return .failed(message: message, decision: decision)
        case .cancelled:
            return .cancelled
        }
    }


    /// Executes only advisory/approved routes. Consequential routes create a
    /// typed PendingAction and enter the existing policy + approval queue; this
    /// method never treats a spoken confirmation as a replacement for policy.
    func executeVoiceRoute(_ decision: VoiceRouteDecision,
                                   command: String,
                                   referencedTabIDs: Set<String>) async throws -> VoiceExecutionResult {
        switch decision.route {
        case .genericQuestion, .pageQuestion:
            let userText = command
            let placeholder = GeminiMessage(role: .assistant, text: "...")
            geminiMessages.append(GeminiMessage(role: .user, text: userText))
            geminiMessages.append(placeholder)
            let responseID = beginResponse()
            defer { finishResponse(responseID) }

            let request = SwarmResponseRequest.voice(
                route: decision.route == .pageQuestion ? .pageQuestion : .genericQuestion,
                intent: userText,
                explicitTabIDs: referencedTabIDs
            )
            do {
                let result = try await executeSharedResponse(
                    request,
                    responseID: responseID
                )
                guard responseIsCurrent(responseID), !Task.isCancelled else {
                    throw CancellationError()
                }
                if result.contextChanged {
                    replaceMessage(id: placeholder.id, text: result.text)
                    return VoiceExecutionResult(text: result.text, providerLabel: result.providerLabel, shouldSpeak: false)
                }
                lastGeminiProvider = result.providerLabel
                lastContextDiagnostics = result.diagnostics
                replaceMessage(id: placeholder.id, text: result.text)
                return VoiceExecutionResult(
                    text: result.text,
                    providerLabel: result.providerLabel,
                    shouldSpeak: true
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as UserFacingSwarmResponseError {
                guard responseIsCurrent(responseID), !Task.isCancelled else {
                    throw CancellationError()
                }
                replaceMessage(id: placeholder.id, text: error.message)
                return VoiceExecutionResult(text: error.message, providerLabel: "error", shouldSpeak: false)
            } catch {
                guard responseIsCurrent(responseID), !Task.isCancelled else {
                    throw CancellationError()
                }
                let message = "I couldn't complete that response. Please try again."
                replaceMessage(id: placeholder.id, text: message)
                return VoiceExecutionResult(text: message, providerLabel: "error", shouldSpeak: false)
            }

        case .research:
            let query = voiceResearchQuery(from: command)
            guard !query.isEmpty else {
                return VoiceExecutionResult(text: "What should I research?", providerLabel: "local")
            }
            performResearch(query: query)
            let researchProviderLabel = activeResearchProvider()?.rawValue ?? "research"
            return VoiceExecutionResult(
                text: "I started research on \(query). I’ll bring the cited brief back in the Swarm panel.",
                providerLabel: researchProviderLabel,
                shouldSpeak: true
            )

        case .organize:
            guard !isKnowledgePersistenceDegraded else {
                throw VoiceExecutionError.persistenceUnavailable
            }
            let candidates = PreferenceExtractor.extract(from: command)
            let noteID = "voice-note-\(UUID().uuidString)"
            let note = HoneycombStore.Node(
                id: noteID,
                type: .note,
                label: "Voice note",
                metadata: .object([
                    "text": .string(String(command.prefix(2_000))),
                    "workspace": .string(currentWorkspaceID.uuidString),
                    "source": .string("voice")
                ]),
                contentHash: HoneycombStore.sha256(command),
                provenance: "voice-command"
            )
            let stored: HoneycombStore.Node
            do {
                stored = try await honeycomb.insertNode(note)
            } catch {
                reportKnowledgePersistenceFailure()
                throw VoiceExecutionError.persistenceUnavailable
            }
            await hotMemory.didAccessNode(
                id: stored.id,
                sourceHint: "explicit",
                label: candidates.isEmpty ? "Voice note" : candidates.map(\.path).joined(separator: ", "),
                content: String(command.prefix(200)),
                workspaceID: currentWorkspaceID.uuidString,
                profileID: currentProfileID.uuidString
            )
            _ = await recordAuditEvent(EventLedgerStore.LedgerEvent(
                id: UUID().uuidString,
                timestamp: Date(),
                actor: "user",
                intent: command,
                actionKind: .systemEvent,
                actionPreview: "Saved as a voice note",
                trustLevel: .t2,
                policyDecision: .allowed,
                consentState: .approved,
                contextIDs: [stored.id],
                result: .success,
                provenance: "voice-command"
            ))
            let message = candidates.isEmpty
                ? "Saved that as a voice note in the current workspace."
                : "Saved it to Hive memory and filed the preference under \(candidates[0].path)."
            geminiMessages.append(GeminiMessage(role: .user, text: command))
            geminiMessages.append(GeminiMessage(role: .assistant, text: message))
            return VoiceExecutionResult(text: message, providerLabel: "local")

        case .browse:
            guard let url = voiceNavigationURL(from: command) else {
                return VoiceExecutionResult(text: "I need a valid site or search query before I can prepare navigation.", providerLabel: "local")
            }
            let action = PendingAction(
                summary: "Navigate to \(url.absoluteString)",
                detail: "Hive prepared this navigation from your spoken request. Nothing will open until the approval policy accepts it.",
                preview: "Open:\n\(url.absoluteString)",
                trustLevel: .t3,
                actionKind: .browserNavigate,
                execution: .navigate(url),
                toolInvocation: ToolInvocation.browserNavigate(url: url)
            )
            requestApproval(for: action)
            return VoiceExecutionResult(text: "I prepared that navigation and sent it to Action Approval.", providerLabel: "local")

        case .action:
            let lower = command.lowercased()
            if lower.contains("run ") || lower.contains("test") {
                await proposeRunCheck(command: command)
                return VoiceExecutionResult(text: "I prepared that check in Action Approval. Nothing runs until it is approved.", providerLabel: "local")
            }
            return VoiceExecutionResult(
                text: "I understand that as a consequential action, but I don't have a typed safe tool for it yet. I won't guess or execute it.",
                providerLabel: "local"
            )

        case .clarification:
            return VoiceExecutionResult(text: decision.clarificationPrompt ?? "What would you like Hive to do?", providerLabel: "local")

        case .unsupported:
            return VoiceExecutionResult(text: decision.clarificationPrompt ?? "That capability is unavailable.", providerLabel: "local")
        }
    }


    func voiceResearchQuery(from command: String) -> String {
        let text = command.components(separatedBy: " User clarification:").first ?? command
        let prefixes = ["/research ", "research ", "look up ", "investigate ", "find sources for "]
        for prefix in prefixes where text.lowercased().hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }


    func voiceNavigationURL(from command: String) -> URL? {
        let text = (command.components(separatedBy: " User clarification:").first ?? command)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = ["open ", "go to ", "navigate to ", "search the web for ", "search for ", "find me "]
        let body = prefixes.first(where: { text.lowercased().hasPrefix($0) }).map {
            String(text.dropFirst($0.count))
        } ?? text
        let target = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = URL(string: target),
           ["http", "https"].contains(direct.scheme?.lowercased()) {
            return direct
        }
        if target.contains("."), let site = URL(string: "https://\(target)") {
            return site
        }
        let encoded = target.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? target
        return URL(string: searchEngine.searchURL + encoded)
    }


    var browserAccentColor: Color {
        Color(hex: browserAccentColorHex) ?? Color.hiveAccent
    }
}
