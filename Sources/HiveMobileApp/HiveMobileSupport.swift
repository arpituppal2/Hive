import Foundation
import HiveCore
import HiveDesignSystem
#if canImport(SwiftUI)
import SwiftUI
#endif
#if os(iOS) && canImport(CoreMotion)
import CoreMotion
#endif
#if os(iOS) && canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#if os(iOS) && canImport(UIKit)
import UIKit
#endif
#if os(iOS) && canImport(PencilKit)
import PencilKit
#endif

public struct HiveMobileNavigationState: Hashable, Sendable {
    public var selectedSurface: String
    public var shareExtensionPendingCount: Int

    public init(selectedSurface: String = "Field", shareExtensionPendingCount: Int = 0) {
        self.selectedSurface = selectedSurface
        self.shareExtensionPendingCount = shareExtensionPendingCount
    }
}

public enum HiveHapticTrigger: String, CaseIterable, Sendable {
    case newNodeFormation
    case waxSealPromotion
    case contradictionDetected
    case claimConfirmed
    case forgetCompleted
}

public struct HiveShareCapturePayload: Hashable, Sendable {
    public var title: String
    public var text: String
    public var receivedAt: Date

    public init(title: String, text: String, receivedAt: Date = Date()) {
        self.title = SourcePresentationModel.cleanTitle(title)
        self.text = text
        self.receivedAt = receivedAt
    }
}

public enum HiveIPadInputMode: String, CaseIterable, Sendable {
    case multiTouch
    case virtualKeyboard
    case hardwareKeyboard
    case pointer
    case applePencil
    case voice
    case dragAndDrop
}

public enum HiveIPadLayoutMode: String, CaseIterable, Sendable {
    case compactOneColumn
    case regularTwoColumn
    case expandedThreeColumn
    case externalDisplay
}

public enum HiveIPhoneInputMode: String, CaseIterable, Sendable {
    case multiTouch
    case virtualKeyboard
    case voiceControl
    case shareSheet
    case quickActions
    case widgets
    case spotlight
    case shortcuts
    case motionSensors
    case biometricPrivacy
}

public enum HiveIPhoneLayoutMode: String, CaseIterable, Sendable {
    case oneHandPortrait
    case twoHandLandscape
    case dynamicTypeExpanded
    case backgroundRefresh
}

public struct HiveIPadDesignPolicy: Hashable, Sendable {
    public var usesNavigationSplitViewOnRegularWidth: Bool
    public var minimizesModalTransitions: Bool
    public var keepsControlsReachableButOutOfContent: Bool
    public var supportsMultitaskingAndStageManager: Bool
    public var supportsAllOrientations: Bool
    public var supportsDynamicType: Bool
    public var supportsDarkMode: Bool
    public var supportsWidgets: Bool
    public var transitionsToMacOS: Bool
    public var supportedInputModes: Set<HiveIPadInputMode>

    public init(
        usesNavigationSplitViewOnRegularWidth: Bool = true,
        minimizesModalTransitions: Bool = true,
        keepsControlsReachableButOutOfContent: Bool = true,
        supportsMultitaskingAndStageManager: Bool = true,
        supportsAllOrientations: Bool = true,
        supportsDynamicType: Bool = true,
        supportsDarkMode: Bool = true,
        supportsWidgets: Bool = true,
        transitionsToMacOS: Bool = true,
        supportedInputModes: Set<HiveIPadInputMode> = Set(HiveIPadInputMode.allCases)
    ) {
        self.usesNavigationSplitViewOnRegularWidth = usesNavigationSplitViewOnRegularWidth
        self.minimizesModalTransitions = minimizesModalTransitions
        self.keepsControlsReachableButOutOfContent = keepsControlsReachableButOutOfContent
        self.supportsMultitaskingAndStageManager = supportsMultitaskingAndStageManager
        self.supportsAllOrientations = supportsAllOrientations
        self.supportsDynamicType = supportsDynamicType
        self.supportsDarkMode = supportsDarkMode
        self.supportsWidgets = supportsWidgets
        self.transitionsToMacOS = transitionsToMacOS
        self.supportedInputModes = supportedInputModes
    }

