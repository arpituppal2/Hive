import Foundation

/// The only response routes accepted by the shared advisory response executor.
/// Research and consequential actions retain their own lifecycles.
public enum SwarmResponseRoute: String, Sendable, Codable, CaseIterable {
    case genericQuestion
    case pageQuestion
}

/// Immutable input shared by Chromium text and voice advisory response paths.
/// It contains user-authored intent and explicit tab references only; page text
/// and durable context are assembled later by the browser context boundary.
public struct SwarmResponseRequest: Sendable, Equatable {
    public let route: SwarmResponseRoute
    public let role: ModelRole
    public let intent: String
    public let maxTokens: Int
    public let explicitTabIDs: Set<String>

    public init(
        route: SwarmResponseRoute,
        intent: String,
        maxTokens: Int,
        explicitTabIDs: Set<String> = []
    ) {
        self.route = route
        self.role = route == .pageQuestion ? .pageQa : .summarizer
        self.intent = intent
        self.maxTokens = maxTokens
        self.explicitTabIDs = explicitTabIDs
    }

    public static func text(
        intent: String,
        maxTokens: Int = 512,
        explicitTabIDs: Set<String> = []
    ) -> Self {
        Self(
            route: .genericQuestion,
            intent: intent,
            maxTokens: maxTokens,
            explicitTabIDs: explicitTabIDs
        )
    }

    public static func voice(
        route: SwarmResponseRoute,
        intent: String,
        explicitTabIDs: Set<String> = []
    ) -> Self {
        Self(
            route: route,
            intent: intent,
            maxTokens: 512,
            explicitTabIDs: explicitTabIDs
        )
    }
}
