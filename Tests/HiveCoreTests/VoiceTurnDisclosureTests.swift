import Testing
@testable import HiveCore

@Suite("VoiceTurnDisclosure")
struct VoiceTurnDisclosureTests {
    @Test("clarification explains missing fields without exposing classifier details")
    func clarification() {
        let decision = VoiceRouteDecision(
            route: .clarification,
            confidence: 0.99,
            reason: "The page contains a secret transcript that must never be shown",
            missingFields: ["target", "desired result"],
            clarificationPrompt: "Which secret should I use?"
        )

        let disclosure = VoiceTurnDisclosure.make(state: .clarifying, pendingDecision: decision)

        #expect(disclosure?.kind == .clarification)
        #expect(disclosure?.title == "Clarification needed")
        #expect(disclosure?.detail == "Nothing has run yet. Hive needs the target, and your desired result before it can continue.")
        #expect(disclosure?.instruction == "Answer the question to continue, or say “cancel” to stop.")
        #expect(disclosure?.isBlocking == true)
        #expect(disclosure?.detail.contains("secret") == false)
        #expect(disclosure?.detail.contains("Nothing has run yet") == true)
        #expect(disclosure?.detail.contains("0.99") == false)
    }

    @Test("confirmation states that no action ran and gives only typed controls")
    func confirmation() {
        let decision = VoiceRouteDecision(
            route: .action,
            confidence: 0.93,
            reason: "Run the project tests",
            requiresConfirmation: true
        )

        let disclosure = VoiceTurnDisclosure.make(state: .completed, pendingDecision: decision)

        #expect(disclosure?.kind == .confirmation)
        #expect(disclosure?.title == "Confirmation needed")
        #expect(disclosure?.detail == "Nothing has run yet. Hive is waiting for your approval.")
        #expect(disclosure?.instruction == "Say “confirm” to continue or “cancel” to stop.")
        #expect(disclosure?.isBlocking == true)
    }

    @Test("pending clarification takes precedence over completed state")
    func pendingClarificationPrecedence() {
        let decision = VoiceRouteDecision(
            route: .clarification,
            confidence: 0.99,
            reason: "Missing page",
            missingFields: ["active page"],
            clarificationPrompt: "Which page?"
        )

        let disclosure = VoiceTurnDisclosure.make(state: .completed, pendingDecision: decision)

        #expect(disclosure?.kind == .clarification)
        #expect(disclosure?.detail == "Nothing has run yet. Hive needs an active page before it can continue.")
    }

    @Test("active lifecycle states have stable copy")
    func lifecycleStates() {
        let cases: [(VoiceCommandState, VoiceTurnDisclosure.Kind, String)] = [
            (.listening, .listening, "Listening"),
            (.transcribing, .transcribing, "Transcribing"),
            (.classifying, .routing, "Routing"),
            (.executing, .executing, "Working"),
            (.speaking, .speaking, "Speaking")
        ]

        for (state, kind, title) in cases {
            let disclosure = VoiceTurnDisclosure.make(state: state, pendingDecision: nil)
            #expect(disclosure?.kind == kind)
            #expect(disclosure?.title == title)
            #expect(disclosure?.detail.isEmpty == false)
        }
    }

    @Test("terminal states explain safe outcomes")
    func terminalStates() {
        let unavailable = VoiceTurnDisclosure.make(state: .unsupported, pendingDecision: nil)
        let failed = VoiceTurnDisclosure.make(state: .failed, pendingDecision: nil)
        let cancelled = VoiceTurnDisclosure.make(state: .cancelled, pendingDecision: nil)

        #expect(unavailable?.kind == .unavailable)
        #expect(failed?.kind == .failed)
        #expect(cancelled?.kind == .cancelled)
        #expect(failed?.detail.contains("Nothing was changed") == true)
        #expect(cancelled?.detail.contains("No action was run") == true)
    }

    @Test("idle and completed states are quiet without a pending decision")
    func quietStates() {
        #expect(VoiceTurnDisclosure.make(state: .idle, pendingDecision: nil) == nil)
        #expect(VoiceTurnDisclosure.make(state: .completed, pendingDecision: nil) == nil)
    }
}
