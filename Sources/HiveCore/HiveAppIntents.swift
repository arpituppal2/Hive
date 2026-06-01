import Foundation

#if canImport(AppIntents)
import AppIntents

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public enum HiveIntentSurface: String, AppEnum, CaseIterable, Sendable {
    case rawInputs
    case wiki
    case graph
    case chat

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Hive Surface")
    public static let caseDisplayRepresentations: [HiveIntentSurface: DisplayRepresentation] = [
        .rawInputs: "Field",
        .wiki: "The Colony",
        .graph: "The Hive",
        .chat: "Ask Hive"
    ]
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public protocol HiveRoutableIntent: AppIntent {
    static var hiveRoute: HiveIntentRoute { get }
}

public enum HiveIntentRoute: String, Codable, CaseIterable, Sendable {
    case requiresLogin
    case quickCapture
    case feedHive
    case importEvidence
    case askHive
    case openWiki
    case showGraph
    case consolidateArticles
    case captureCurrentPage
    case downloadAttachments
    case summarizeRecentInputs
    case runMemoryMaintenance
    case toggleMenuBar
}

public struct HiveIntentRequest: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var route: HiveIntentRoute
    public var text: String?
    public var query: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        route: HiveIntentRoute,
        text: String? = nil,
        query: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.route = route
        self.text = text
        self.query = query
        self.createdAt = createdAt
    }
}

public enum HiveIntentRequestStore {
    public static let didChangeNotification = Notification.Name("HiveIntentRequestStoreDidChange")
    private static let key = "hive.intent.pendingRequests"

    public static func enqueue(
        route: HiveIntentRoute,
        text: String? = nil,
        query: String? = nil,
        defaults: UserDefaults = .standard
    ) {
        var requests = pending(defaults: defaults)
        let requiresLogin = HiveAppleAccountPolicy.requiresSignInBeforeUse
            && HiveAccountStore.load(defaults: defaults) == nil
            && !HiveGuestAccessStore.isEnabled(defaults: defaults)
        requests.append(
            requiresLogin
            ? HiveIntentRequest(route: .requiresLogin)
            : HiveIntentRequest(route: route, text: text, query: query)
        )
        save(requests.suffix(20), defaults: defaults)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    public static func consumePending(defaults: UserDefaults = .standard) -> [HiveIntentRequest] {
        let requests = pending(defaults: defaults)
        defaults.removeObject(forKey: key)
        return requests.sorted { $0.createdAt < $1.createdAt }
    }

    private static func pending(defaults: UserDefaults) -> [HiveIntentRequest] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([HiveIntentRequest].self, from: data)) ?? []
    }

    private static func save<S: Sequence>(_ requests: S, defaults: UserDefaults) where S.Element == HiveIntentRequest {
        let array = Array(requests)
        guard let data = try? JSONEncoder().encode(array) else { return }
        defaults.set(data, forKey: key)
    }
}

public struct HiveAppShortcutDescriptor: Codable, Hashable, Sendable {
    public var route: HiveIntentRoute
    public var title: String
    public var phrases: [String]
    public var systemImageName: String
    public var fullDialogue: String
    public var supportingDialogue: String
    public var opensAppWhenRun: Bool
    public var importanceRank: Int

    public init(
        route: HiveIntentRoute,
        title: String,
        phrases: [String],
        systemImageName: String,
        fullDialogue: String,
        supportingDialogue: String,
        opensAppWhenRun: Bool,
        importanceRank: Int
    ) {
        self.route = route
        self.title = title
        self.phrases = phrases
        self.systemImageName = systemImageName
        self.fullDialogue = fullDialogue
        self.supportingDialogue = supportingDialogue
        self.opensAppWhenRun = opensAppWhenRun
        self.importanceRank = importanceRank
    }
}

public enum HiveAppShortcutCatalog {
    public static let maximumAppShortcuts = 10

