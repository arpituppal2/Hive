import Foundation
import HiveCore

#if canImport(SwiftUI)
import SwiftUI
import HiveDesignSystem
#endif

#if os(watchOS) && canImport(WatchKit)
import WatchKit
#endif

public struct HiveWatchSnapshot: Hashable, Sendable {
    public static let maximumRecentClaims = 3

    public var memoryCount: Int
    public var stateText: String
    public var recentClaims: [String]
    public var redactsPrivateContentOnAlwaysOn: Bool
    public var deepLinkTarget: String
    public var updatedAt: Date

    public init(
        memoryCount: Int,
        stateText: String,
        recentClaims: [String],
        redactsPrivateContentOnAlwaysOn: Bool = true,
        deepLinkTarget: String = "hive://watch/recent",
        updatedAt: Date = Date()
    ) {
        self.memoryCount = max(0, memoryCount)
        self.stateText = SourcePresentationModel.cleanTitle(stateText)
        self.recentClaims = Array(
            recentClaims
                .map(SourcePresentationModel.cleanTitle)
                .filter(GraphChangeAnimationList.isUsefulAnimationTitle)
                .prefix(Self.maximumRecentClaims)
        )
        self.redactsPrivateContentOnAlwaysOn = redactsPrivateContentOnAlwaysOn
        self.deepLinkTarget = deepLinkTarget
        self.updatedAt = updatedAt
    }

    public static var placeholder: HiveWatchSnapshot {
        HiveWatchSnapshot(
            memoryCount: 0,
            stateText: "Add a source",
            recentClaims: []
        )
    }

    public var glanceLines: [String] {
        let usefulClaims = recentClaims.filter(GraphChangeAnimationList.isUsefulAnimationTitle)
        return usefulClaims.isEmpty ? [stateText] : usefulClaims
    }

    public var isGlanceable: Bool {
        memoryCount >= 0
            && glanceLines.count <= Self.maximumRecentClaims
            && !deepLinkTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && redactsPrivateContentOnAlwaysOn
    }
}

public enum HiveWatchCrownHapticMode: String, Codable, CaseIterable, Sendable {
    case linearDetents
    case rowDetents
    case off
}

public struct HiveWatchCrownInteractionPolicy: Codable, Hashable, Sendable {
    public var anchorsNavigationToDigitalCrown: Bool
    public var usesVerticalPagination: Bool
    public var usesVerticalLists: Bool
    public var backsUpCrownWithTouch: Bool
    public var crownPressesAreSystemReserved: Bool
    public var providesVisualFeedbackForEveryTurn: Bool
    public var hapticMode: HiveWatchCrownHapticMode
    public var maximumAnimationDuration: TimeInterval
    public var minimumAnimationDuration: TimeInterval

    public init(
        anchorsNavigationToDigitalCrown: Bool = true,
        usesVerticalPagination: Bool = true,
        usesVerticalLists: Bool = true,
        backsUpCrownWithTouch: Bool = true,
        crownPressesAreSystemReserved: Bool = true,
        providesVisualFeedbackForEveryTurn: Bool = true,
        hapticMode: HiveWatchCrownHapticMode = .linearDetents,
        maximumAnimationDuration: TimeInterval = 0.28,
        minimumAnimationDuration: TimeInterval = 0.08
    ) {
        self.anchorsNavigationToDigitalCrown = anchorsNavigationToDigitalCrown
        self.usesVerticalPagination = usesVerticalPagination
        self.usesVerticalLists = usesVerticalLists
        self.backsUpCrownWithTouch = backsUpCrownWithTouch
        self.crownPressesAreSystemReserved = crownPressesAreSystemReserved
        self.providesVisualFeedbackForEveryTurn = providesVisualFeedbackForEveryTurn
        self.hapticMode = hapticMode
        self.maximumAnimationDuration = maximumAnimationDuration
        self.minimumAnimationDuration = minimumAnimationDuration
    }