    public static let defaultPolicy = HiveIPadDesignPolicy()

    public var followsIPadGuidance: Bool {
        usesNavigationSplitViewOnRegularWidth
            && minimizesModalTransitions
            && keepsControlsReachableButOutOfContent
            && supportsMultitaskingAndStageManager
            && supportsAllOrientations
            && supportsDynamicType
            && supportsDarkMode
            && supportsWidgets
            && transitionsToMacOS
            && supportedInputModes.isSuperset(of: Set(HiveIPadInputMode.allCases))
            && HiveDesignDocumentPolicy.followsCoreDesignRules
    }
}

public struct HiveIPadPackagingManifest: Hashable, Sendable {
    public var bundleIdentifier: String
    public var displayName: String
    public var supportedDeviceFamilies: Set<String>
    public var supportedInterfaceOrientations: Set<String>
    public var requiresFullScreen: Bool
    public var supportsMultipleWindows: Bool
    public var supportsStageManager: Bool
    public var supportsExternalDisplay: Bool
    public var supportsDocumentsInPlace: Bool
    public var supportsShareExtension: Bool
    public var supportsWidgets: Bool
    public var supportsApplePencil: Bool
    public var supportsExternalKeyboardAndPointer: Bool
    public var appGroupIdentifier: String

    public init(
        bundleIdentifier: String = "local.hive.mobile",
        displayName: String = "Hive",
        supportedDeviceFamilies: Set<String> = ["iPhone", "iPad"],
        supportedInterfaceOrientations: Set<String> = ["portrait", "portraitUpsideDown", "landscapeLeft", "landscapeRight"],
        requiresFullScreen: Bool = false,
        supportsMultipleWindows: Bool = true,
        supportsStageManager: Bool = true,
        supportsExternalDisplay: Bool = true,
        supportsDocumentsInPlace: Bool = true,
        supportsShareExtension: Bool = true,
        supportsWidgets: Bool = true,
        supportsApplePencil: Bool = true,
        supportsExternalKeyboardAndPointer: Bool = true,
        appGroupIdentifier: String = "group.local.hive"
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.supportedDeviceFamilies = supportedDeviceFamilies
        self.supportedInterfaceOrientations = supportedInterfaceOrientations
        self.requiresFullScreen = requiresFullScreen
        self.supportsMultipleWindows = supportsMultipleWindows
        self.supportsStageManager = supportsStageManager
        self.supportsExternalDisplay = supportsExternalDisplay
        self.supportsDocumentsInPlace = supportsDocumentsInPlace
        self.supportsShareExtension = supportsShareExtension
        self.supportsWidgets = supportsWidgets
        self.supportsApplePencil = supportsApplePencil
        self.supportsExternalKeyboardAndPointer = supportsExternalKeyboardAndPointer
        self.appGroupIdentifier = appGroupIdentifier
    }

    public static let current = HiveIPadPackagingManifest()

    public var isReadyForIPadPackaging: Bool {
        bundleIdentifier == "local.hive.mobile"
            && displayName == "Hive"
            && supportedDeviceFamilies.contains("iPad")
            && !requiresFullScreen
            && supportsMultipleWindows
            && supportsStageManager
            && supportsExternalDisplay
            && supportsDocumentsInPlace
            && supportsShareExtension
            && supportsWidgets
            && supportsApplePencil
            && supportsExternalKeyboardAndPointer
            && supportedInterfaceOrientations.isSuperset(of: ["portrait", "portraitUpsideDown", "landscapeLeft", "landscapeRight"])
            && appGroupIdentifier.hasPrefix("group.")
    }
}

public struct HiveIPhoneDesignPolicy: Hashable, Sendable {
    public var prioritizesPrimaryTaskContent: Bool
    public var limitsOnscreenControls: Bool
    public var keepsPrimaryActionsInMiddleOrBottomReachZone: Bool
    public var supportsSwipeBackAndRowActions: Bool
    public var supportsPortraitAndLandscape: Bool
    public var supportsDynamicType: Bool
    public var supportsDarkMode: Bool
    public var supportsWidgets: Bool
    public var supportsHomeScreenQuickActions: Bool
    public var supportsSpotlight: Bool
    public var supportsShortcuts: Bool
    public var supportsActivityViews: Bool
    public var requestsPersonalDataContextually: Bool
    public var supportsMotionSensorsWithPermission: Bool
    public var supportsVoiceControl: Bool
    public var supportedInputModes: Set<HiveIPhoneInputMode>

