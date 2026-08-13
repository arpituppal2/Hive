import Foundation

/// A privacy-safe presentation model for one voice turn.
///
/// The voice runtime already owns classification, scope, confirmation, and
/// cancellation. This value only explains that state to the user. It never
/// includes the transcript, classifier reason, page data, URLs, tab IDs, or
/// model output.
public struct VoiceTurnDisclosure: Sendable, Equatable {
    public enum Kind: String, Sendable, Codable, CaseIterable {
        case listening
        case transcribing
        case routing
        case clarification
        case confirmation
        case executing
        case speaking
        case unavailable
        case failed
        case cancelled
    }

    public let kind: Kind
    public let title: String
    public let detail: String
    public let instruction: String?
    public let iconName: String
    public let isBlocking: Bool

    public init(kind: Kind,
                title: String,
                detail: String,
                instruction: String? = nil,
                iconName: String,
                isBlocking: Bool = false) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.instruction = instruction
        self.iconName = iconName
        self.isBlocking = isBlocking
    }

    /// Builds fixed, user-facing copy from the coordinator's typed state.
    /// Pending decisions take precedence over transient state so a clarification
    /// or confirmation remains visible while its spoken prompt finishes.
    public static func make(
        state: VoiceCommandState,
        pendingDecision: VoiceRouteDecision?
    ) -> VoiceTurnDisclosure? {
        if let pendingDecision {
            if pendingDecision.requiresConfirmation {
                return confirmation()
            }
            if pendingDecision.needsClarification {
                return clarification(for: pendingDecision)
            }
        }

        switch state {
        case .listening:
            return .init(
                kind: .listening,
                title: "Listening",
                detail: "Speak your request. Hive will ask before it acts.",
                iconName: "waveform"
            )
        case .transcribing:
            return .init(
                kind: .transcribing,
                title: "Transcribing",
                detail: "Turning local audio into your request.",
                iconName: "waveform.and.mic"
            )
        case .classifying:
            return .init(
                kind: .routing,
                title: "Routing",
                detail: "Determining whether this is a question, research, or an action.",
                iconName: "arrow.triangle.branch"
            )
        case .clarifying:
            return clarification(for: nil)
        case .executing:
            return .init(
                kind: .executing,
                title: "Working",
                detail: "The approved request is being handled.",
                iconName: "gearshape.2"
            )
        case .speaking:
            return .init(
                kind: .speaking,
                title: "Speaking",
                detail: "Hive is reading the result aloud.",
                iconName: "waveform"
            )
        case .unsupported:
            return .init(
                kind: .unavailable,
                title: "Unavailable",
                detail: "This capability is not configured or safely available.",
                iconName: "exclamationmark.triangle",
                isBlocking: true
            )
        case .failed:
            return .init(
                kind: .failed,
                title: "Voice error",
                detail: "The request could not be completed. Nothing was changed.",
                iconName: "xmark.octagon",
                isBlocking: true
            )
        case .cancelled:
            return .init(
                kind: .cancelled,
                title: "Cancelled",
                detail: "The request stopped before completion. No action was run.",
                iconName: "xmark.circle",
                isBlocking: true
            )
        case .completed, .idle:
            return nil
        }
    }

    private static func clarification(for decision: VoiceRouteDecision?) -> VoiceTurnDisclosure {
        let fields = decision.map(missingFieldLabels(for:)) ?? []
        let requestDetail: String
        if fields.isEmpty {
            requestDetail = "Hive needs one more detail before it can continue."
        } else if fields.count == 1 {
            requestDetail = "Hive needs \(fields[0]) before it can continue."
        } else {
            requestDetail = "Hive needs \(join(fields)) before it can continue."
        }
        let detail = "Nothing has run yet. \(requestDetail)"

        return .init(
            kind: .clarification,
            title: "Clarification needed",
            detail: detail,
            instruction: "Answer the question to continue, or say “cancel” to stop.",
            iconName: "questionmark.circle",
            isBlocking: true
        )
    }

    private static func confirmation() -> VoiceTurnDisclosure {
        .init(
            kind: .confirmation,
            title: "Confirmation needed",
            detail: "Nothing has run yet. Hive is waiting for your approval.",
            instruction: "Say “confirm” to continue or “cancel” to stop.",
            iconName: "checkmark.shield",
            isBlocking: true
        )
    }

    private static func missingFieldLabels(for decision: VoiceRouteDecision) -> [String] {
        decision.missingFields.map { field in
            switch field.lowercased() {
            case "active page": return "an active page"
            case "action target": return "the action target"
            case "desired result": return "your desired result"
            case "research query": return "a research topic"
            case "target": return "the target"
            case "content": return "the content"
            case "destination": return "the destination"
            case "request": return "your request"
            default: return "more detail"
            }
        }
    }

    private static func join(_ fields: [String]) -> String {
        guard let last = fields.last else { return "more detail" }
        guard fields.count > 1 else { return last }
        return fields.dropLast().joined(separator: ", ") + ", and " + last
    }
}