    public static let shortcuts: [HiveAppShortcutDescriptor] = [
        HiveAppShortcutDescriptor(
            route: .feedHive,
            title: "Add to Field",
            phrases: ["Feed Hive", "Add to Hive Field", "Save this in Hive"],
            systemImageName: "camera.macro",
            fullDialogue: "Hive is open to Field so you can add a note, file, screenshot, or capture.",
            supportingDialogue: "Add to Field",
            opensAppWhenRun: true,
            importanceRank: 1
        ),
        HiveAppShortcutDescriptor(
            route: .askHive,
            title: "Ask Hive",
            phrases: ["Ask Hive", "Ask Hive about this", "Search my Hive"],
            systemImageName: "bubble.left.and.text.bubble.right",
            fullDialogue: "Ask from The Colony and local memory.",
            supportingDialogue: "Ask",
            opensAppWhenRun: true,
            importanceRank: 2
        ),
        HiveAppShortcutDescriptor(
            route: .captureCurrentPage,
            title: "Capture Current Page",
            phrases: ["Capture this page in Hive", "Save this page to Hive"],
            systemImageName: "camera.viewfinder",
            fullDialogue: "Hive will capture the current page into Field and keep private details hidden when locked.",
            supportingDialogue: "Capture page",
            opensAppWhenRun: true,
            importanceRank: 3
        ),
        HiveAppShortcutDescriptor(
            route: .openWiki,
            title: "Open The Colony",
            phrases: ["Open Hive Colony", "Read my Hive Colony"],
            systemImageName: "books.vertical",
            fullDialogue: "Hive is opening The Colony article layer.",
            supportingDialogue: "Open The Colony",
            opensAppWhenRun: true,
            importanceRank: 4
        ),
        HiveAppShortcutDescriptor(
            route: .showGraph,
            title: "Open The Hive",
            phrases: ["Open The Hive", "Show my Hive map"],
            systemImageName: "point.3.filled.connected.trianglepath.dotted",
            fullDialogue: "Hive is opening The Hive so you can inspect connected memories.",
            supportingDialogue: "Open The Hive",
            opensAppWhenRun: true,
            importanceRank: 5
        ),
        HiveAppShortcutDescriptor(
            route: .summarizeRecentInputs,
            title: "Summarize Field",
            phrases: ["Summarize Hive Field", "What did Hive learn recently"],
            systemImageName: "doc.text.magnifyingglass",
            fullDialogue: "Hive is showing the recent Field synthesis, with original evidence kept separate.",
            supportingDialogue: "Recent synthesis",
            opensAppWhenRun: true,
            importanceRank: 6
        ),
        HiveAppShortcutDescriptor(
            route: .runMemoryMaintenance,
            title: "Review Memory",
            phrases: ["Review Hive memory", "Run Hive maintenance"],
            systemImageName: "arrow.trianglehead.2.clockwise",
            fullDialogue: "Hive is starting a bounded local review of Field items, Colony articles, and The Hive connections.",
            supportingDialogue: "Review memory",
            opensAppWhenRun: true,
            importanceRank: 7
        ),
        HiveAppShortcutDescriptor(
            route: .consolidateArticles,
            title: "Consolidate Articles",
            phrases: ["Consolidate Hive articles", "Merge Hive articles"],
            systemImageName: "book",
            fullDialogue: "Hive is opening article consolidation so duplicates can merge into the best existing page.",
            supportingDialogue: "Consolidate",
            opensAppWhenRun: true,
            importanceRank: 8
        ),
        HiveAppShortcutDescriptor(
            route: .downloadAttachments,
            title: "Save Article Images",
            phrases: ["Save Hive article images", "Download Hive images"],
            systemImageName: "arrow.down.doc",
            fullDialogue: "Hive is saving images for the current article so The Colony remains useful offline.",
            supportingDialogue: "Save images",
            opensAppWhenRun: true,
            importanceRank: 9
        ),
        HiveAppShortcutDescriptor(
            route: .quickCapture,
            title: "Quick Capture",
            phrases: ["Quick capture in Hive", "Remember this in Hive"],
            systemImageName: "square.and.pencil",
            fullDialogue: "Capture a short thought into Field.",
            supportingDialogue: "Quick capture",
            opensAppWhenRun: true,
            importanceRank: 10
        )
    ]

    public static func descriptor(for route: HiveIntentRoute) -> HiveAppShortcutDescriptor? {
        shortcuts.first { $0.route == route }
    }