    public static let watchOS10Default = HiveWatchCrownInteractionPolicy()

    public var followsWatchOSNavigationGuidance: Bool {
        anchorsNavigationToDigitalCrown
            && usesVerticalPagination
            && usesVerticalLists
            && backsUpCrownWithTouch
            && crownPressesAreSystemReserved
            && providesVisualFeedbackForEveryTurn
            && hapticMode != .off
    }

    public func animationDuration(turnsPerSecond: Double) -> TimeInterval {
        let speed = max(0, min(6, turnsPerSecond))
        let normalized = speed / 6
        return maximumAnimationDuration - ((maximumAnimationDuration - minimumAnimationDuration) * normalized)
    }

    public func normalizedInspectionValue(rawValue: Double, itemCount: Int) -> Double {
        guard itemCount > 1 else { return 0 }
        let upperBound = Double(itemCount - 1)
        return min(upperBound, max(0, rawValue))
    }
}

public enum HiveWatchSurface: String, Codable, CaseIterable, Identifiable, Sendable {
    case flowerField
    case colony
    case hive
    case ask

    public var id: String { rawValue }
}

public struct HiveWatchScreenDescriptor: Codable, Hashable, Sendable {
    public var surface: HiveWatchSurface
    public var title: String
    public var symbolName: String
    public var shortDescription: String
    public var deepLinkTarget: String
    public var usesCrownForVerticalNavigation: Bool
    public var supportsTouchFallback: Bool
    public var maximumPrimaryActions: Int

    public init(
        surface: HiveWatchSurface,
        title: String,
        symbolName: String,
        shortDescription: String,
        deepLinkTarget: String,
        usesCrownForVerticalNavigation: Bool = true,
        supportsTouchFallback: Bool = true,
        maximumPrimaryActions: Int = 2
    ) {
        self.surface = surface
        self.title = title
        self.symbolName = symbolName
        self.shortDescription = shortDescription
        self.deepLinkTarget = deepLinkTarget
        self.usesCrownForVerticalNavigation = usesCrownForVerticalNavigation
        self.supportsTouchFallback = supportsTouchFallback
        self.maximumPrimaryActions = maximumPrimaryActions
    }

    public var isWatchSized: Bool {
        !title.isEmpty
            && shortDescription.count <= 72
            && maximumPrimaryActions <= 2
            && usesCrownForVerticalNavigation
            && supportsTouchFallback
    }
}

public enum HiveWatchNavigationCatalog {
    public static let screens: [HiveWatchScreenDescriptor] = [
        HiveWatchScreenDescriptor(
            surface: .flowerField,
            title: "Field",
            symbolName: "camera.macro",
            shortDescription: "Capture a thought, page, or voice note.",
            deepLinkTarget: "hive://watch/flower-field"
        ),
        HiveWatchScreenDescriptor(
            surface: .colony,
            title: "The Colony",
            symbolName: "books.vertical",
            shortDescription: "Read the latest useful memory.",
            deepLinkTarget: "hive://watch/colony"
        ),
        HiveWatchScreenDescriptor(
            surface: .hive,
            title: "The Hive",
            symbolName: "hexagon",
            shortDescription: "Inspect the current memory shape.",
            deepLinkTarget: "hive://watch/hive"
        ),
        HiveWatchScreenDescriptor(
            surface: .ask,
            title: "Ask Hive",
            symbolName: "bubble.left.and.text.bubble.right",
            shortDescription: "Ask from the local Wiki.",
            deepLinkTarget: "hive://watch/ask"
        )
    ]

    public static var followsWatchHierarchyGuidance: Bool {
        screens.count <= 4
            && screens.allSatisfy(\.isWatchSized)
            && Set(screens.map(\.surface)) == Set(HiveWatchSurface.allCases)
            && Set(screens.map(\.deepLinkTarget)).count == screens.count
    }
}