    public init(
        prioritizesPrimaryTaskContent: Bool = true,
        limitsOnscreenControls: Bool = true,
        keepsPrimaryActionsInMiddleOrBottomReachZone: Bool = true,
        supportsSwipeBackAndRowActions: Bool = true,
        supportsPortraitAndLandscape: Bool = true,
        supportsDynamicType: Bool = true,
        supportsDarkMode: Bool = true,
        supportsWidgets: Bool = true,
        supportsHomeScreenQuickActions: Bool = true,
        supportsSpotlight: Bool = true,
        supportsShortcuts: Bool = true,
        supportsActivityViews: Bool = true,
        requestsPersonalDataContextually: Bool = true,
        supportsMotionSensorsWithPermission: Bool = true,
        supportsVoiceControl: Bool = true,
        supportedInputModes: Set<HiveIPhoneInputMode> = Set(HiveIPhoneInputMode.allCases)
    ) {
        self.prioritizesPrimaryTaskContent = prioritizesPrimaryTaskContent
        self.limitsOnscreenControls = limitsOnscreenControls
        self.keepsPrimaryActionsInMiddleOrBottomReachZone = keepsPrimaryActionsInMiddleOrBottomReachZone
        self.supportsSwipeBackAndRowActions = supportsSwipeBackAndRowActions
        self.supportsPortraitAndLandscape = supportsPortraitAndLandscape
        self.supportsDynamicType = supportsDynamicType
        self.supportsDarkMode = supportsDarkMode
        self.supportsWidgets = supportsWidgets
        self.supportsHomeScreenQuickActions = supportsHomeScreenQuickActions
        self.supportsSpotlight = supportsSpotlight
        self.supportsShortcuts = supportsShortcuts
        self.supportsActivityViews = supportsActivityViews
        self.requestsPersonalDataContextually = requestsPersonalDataContextually
        self.supportsMotionSensorsWithPermission = supportsMotionSensorsWithPermission
        self.supportsVoiceControl = supportsVoiceControl
        self.supportedInputModes = supportedInputModes
    }

    public static let defaultPolicy = HiveIPhoneDesignPolicy()

    public var followsIPhoneGuidance: Bool {
        prioritizesPrimaryTaskContent
            && limitsOnscreenControls
            && keepsPrimaryActionsInMiddleOrBottomReachZone
            && supportsSwipeBackAndRowActions
            && supportsPortraitAndLandscape
            && supportsDynamicType
            && supportsDarkMode
            && supportsWidgets
            && supportsHomeScreenQuickActions
            && supportsSpotlight
            && supportsShortcuts
            && supportsActivityViews
            && requestsPersonalDataContextually
            && supportsMotionSensorsWithPermission
            && supportsVoiceControl
            && supportedInputModes.isSuperset(of: Set(HiveIPhoneInputMode.allCases))
            && HiveDesignDocumentPolicy.followsCoreDesignRules
    }
}

public struct HiveIPhonePackagingManifest: Hashable, Sendable {
    public var bundleIdentifier: String
    public var displayName: String
    public var supportedDeviceFamilies: Set<String>
    public var supportedInterfaceOrientations: Set<String>
    public var requiresFullScreen: Bool
    public var supportsWidgets: Bool
    public var supportsHomeScreenQuickActions: Bool
    public var supportsSpotlight: Bool
    public var supportsShortcuts: Bool
    public var supportsActivityViews: Bool
    public var supportsShareExtension: Bool
    public var supportsVoiceInput: Bool
    public var supportsMotionUsageDescription: Bool
    public var appGroupIdentifier: String