    public static var orderedShortcuts: [HiveAppShortcutDescriptor] {
        shortcuts.sorted { lhs, rhs in
            if lhs.importanceRank == rhs.importanceRank {
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
            return lhs.importanceRank < rhs.importanceRank
        }
    }

    public static var respectsSystemShortcutLimit: Bool {
        shortcuts.count <= maximumAppShortcuts
    }

    public static var routesAreUnique: Bool {
        Set(shortcuts.map(\.route)).count == shortcuts.count
    }

    public static var allPhrasesIncludeAppName: Bool {
        shortcuts.flatMap(\.phrases).allSatisfy { phrase in
            phrase.range(of: "Hive", options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    public static var allDialoguesSupportAudioOnlyUse: Bool {
        shortcuts.allSatisfy { descriptor in
            !descriptor.fullDialogue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !descriptor.supportingDialogue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && descriptor.fullDialogue.count >= descriptor.supportingDialogue.count
        }
    }

    public static var allSymbolsAreDeclaredInDesignSystem: Bool {
        let approved = Set([
            "tray.and.arrow.down",
            "camera.macro",
            "bubble.left.and.text.bubble.right",
            "camera.viewfinder",
            "books.vertical",
            "point.3.filled.connected.trianglepath.dotted",
            "doc.text.magnifyingglass",
            "arrow.trianglehead.2.clockwise",
            "book",
            "arrow.down.doc",
            "square.and.pencil"
        ])
        return shortcuts.allSatisfy { approved.contains($0.systemImageName) }
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct HiveQuickCaptureIntent: HiveRoutableIntent {
    public static let title: LocalizedStringResource = "Quick Capture in Hive"
    public static let description = IntentDescription("Capture a short thought into Hive Field.")
    public static let openAppWhenRun = true
    public static let hiveRoute: HiveIntentRoute = .quickCapture

    @Parameter(title: "Text")
    public var text: String

    public init() {}

    public func perform() async throws -> some IntentResult {
        HiveIntentRequestStore.enqueue(route: Self.hiveRoute, text: text)
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct HiveOpenSurfaceIntent: HiveRoutableIntent {
    public static let title: LocalizedStringResource = "Open Hive"
    public static let description = IntentDescription("Open a primary Hive surface.")
    public static let openAppWhenRun = true
    public static let hiveRoute: HiveIntentRoute = .showGraph

    @Parameter(title: "Surface")
    public var surface: HiveIntentSurface

    public init() {}

    public func perform() async throws -> some IntentResult {
        HiveIntentRequestStore.enqueue(route: .showGraph, query: surface.rawValue)
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct HiveImportEvidenceIntent: HiveRoutableIntent {
    public static let title: LocalizedStringResource = "Add to Field"
    public static let description = IntentDescription("Open Hive's Field picker.")
    public static let openAppWhenRun = true
    public static let hiveRoute: HiveIntentRoute = .importEvidence

    public init() {}

    public func perform() async throws -> some IntentResult {
        HiveIntentRequestStore.enqueue(route: Self.hiveRoute)
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct HiveFeedHiveIntent: HiveRoutableIntent {
    public static let title: LocalizedStringResource = "Feed Hive"
    public static let description = IntentDescription("Open Hive's Field intake.")
    public static let openAppWhenRun = true
    public static let hiveRoute: HiveIntentRoute = .feedHive

    public init() {}

    public func perform() async throws -> some IntentResult {
        HiveIntentRequestStore.enqueue(route: Self.hiveRoute)
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct HiveAskMemoryIntent: HiveRoutableIntent {
    public static let title: LocalizedStringResource = "Ask Hive"
    public static let description = IntentDescription("Ask Hive a question using local indexed memory.")
    public static let openAppWhenRun = true
    public static let hiveRoute: HiveIntentRoute = .askHive

    @Parameter(title: "Question")
    public var question: String

    public init() {}

    public func perform() async throws -> some IntentResult {
        HiveIntentRequestStore.enqueue(route: Self.hiveRoute, query: question)
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct HiveOpenWikiArticleIntent: HiveRoutableIntent {
    public static let title: LocalizedStringResource = "Open Colony Article"
    public static let description = IntentDescription("Open a Colony article by title.")
    public static let openAppWhenRun = true
    public static let hiveRoute: HiveIntentRoute = .openWiki

    @Parameter(title: "Article")
    public var titleQuery: String

    public init() {}

    public func perform() async throws -> some IntentResult {
        HiveIntentRequestStore.enqueue(route: Self.hiveRoute, query: titleQuery)
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct HiveShowGraphNodeIntent: HiveRoutableIntent {
    public static let title: LocalizedStringResource = "Show in The Hive"
    public static let description = IntentDescription("Show a memory in The Hive.")
    public static let openAppWhenRun = true
    public static let hiveRoute: HiveIntentRoute = .showGraph

    @Parameter(title: "Memory")
    public var memoryQuery: String

    public init() {}

    public func perform() async throws -> some IntentResult {
        HiveIntentRequestStore.enqueue(route: Self.hiveRoute, query: memoryQuery)
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct HiveConsolidateArticlesIntent: HiveRoutableIntent {
    public static let title: LocalizedStringResource = "Consolidate Hive Articles"
    public static let description = IntentDescription("Merge selected duplicate Colony articles into the best existing page.")
    public static let openAppWhenRun = true
    public static let hiveRoute: HiveIntentRoute = .consolidateArticles

    public init() {}

    public func perform() async throws -> some IntentResult {
        HiveIntentRequestStore.enqueue(route: Self.hiveRoute)
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct HiveCaptureCurrentPageIntent: HiveRoutableIntent {
    public static let title: LocalizedStringResource = "Capture Current Page in Hive"
    public static let description = IntentDescription("Capture the current page into Hive Field.")
    public static let openAppWhenRun = true
    public static let hiveRoute: HiveIntentRoute = .captureCurrentPage

    public init() {}

    public func perform() async throws -> some IntentResult {
        HiveIntentRequestStore.enqueue(route: Self.hiveRoute)
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct HiveDownloadAttachmentsIntent: HiveRoutableIntent {
    public static let title: LocalizedStringResource = "Download Hive Article Images"
    public static let description = IntentDescription("Save images referenced by the current Colony article for offline use.")
    public static let openAppWhenRun = true
    public static let hiveRoute: HiveIntentRoute = .downloadAttachments

    public init() {}

    public func perform() async throws -> some IntentResult {
        HiveIntentRequestStore.enqueue(route: Self.hiveRoute)
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct HiveSummarizeRecentInputsIntent: HiveRoutableIntent {
    public static let title: LocalizedStringResource = "Summarize Field"
    public static let description = IntentDescription("Open Hive's recent Field synthesis.")
    public static let openAppWhenRun = true
    public static let hiveRoute: HiveIntentRoute = .summarizeRecentInputs

    public init() {}

    public func perform() async throws -> some IntentResult {
        HiveIntentRequestStore.enqueue(route: Self.hiveRoute)
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct HiveRunMemoryMaintenanceIntent: HiveRoutableIntent {
    public static let title: LocalizedStringResource = "Run Hive Memory Maintenance"
    public static let description = IntentDescription("Run Hive's local memory maintenance pass.")
    public static let openAppWhenRun = true
    public static let hiveRoute: HiveIntentRoute = .runMemoryMaintenance

    public init() {}

    public func perform() async throws -> some IntentResult {
        HiveIntentRequestStore.enqueue(route: Self.hiveRoute)
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct HiveToggleMenuBarIntent: HiveRoutableIntent {
    public static let title: LocalizedStringResource = "Toggle Hive Menu Bar Icon"
    public static let description = IntentDescription("Show or hide Hive in the menu bar.")
    public static let openAppWhenRun = true
    public static let hiveRoute: HiveIntentRoute = .toggleMenuBar

    public init() {}

    public func perform() async throws -> some IntentResult {
        HiveIntentRequestStore.enqueue(route: Self.hiveRoute)
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct HiveShortcutsProvider: AppShortcutsProvider {
    public static let shortcutTileColor: ShortcutTileColor = .yellow

    @AppShortcutsBuilder
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: HiveFeedHiveIntent(),
            phrases: ["Add to \(.applicationName)", "Feed \(.applicationName)", "Add to Field in \(.applicationName)"],
            shortTitle: "Add",
            systemImageName: "camera.macro"
        )
        AppShortcut(
            intent: HiveAskMemoryIntent(),
            phrases: ["Ask \(.applicationName)", "Ask \(.applicationName) about this", "Search \(.applicationName)"],
            shortTitle: "Ask",
            systemImageName: "bubble.left.and.text.bubble.right"
        )
        AppShortcut(
            intent: HiveOpenWikiArticleIntent(),
            phrases: ["Open The Colony in \(.applicationName)", "Read \(.applicationName) Colony"],
            shortTitle: "Colony",
            systemImageName: "books.vertical"
        )
        AppShortcut(
            intent: HiveShowGraphNodeIntent(),
            phrases: ["Open The Hive in \(.applicationName)", "Show \(.applicationName) map"],
            shortTitle: "Hive",
            systemImageName: "point.3.filled.connected.trianglepath.dotted"
        )
        AppShortcut(
            intent: HiveRunMemoryMaintenanceIntent(),
            phrases: ["Review \(.applicationName) memory", "Run \(.applicationName) maintenance"],
            shortTitle: "Review",
            systemImageName: "arrow.trianglehead.2.clockwise"
        )
    }
}
#endif