public struct HiveWatchAccountAccessPolicy: Codable, Hashable, Sendable {
    public var usesAppleAccountIdentity: Bool
    public var signInIsOptionalOnWatch: Bool
    public var usesSystemAuthorizationButton: Bool
    public var defersAccountSetupToCompanionWhenNeeded: Bool

    public init(
        usesAppleAccountIdentity: Bool = true,
        signInIsOptionalOnWatch: Bool = false,
        usesSystemAuthorizationButton: Bool = true,
        defersAccountSetupToCompanionWhenNeeded: Bool = true
    ) {
        self.usesAppleAccountIdentity = usesAppleAccountIdentity
        self.signInIsOptionalOnWatch = signInIsOptionalOnWatch
        self.usesSystemAuthorizationButton = usesSystemAuthorizationButton
        self.defersAccountSetupToCompanionWhenNeeded = defersAccountSetupToCompanionWhenNeeded
    }

    public static let defaultPolicy = HiveWatchAccountAccessPolicy()

    public var followsSignInGuidance: Bool {
        usesAppleAccountIdentity
            && !signInIsOptionalOnWatch
            && usesSystemAuthorizationButton
            && defersAccountSetupToCompanionWhenNeeded
            && HiveAppleAccountPolicy.followsSignInWithAppleGuidance
    }
}

public struct HiveWatchCloudContinuityPolicy: Codable, Hashable, Sendable {
    public var readsICloudHiveState: Bool
    public var keepsWatchInteractionsGlanceable: Bool
    public var avoidsRawFileManagementOnWatch: Bool
    public var defersLargeDownloadsToCompanion: Bool

    public init(
        readsICloudHiveState: Bool = true,
        keepsWatchInteractionsGlanceable: Bool = true,
        avoidsRawFileManagementOnWatch: Bool = true,
        defersLargeDownloadsToCompanion: Bool = true
    ) {
        self.readsICloudHiveState = readsICloudHiveState
        self.keepsWatchInteractionsGlanceable = keepsWatchInteractionsGlanceable
        self.avoidsRawFileManagementOnWatch = avoidsRawFileManagementOnWatch
        self.defersLargeDownloadsToCompanion = defersLargeDownloadsToCompanion
    }

    public static let defaultPolicy = HiveWatchCloudContinuityPolicy()

    public var followsICloudGuidance: Bool {
        readsICloudHiveState
            && keepsWatchInteractionsGlanceable
            && avoidsRawFileManagementOnWatch
            && defersLargeDownloadsToCompanion
            && HiveCloudSyncPolicy.default.followsICloudGuidance
    }
}

public enum HiveWatchQuickAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case voiceNote
    case quickThought
    case askHive
    case openRecent

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .voiceNote: return "Voice Note"
        case .quickThought: return "Quick Thought"
        case .askHive: return "Ask Hive"
        case .openRecent: return "Recent Memory"
        }
    }

    public var symbolName: String {
        switch self {
        case .voiceNote: return "mic"
        case .quickThought: return "square.and.pencil"
        case .askHive: return "bubble.left.and.text.bubble.right"
        case .openRecent: return "clock"
        }
    }
}

public enum HiveWatchQuickActionCatalog {
    public static let glanceableActions: [HiveWatchQuickAction] = [
        .voiceNote,
        .quickThought,
        .askHive,
        .openRecent
    ]

    public static let usesSystemDictationForTextFields = true
    public static let customSpeechRecognitionRunsOnCompanion = true
    public static let avoidsLocalSpeechRecognizerDependency = true

    public static var supportsVoiceCapture: Bool {
        glanceableActions.contains(.voiceNote)
    }

    public static var keepsActionsShort: Bool {
        glanceableActions.allSatisfy { $0.title.count <= 18 }
    }

    public static var followsWatchDictationGuidance: Bool {
        supportsVoiceCapture
            && usesSystemDictationForTextFields
            && customSpeechRecognitionRunsOnCompanion
            && avoidsLocalSpeechRecognizerDependency
            && keepsActionsShort
    }
}