    public init(
        bundleIdentifier: String = "local.hive.mobile",
        displayName: String = "Hive",
        supportedDeviceFamilies: Set<String> = ["iPhone", "iPad"],
        supportedInterfaceOrientations: Set<String> = ["portrait", "landscapeLeft", "landscapeRight"],
        requiresFullScreen: Bool = false,
        supportsWidgets: Bool = true,
        supportsHomeScreenQuickActions: Bool = true,
        supportsSpotlight: Bool = true,
        supportsShortcuts: Bool = true,
        supportsActivityViews: Bool = true,
        supportsShareExtension: Bool = true,
        supportsVoiceInput: Bool = true,
        supportsMotionUsageDescription: Bool = true,
        appGroupIdentifier: String = "group.local.hive"
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.supportedDeviceFamilies = supportedDeviceFamilies
        self.supportedInterfaceOrientations = supportedInterfaceOrientations
        self.requiresFullScreen = requiresFullScreen
        self.supportsWidgets = supportsWidgets
        self.supportsHomeScreenQuickActions = supportsHomeScreenQuickActions
        self.supportsSpotlight = supportsSpotlight
        self.supportsShortcuts = supportsShortcuts
        self.supportsActivityViews = supportsActivityViews
        self.supportsShareExtension = supportsShareExtension
        self.supportsVoiceInput = supportsVoiceInput
        self.supportsMotionUsageDescription = supportsMotionUsageDescription
        self.appGroupIdentifier = appGroupIdentifier
    }

    public static let current = HiveIPhonePackagingManifest()

    public var isReadyForIPhonePackaging: Bool {
        bundleIdentifier == "local.hive.mobile"
            && displayName == "Hive"
            && supportedDeviceFamilies.contains("iPhone")
            && !requiresFullScreen
            && supportsWidgets
            && supportsHomeScreenQuickActions
            && supportsSpotlight
            && supportsShortcuts
            && supportsActivityViews
            && supportsShareExtension
            && supportsVoiceInput
            && supportsMotionUsageDescription
            && supportedInterfaceOrientations.isSuperset(of: ["portrait", "landscapeLeft", "landscapeRight"])
            && appGroupIdentifier.hasPrefix("group.")
    }
}

public struct HiveMobileAccountAccessPolicy: Hashable, Sendable {
    public var usesAppleAccountIdentity: Bool
    public var signInIsOptional: Bool
    public var usesSystemAuthorizationButton: Bool
    public var supportsPrivateRelayEmail: Bool

    public init(
        usesAppleAccountIdentity: Bool = true,
        signInIsOptional: Bool = false,
        usesSystemAuthorizationButton: Bool = true,
        supportsPrivateRelayEmail: Bool = true
    ) {
        self.usesAppleAccountIdentity = usesAppleAccountIdentity
        self.signInIsOptional = signInIsOptional
        self.usesSystemAuthorizationButton = usesSystemAuthorizationButton
        self.supportsPrivateRelayEmail = supportsPrivateRelayEmail
    }

    public static let defaultPolicy = HiveMobileAccountAccessPolicy()

    public var followsSignInGuidance: Bool {
        usesAppleAccountIdentity
            && !signInIsOptional
            && usesSystemAuthorizationButton
            && supportsPrivateRelayEmail
            && HiveAppleAccountPolicy.followsSignInWithAppleGuidance
    }
}

#if os(iOS) && canImport(SwiftUI) && canImport(UniformTypeIdentifiers)
@available(iOS 17.0, *)
public enum HiveIPadSurface: String, CaseIterable, Identifiable, Sendable {
    case field = "Field"
    case colony = "Colony"
    case hive = "Hive"
    case swarm = "Swarm"

    public var id: String { rawValue }

    public var symbol: HiveSymbolName {
        switch self {
        case .field:
            return .rawInputs
        case .colony:
            return .wiki
        case .hive:
            return .hiveGraph
        case .swarm:
            return .chat
        }
    }
}

