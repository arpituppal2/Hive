import Foundation

#if canImport(CoreML)
import CoreML
#endif

public enum HiveCapabilityTier: String, Codable, CaseIterable, Sendable {
    case appleIntelligenceFull
    case coreMLDistilled
    case voiceRelayOnly

    public var allowsSwarmGeneration: Bool {
        switch self {
        case .appleIntelligenceFull:
            return true
        case .coreMLDistilled, .voiceRelayOnly:
            return false
        }
    }

    public var swarmPlaceholder: String {
        switch self {
        case .appleIntelligenceFull:
            return "Ask Hive..."
        case .coreMLDistilled:
            return "Search your knowledge base (AI generation unavailable on this device)"
        case .voiceRelayOnly:
            return "Ask on iPhone..."
        }
    }
}

public final class CapabilityStore: ObservableObject, @unchecked Sendable {
    public static let shared = CapabilityStore()

    @Published public private(set) var tier: HiveCapabilityTier = .coreMLDistilled
    @Published public private(set) var isDetecting = true

    private init() {}

    @MainActor
    public func refresh() async {
        isDetecting = true
        tier = await CapabilityDetector.detect()
        isDetecting = false
    }
}

public enum CapabilityDetector {
    public static func detect() async -> HiveCapabilityTier {
        #if os(watchOS)
        return .voiceRelayOnly
        #else
        let foundationAvailability = HiveFoundationModelsOrchestrator.currentAvailability()
        if foundationAvailability == .available {
            return .appleIntelligenceFull
        }
        #if canImport(CoreML)
        if distilledModelIsAvailable {
            return .coreMLDistilled
        }
        #endif
        return .coreMLDistilled
        #endif
    }

    #if canImport(CoreML) && !os(watchOS)
    private static var distilledModelIsAvailable: Bool {
        // HiveCore does not bundle a compiled Core ML artifact in SPM yet.
        true
    }
    #endif
}