public enum HiveWatchComplicationFamily: String, CaseIterable, Sendable {
    case circular
    case inline
    case rectangular
    case corner
}

public struct HiveWatchComplicationDescriptor: Hashable, Sendable {
    public var family: HiveWatchComplicationFamily
    public var title: String
    public var systemImageName: String
    public var placeholderText: String
    public var deepLinkTarget: String
    public var hidesPrivateContentOnAlwaysOn: Bool
    public var supportsTintedRendering: Bool
    public var timelineRefreshWindowMinutes: Int
    public var usesAppIconPlaceholderWhenEmpty: Bool

    public init(
        family: HiveWatchComplicationFamily,
        title: String,
        systemImageName: String,
        placeholderText: String,
        deepLinkTarget: String,
        hidesPrivateContentOnAlwaysOn: Bool = true,
        supportsTintedRendering: Bool = true,
        timelineRefreshWindowMinutes: Int = HiveWatchComplicationTimelinePolicy.maximumRefreshWindowMinutes,
        usesAppIconPlaceholderWhenEmpty: Bool = true
    ) {
        self.family = family
        self.title = title
        self.systemImageName = systemImageName
        self.placeholderText = placeholderText
        self.deepLinkTarget = deepLinkTarget
        self.hidesPrivateContentOnAlwaysOn = hidesPrivateContentOnAlwaysOn
        self.supportsTintedRendering = supportsTintedRendering
        self.timelineRefreshWindowMinutes = timelineRefreshWindowMinutes
        self.usesAppIconPlaceholderWhenEmpty = usesAppIconPlaceholderWhenEmpty
    }
}

public enum HiveWatchComplicationTimelinePolicy {
    public static let maximumRefreshWindowMinutes = 5
    public static let staleGraceWindowMinutes = 30

    public static func nextRefresh(after date: Date) -> Date {
        date.addingTimeInterval(TimeInterval(maximumRefreshWindowMinutes * 60))
    }

    public static func isFresh(_ entry: HiveWatchComplicationTimelineEntry, now: Date = Date()) -> Bool {
        now.timeIntervalSince(entry.date) <= TimeInterval(staleGraceWindowMinutes * 60)
    }
}

public struct HiveWatchComplicationTimelineEntry: Hashable, Sendable {
    public var date: Date
    public var family: HiveWatchComplicationFamily
    public var snapshot: HiveWatchSnapshot
    public var privacyRedacted: Bool

    public init(
        date: Date = Date(),
        family: HiveWatchComplicationFamily,
        snapshot: HiveWatchSnapshot,
        privacyRedacted: Bool = true
    ) {
        self.date = date
        self.family = family
        self.snapshot = snapshot
        self.privacyRedacted = privacyRedacted
    }

    public var refreshAfter: Date {
        HiveWatchComplicationTimelinePolicy.nextRefresh(after: date)
    }
}

public enum HiveWatchComplicationCatalog {
    public static let descriptors: [HiveWatchComplicationDescriptor] = HiveWatchComplicationFamily.allCases.map { family in
        HiveWatchComplicationDescriptor(
            family: family,
            title: "Hive",
            systemImageName: family == .inline ? "hexagon" : "hexagon.fill",
            placeholderText: "Add a source",
            deepLinkTarget: "hive://watch/\(family.rawValue)"
        )
    }

    public static var supportsAllCoreFamilies: Bool {
        Set(descriptors.map(\.family)) == Set(HiveWatchComplicationFamily.allCases)
    }

    public static var deepLinksAreDistinct: Bool {
        Set(descriptors.map(\.deepLinkTarget)).count == descriptors.count
    }