@available(iOS 17.0, *)
public struct HiveIPadRootView: View {
    @State private var navigationState: HiveMobileNavigationState
    @State private var selectedSurface: HiveIPadSurface
    @State private var columnVisibility: NavigationSplitViewVisibility
    @State private var searchText: String
    @State private var pendingCaptures: [HiveShareCapturePayload]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(navigationState: HiveMobileNavigationState = HiveMobileNavigationState()) {
        _navigationState = State(initialValue: navigationState)
        _selectedSurface = State(initialValue: HiveIPadSurface(rawValue: navigationState.selectedSurface) ?? .field)
        _columnVisibility = State(initialValue: .automatic)
        _searchText = State(initialValue: "")
        _pendingCaptures = State(initialValue: [])
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } content: {
            surfaceList
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $searchText, prompt: "Search Hive")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    selectedSurface = .field
                } label: {
                    HiveSymbol(.feedHive, size: 18, active: true)
                }
                .keyboardShortcut("n", modifiers: [.command])
                .accessibilityLabel("Add to Field")

                Button {
                    selectedSurface = .swarm
                } label: {
                    HiveSymbol(.chat, size: 18, active: selectedSurface == .swarm)
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .accessibilityLabel("Ask Swarm")
            }
        }
        .onDrop(of: [UTType.fileURL.identifier, UTType.text.identifier], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    private var layoutMode: HiveIPadLayoutMode {
        horizontalSizeClass == .compact ? .compactOneColumn : .regularTwoColumn
    }

    private var sidebar: some View {
        List {
            ForEach(HiveIPadSurface.allCases) { surface in
                Button {
                    selectedSurface = surface
                    navigationState.selectedSurface = surface.rawValue
                } label: {
                    Label {
                        Text(surface.rawValue)
                    } icon: {
                        HiveSymbol(surface.symbol, size: 16, active: selectedSurface == surface)
                    }
                }
            }
        }
        .navigationTitle("Hive")
    }

    private var surfaceList: some View {
        List {
            Section("Ready") {
                row(title: selectedSurface.rawValue, subtitle: subtitle(for: selectedSurface), symbol: selectedSurface.symbol)
                if !pendingCaptures.isEmpty {
                    ForEach(pendingCaptures, id: \.self) { capture in
                        row(title: capture.title, subtitle: "Ready to stage in Field", symbol: .importAction)
                    }
                }
            }
            Section("Input") {
                row(title: inputModeSummary, subtitle: "Touch, keyboard, pointer, Pencil, voice, and drag and drop are supported.", symbol: .attach)
            }
        }
        .navigationTitle(selectedSurface.rawValue)
        .keyboardShortcut("f", modifiers: [.command])
    }

    private var detailPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HiveSpacing.lg) {
                HStack(spacing: HiveSpacing.sm) {
                    HiveSymbol(selectedSurface.symbol, size: 22, active: true)
                    Text(selectedSurface.rawValue)
                        .font(.title2.weight(.semibold))
                }

                Text(detailCopy(for: selectedSurface))
                    .font(.body)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .lineSpacing(4)

                if selectedSurface == .field {
                    #if canImport(PencilKit)
                    HiveIPadPencilCanvas()
                        .frame(minHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: HiveRadius.lg, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: HiveRadius.lg, style: .continuous)
                                .stroke(HiveColorToken.waxAmber.color.opacity(0.10), lineWidth: 1)
                        }
                        .accessibilityLabel("Apple Pencil note canvas")
                    #endif
                }
            }
            .padding(HiveSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(HiveColorToken.backgroundDeep.color)
    }

    private var inputModeSummary: String {
        switch (layoutMode, dynamicTypeSize.isAccessibilitySize) {
        case (.compactOneColumn, true):
            return "Compact readable controls"
        case (.compactOneColumn, false):
            return "Compact multitasking layout"
        case (_, true):
            return "Readable split view"
        default:
            return "Split view workspace"
        }
    }

    private func row(title: String, subtitle: String, symbol: HiveSymbolName) -> some View {
        HStack(spacing: HiveSpacing.md) {
            HiveSymbol(symbol, size: 16, active: false)
            VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, HiveSpacing.xs)
    }

    private func subtitle(for surface: HiveIPadSurface) -> String {
        switch surface {
        case .field:
            return "Stage files, URLs, screenshots, notes, and share sheet captures."
        case .colony:
            return "Read and search the organized wiki."
        case .hive:
            return "Explore the knowledge graph with touch, pointer, and keyboard."
        case .swarm:
            return "Ask questions, use voice, and continue current work."
        }
    }

    private func detailCopy(for surface: HiveIPadSurface) -> String {
        switch surface {
        case .field:
            return "Drop files from Files, drag text from another app, paste links, or sketch notes with Apple Pencil before Hive stages them."
        case .colony:
            return "The Colony stays readable in split view, Slide Over, Stage Manager, and external display setups."
        case .hive:
            return "The graph keeps content central while controls stay reachable at the edge for touch, trackpad, and keyboard users."
        case .swarm:
            return "Swarm keeps the current conversation available across app and pop-up entry points without forcing a full-screen transition."
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let accepted = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                || $0.hasItemConformingToTypeIdentifier(UTType.text.identifier)
        }
        for provider in accepted {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url = (item as? URL)
                        ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                    appendPendingCapture(title: url?.lastPathComponent ?? "Dropped file", text: url?.absoluteString ?? "")
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                    let text = (item as? String)
                        ?? (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
                        ?? ""
                    appendPendingCapture(title: text.components(separatedBy: .newlines).first ?? "Dropped text", text: text)
                }
            }
        }
        return !accepted.isEmpty
    }

    private func appendPendingCapture(title: String, text: String) {
        DispatchQueue.main.async {
            pendingCaptures.append(HiveShareCapturePayload(title: title, text: text))
            navigationState.shareExtensionPendingCount = pendingCaptures.count
        }
    }
}