    public static var alwaysOnSafe: Bool {
        descriptors.allSatisfy { descriptor in
            descriptor.hidesPrivateContentOnAlwaysOn
                && descriptor.supportsTintedRendering
                && descriptor.timelineRefreshWindowMinutes > 0
                && descriptor.timelineRefreshWindowMinutes <= HiveWatchComplicationTimelinePolicy.maximumRefreshWindowMinutes
                && descriptor.usesAppIconPlaceholderWhenEmpty
                && !descriptor.placeholderText.isEmpty
        }
    }
}

public struct HiveWatchPackagingManifest: Codable, Hashable, Sendable {
    public var appBundleIdentifier: String
    public var extensionBundleIdentifier: String
    public var companionBundleIdentifier: String
    public var minimumWatchOSVersion: String
    public var supportsIndependentOperation: Bool
    public var supportsComplications: Bool
    public var supportsNotifications: Bool
    public var supportsVoiceCapture: Bool
    public var localAIAvailableOnWatch: Bool

    public init(
        appBundleIdentifier: String = "local.hive.watch",
        extensionBundleIdentifier: String = "local.hive.watch.extension",
        companionBundleIdentifier: String = "local.hive.mobile",
        minimumWatchOSVersion: String = "10.0",
        supportsIndependentOperation: Bool = true,
        supportsComplications: Bool = true,
        supportsNotifications: Bool = true,
        supportsVoiceCapture: Bool = true,
        localAIAvailableOnWatch: Bool = false
    ) {
        self.appBundleIdentifier = appBundleIdentifier
        self.extensionBundleIdentifier = extensionBundleIdentifier
        self.companionBundleIdentifier = companionBundleIdentifier
        self.minimumWatchOSVersion = minimumWatchOSVersion
        self.supportsIndependentOperation = supportsIndependentOperation
        self.supportsComplications = supportsComplications
        self.supportsNotifications = supportsNotifications
        self.supportsVoiceCapture = supportsVoiceCapture
        self.localAIAvailableOnWatch = localAIAvailableOnWatch
    }

    public static let current = HiveWatchPackagingManifest()

    public var isReadyForWatchPackaging: Bool {
        minimumWatchOSVersion == "10.0"
            && supportsIndependentOperation
            && supportsComplications
            && supportsNotifications
            && supportsVoiceCapture
            && !localAIAvailableOnWatch
            && appBundleIdentifier.hasPrefix("local.hive")
            && extensionBundleIdentifier.hasPrefix(appBundleIdentifier)
    }
}

public struct HiveVoiceFeedIntent: Hashable, Sendable {
    public var transcript: String
    public var capturedAt: Date

    public init(transcript: String, capturedAt: Date = Date()) {
        self.transcript = transcript
        self.capturedAt = capturedAt
    }

    public var isUsable: Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#if os(watchOS) && canImport(SwiftUI)
@available(watchOS 10.0, *)
public struct HiveWatchRootView: View {
    public var snapshot: HiveWatchSnapshot
    @State private var selectedSurface: HiveWatchSurface = .flowerField
    @State private var inspectedIndex: Double = 0

    public init(snapshot: HiveWatchSnapshot = .placeholder) {
        self.snapshot = snapshot
    }

    public var body: some View {
        TabView(selection: $selectedSurface) {
            HiveWatchCapturePage(snapshot: snapshot)
                .tag(HiveWatchSurface.flowerField)
            HiveWatchListPage(snapshot: snapshot)
                .tag(HiveWatchSurface.colony)
            HiveWatchInspectionPage(snapshot: snapshot, inspectedIndex: $inspectedIndex)
                .tag(HiveWatchSurface.hive)
            HiveWatchAskPage()
                .tag(HiveWatchSurface.ask)
        }
        .tabViewStyle(.verticalPage)
        .animation(.snappy(duration: 0.22), value: selectedSurface)
    }
}

@available(watchOS 10.0, *)
private struct HiveWatchCapturePage: View {
    var snapshot: HiveWatchSnapshot
    @State private var dictatedNote = ""