@available(iOS 17.0, *)
public struct HiveIPhoneRootView: View {
    @State private var navigationState: HiveMobileNavigationState
    @State private var selectedSurface: HiveIPadSurface
    @State private var prompt: String
    @State private var searchText: String
    @State private var pendingCaptures: [HiveShareCapturePayload]
    @State private var activityItems: [String]
    @State private var showsActivityView: Bool
    @State private var isRecordingVoice = false
    private var onSendPrompt: ((String, HiveIPadSurface) -> Void)?
    private var onVoiceInput: (() -> Void)?
    private var onAttach: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    public init(
        navigationState: HiveMobileNavigationState = HiveMobileNavigationState(),
        onSendPrompt: ((String, HiveIPadSurface) -> Void)? = nil,
        onVoiceInput: (() -> Void)? = nil,
        onAttach: (() -> Void)? = nil
    ) {
        _navigationState = State(initialValue: navigationState)
        _selectedSurface = State(initialValue: HiveIPadSurface(rawValue: navigationState.selectedSurface) ?? .field)
        _prompt = State(initialValue: "")
        _searchText = State(initialValue: "")
        _pendingCaptures = State(initialValue: [])
        _activityItems = State(initialValue: [])
        _showsActivityView = State(initialValue: false)
        self.onSendPrompt = onSendPrompt
        self.onVoiceInput = onVoiceInput
        self.onAttach = onAttach
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    surfaceSwitcher
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section(selectedSurface.rawValue) {
                    primarySurfaceRow
                    if !pendingCaptures.isEmpty {
                        ForEach(pendingCaptures, id: \.self) { capture in
                            captureRow(capture)
                        }
                    } else {
                        row(
                            title: emptyTitle,
                            subtitle: emptySubtitle,
                            symbol: selectedSurface.symbol
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(selectedSurface.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search Hive")
            .refreshable {
                navigationState.shareExtensionPendingCount = pendingCaptures.count
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            selectedSurface = .field
                        } label: {
                            mobileActionLabel("Add to Field", symbol: .feedHive)
                        }
                        Button {
                            selectedSurface = .swarm
                        } label: {
                            mobileActionLabel("Ask Swarm", symbol: .chat)
                        }
                        Button {
                            shareCurrentContext()
                        } label: {
                            mobileActionLabel("Share", symbol: .importAction)
                        }
                    } label: {
                        HiveSymbol(.ellipsis, size: 20, active: true)
                    }
                    .accessibilityLabel("More actions")
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomComposer
            }
            .onDrop(of: [UTType.fileURL.identifier, UTType.text.identifier], isTargeted: nil) { providers in
                handleDrop(providers)
            }
            .sheet(isPresented: $showsActivityView) {
                HiveIPhoneActivityView(activityItems: activityItems)
            }
        }
    }

    private var surfaceSwitcher: some View {
        Picker("Surface", selection: $selectedSurface) {
            ForEach(HiveIPadSurface.allCases) { surface in
                mobileActionLabel(surface.rawValue, symbol: surface.symbol)
                    .tag(surface)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, HiveSpacing.md)
        .padding(.vertical, HiveSpacing.sm)
        .onChange(of: selectedSurface) { _, newValue in
            navigationState.selectedSurface = newValue.rawValue
        }
    }

    private var primarySurfaceRow: some View {
        row(
            title: iPhoneLayoutTitle,
            subtitle: iPhoneLayoutSubtitle,
            symbol: selectedSurface.symbol
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                shareCurrentContext()
            } label: {
                mobileActionLabel("Share", symbol: .importAction)
            }
            Button {
                selectedSurface = .swarm
            } label: {
                mobileActionLabel("Ask", symbol: .chat)
            }
        }
    }

    private var bottomComposer: some View {
        HStack(spacing: HiveSpacing.sm) {
            Button {
                if let onVoiceInput {
                    onVoiceInput()
                } else {
                    isRecordingVoice.toggle()
                    selectedSurface = .swarm
                }
            } label: {
                HiveSymbol(.voiceNote, size: 18, active: isRecordingVoice)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRecordingVoice ? "Stop voice input" : "Start voice input")

            TextField(composerPlaceholder, text: $prompt, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .submitLabel(.send)
                .onSubmit(sendPrompt)

            Button {
                if let onAttach {
                    onAttach()
                } else {
                    selectedSurface = .field
                }
            } label: {
                HiveSymbol(.attach, size: 18, active: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Attach source")

            Button(action: sendPrompt) {
                HiveSymbol(.send, size: 18, active: !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .buttonStyle(.plain)
            .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Send")
        }
        .padding(HiveSpacing.md)
        .background(HiveColorToken.raisedSurface.color)
        .clipShape(RoundedRectangle(cornerRadius: HiveRadius.lg, style: .continuous))
        .padding(.horizontal, HiveSpacing.md)
        .padding(.bottom, HiveSpacing.sm)
    }

    private var composerPlaceholder: String {
        if CapabilityStore.shared.tier == .coreMLDistilled {
            return "Search your knowledge base (AI generation unavailable on this device)"
        }
        return "Ask or add to Field"
    }

    private var iPhoneLayoutTitle: String {
        switch selectedSurface {
        case .field:
            return "Capture quickly"
        case .colony:
            return "Read the useful version"
        case .hive:
            return "Explore connections"
        case .swarm:
            return "Ask without leaving flow"
        }
    }

    private var iPhoneLayoutSubtitle: String {
        if dynamicTypeSize.isAccessibilitySize {
            return "Controls stay low and readable for larger text."
        }
        if verticalSizeClass == .compact {
            return "Landscape keeps the current task first and moves actions into menus."
        }
        switch selectedSurface {
        case .field:
            return "Use the bottom composer, share sheet, voice, or Home Screen action."
        case .colony:
            return "Search, swipe rows, and share useful articles without extra panels."
        case .hive:
            return "Tap nodes, pinch the graph, and keep detail actions discoverable."
        case .swarm:
            return "Continue quick questions from widgets, Spotlight, Shortcuts, or voice."
        }
    }

    private var emptyTitle: String {
        selectedSurface == .field ? "No staged captures" : "Ready"
    }

    private var emptySubtitle: String {
        selectedSurface == .field ? "Drop, paste, dictate, or share something into Hive." : "Search or use the bottom composer to continue."
    }

    private func row(title: String, subtitle: String, symbol: HiveSymbolName) -> some View {
        HStack(alignment: .top, spacing: HiveSpacing.md) {
            HiveSymbol(symbol, size: 18, active: selectedSurface.symbol == symbol)
            VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, HiveSpacing.xs)
    }

    private func mobileActionLabel(_ title: String, symbol: HiveSymbolName) -> some View {
        Label {
            Text(title)
        } icon: {
            HiveSymbol(symbol, size: 16, active: true)
        }
    }

    private func captureRow(_ capture: HiveShareCapturePayload) -> some View {
        row(
            title: capture.title,
            subtitle: "Ready to stage from iPhone",
            symbol: .importAction
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                pendingCaptures.removeAll { $0 == capture }
                navigationState.shareExtensionPendingCount = pendingCaptures.count
            } label: {
                mobileActionLabel("Remove", symbol: .forget)
            }
            Button {
                activityItems = [capture.title, capture.text]
                showsActivityView = true
            } label: {
                mobileActionLabel("Share", symbol: .importAction)
            }
        }
    }

    private func sendPrompt() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let onSendPrompt {
            onSendPrompt(trimmed, selectedSurface)
        } else {
            pendingCaptures.append(HiveShareCapturePayload(title: "Quick note", text: trimmed))
            navigationState.shareExtensionPendingCount = pendingCaptures.count
            selectedSurface = .swarm
        }
        prompt = ""
    }

    private func shareCurrentContext() {
        activityItems = [selectedSurface.rawValue, iPhoneLayoutSubtitle]
        showsActivityView = true
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let accepted = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                || $0.hasItemConformingToTypeIdentifier(UTType.text.identifier)
        }
        for provider in accepted {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url = (item as? URL)
                        ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                    appendPendingCapture(title: url?.lastPathComponent ?? "Dropped file", text: url?.absoluteString ?? "")
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                    let text = (item as? String)
                        ?? (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
                        ?? ""
                    appendPendingCapture(title: text.components(separatedBy: .newlines).first ?? "Dropped text", text: text)
                }
            }
        }
        return !accepted.isEmpty
    }

    private func appendPendingCapture(title: String, text: String) {
        DispatchQueue.main.async {
            pendingCaptures.append(HiveShareCapturePayload(title: title, text: text))
            navigationState.shareExtensionPendingCount = pendingCaptures.count
        }
    }
}

@available(iOS 17.0, *)
public struct HiveIPhoneActivityView: UIViewControllerRepresentable {
    public var activityItems: [String]

    public init(activityItems: [String]) {
        self.activityItems = activityItems
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems.map { $0 as Any }, applicationActivities: nil)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

#if os(iOS) && canImport(CoreMotion)
public struct HiveIPhoneMotionCapabilityProbe: Hashable, Sendable {
    public var supportsDeviceMotion: Bool
    public var supportsAccelerometer: Bool
    public var supportsGyroscope: Bool

    public init(manager: CMMotionManager = CMMotionManager()) {
        self.supportsDeviceMotion = manager.isDeviceMotionAvailable
        self.supportsAccelerometer = manager.isAccelerometerAvailable
        self.supportsGyroscope = manager.isGyroAvailable
    }

    public var supportsMotionContext: Bool {
        supportsDeviceMotion || supportsAccelerometer || supportsGyroscope
    }
}
#endif

#if os(iOS) && canImport(SwiftUI) && canImport(PencilKit)
@available(iOS 17.0, *)
public struct HiveIPadPencilCanvas: UIViewRepresentable {
    public init() {}

    public func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        return canvas
    }

    public func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
#endif

public struct HiveMobileCloudContinuityPolicy: Hashable, Sendable {
    public var usesICloudForWholeHive: Bool
    public var avoidsPerDocumentChoices: Bool
    public var keepsModelsLocal: Bool
    public var includesHiveContentInSearch: Bool

    public init(
        usesICloudForWholeHive: Bool = true,
        avoidsPerDocumentChoices: Bool = true,
        keepsModelsLocal: Bool = true,
        includesHiveContentInSearch: Bool = true
    ) {
        self.usesICloudForWholeHive = usesICloudForWholeHive
        self.avoidsPerDocumentChoices = avoidsPerDocumentChoices
        self.keepsModelsLocal = keepsModelsLocal
        self.includesHiveContentInSearch = includesHiveContentInSearch
    }

    public static let defaultPolicy = HiveMobileCloudContinuityPolicy()

    public var followsICloudGuidance: Bool {
        usesICloudForWholeHive
            && avoidsPerDocumentChoices
            && keepsModelsLocal
            && includesHiveContentInSearch
            && HiveCloudSyncPolicy.default.followsICloudGuidance
    }
}