    var body: some View {
        List {
            Label {
                Text("Field")
            } icon: {
                HiveSymbol(.rawInputs, size: 17, active: true)
            }
            Text(snapshot.stateText)
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField("Dictate a note", text: $dictatedNote)
                .submitLabel(.send)
                .onSubmit(saveNote)
            Button {
                saveNote()
            } label: {
                Label {
                    Text("Save Note")
                } icon: {
                    HiveSymbol(.voiceNote, size: 15, active: true)
                }
            }
            .disabled(dictatedNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button {
                #if canImport(AppIntents)
                HiveIntentRequestStore.enqueue(route: .feedHive)
                #endif
            } label: {
                Label {
                    Text("Add Later")
                } icon: {
                    HiveSymbol(.quickCapture, size: 15, active: true)
                }
            }
        }
    }

    private func saveNote() {
        let note = dictatedNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return }
        #if canImport(AppIntents)
        HiveIntentRequestStore.enqueue(route: .quickCapture, text: note)
        #endif
        dictatedNote = ""
    }
}

@available(watchOS 10.0, *)
private struct HiveWatchListPage: View {
    var snapshot: HiveWatchSnapshot

    var body: some View {
        List {
            Label {
                Text("The Colony")
            } icon: {
                HiveSymbol(.wiki, size: 17, active: true)
            }
            ForEach(snapshot.glanceLines, id: \.self) { line in
                Text(line)
                    .font(.footnote)
                    .lineLimit(3)
            }
        }
    }
}

@available(watchOS 10.0, *)
private struct HiveWatchInspectionPage: View {
    var snapshot: HiveWatchSnapshot
    @Binding var inspectedIndex: Double

    var body: some View {
        VStack(spacing: 10) {
            HiveSymbol(.hiveGraph, size: 24, active: true)
            Text(currentLine)
                .font(.headline)
                .multilineTextAlignment(.center)
                .contentTransition(.numericText())
            Text("\(snapshot.memoryCount) memories")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable(true)
        .digitalCrownRotation(
            $inspectedIndex,
            from: 0,
            through: Double(max(0, snapshot.glanceLines.count - 1)),
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .animation(.smooth(duration: 0.18), value: inspectedIndex)
        .onChange(of: inspectedIndex) { _, _ in
            #if canImport(WatchKit)
            WKInterfaceDevice.current().play(.click)
            #endif
        }
    }

    private var currentLine: String {
        let lines = snapshot.glanceLines
        guard !lines.isEmpty else { return "Add a source" }
        let index = Int(round(inspectedIndex)).clamped(to: 0...(lines.count - 1))
        return lines[index]
    }
}

@available(watchOS 10.0, *)
private struct HiveWatchAskPage: View {
    @ObservedObject private var connectivity = HiveWatchConnectivityHandler.shared
    @State private var question = ""
    @State private var isSending = false

    var body: some View {
        List {
            Label {
                Text("Ask Hive")
            } icon: {
                HiveSymbol(.chat, size: 17, active: true)
            }
            if let response = connectivity.lastResponse {
                ScrollView {
                    Text(response)
                        .font(.footnote)
                        .lineLimit(8)
                }
                Button("More on iPhone") {
                    #if canImport(WatchKit)
                    if let url = URL(string: "hive://swarm?query=\(question.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                        WKExtension.shared().openSystemURL(url)
                    }
                    #endif
                }
            }
            TextField("Ask from your memory", text: $question)
                .submitLabel(.send)
                .onSubmit(sendQuestion)
            Button {
                sendQuestion()
            } label: {
                Label {
                    Text(isSending ? "Sending..." : "Ask")
                } icon: {
                    HiveSymbol(.send, size: 15, active: !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
    }

    private func sendQuestion() {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSending = true
        connectivity.sendQueryFromWatch(trimmed)
        #if canImport(AppIntents)
        HiveIntentRequestStore.enqueue(route: .askHive, query: trimmed)
        #endif
        question = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isSending = false
        }
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
#endif
