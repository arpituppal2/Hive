import SwiftUI
import HiveCore
import HiveDesignSystem
import HiveMetalRenderer
import HiveUI
#if os(macOS)
import AppKit
#endif

private enum HiveSidebarSurfaceScrollDirection {
    case forward
    case backward

    var transition: AnyTransition {
        switch self {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            )
        }
    }
}

public struct HiveMacRootView: View {
    @EnvironmentObject private var model: HiveAppModel
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("hive.sidebarVisible") private var sidebarVisible = true
    @AppStorage("hive.appearanceMode") private var appearanceModeRaw = HiveAppearanceMode.system.rawValue
    @AppStorage("hive.graph.useAppKitCanvas") private var graphUsesAppKitCanvas = false
    @AppStorage(HiveInterfaceScale.storageKey) private var interfaceScale = HiveInterfaceScale.defaultValue
    @Namespace private var sidebarSelectionNamespace
    @State private var hasSeenOnboarding: Bool
    @State private var didRegisterAppOpen = false
    @State private var dailyUseTipsVisible = false
    @State private var surfaceScrollDirection: HiveSidebarSurfaceScrollDirection = .forward

    public init() {
        _hasSeenOnboarding = State(initialValue: HiveOnboardingStore.isCompleted())
    }

    public var body: some View {
        rootContent
            .background(HiveHoneyBackdrop().ignoresSafeArea())
            .overlay {
                HiveWindowChromeConfigurator(colorScheme: colorScheme)
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
            }
            .tint(HiveColorToken.waxAmber.color)
            .accentColor(HiveColorToken.waxAmber.color)
            .preferredColorScheme(appearanceMode.preferredScheme)
            .sheet(isPresented: settingsVisibleBinding) {
                HiveSettingsSheet(appearanceModeRaw: $appearanceModeRaw, interfaceScale: $interfaceScale) {
                    model.settingsVisible = false
                }
                .frame(
                    minWidth: HiveLayoutMetrics.settingsWindowMinWidth,
                    idealWidth: HiveLayoutMetrics.settingsWindowIdealWidth,
                    minHeight: HiveLayoutMetrics.settingsWindowMinHeight,
                    idealHeight: HiveLayoutMetrics.settingsWindowIdealHeight
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(HiveColorToken.backgroundMid.color)
            }
            .sheet(item: $model.sourcePreview) { preview in
                RawSourcePreviewSheet(preview: preview)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(HiveColorToken.backgroundMid.color)
            }
            .sheet(item: $model.processingResult) { result in
                ProcessingResultView(
                    result: result,
                    onOpenColony: {
                        model.processingResult = nil
                        model.selectedSurface = .wiki
                    },
                    onOpenHive: {
                        model.processingResult = nil
                        model.selectedSurface = .graph
                    },
                    onRetry: {
                        let sourceID = result.sourceID
                        model.processingResult = nil
                        if let sourceID {
                            model.reprocessSource(sourceID: sourceID)
                        }
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(HiveColorToken.backgroundMid.color)
            }
            .sheet(item: $model.firstLoginDataChoicePrompt) { prompt in
                HiveFirstLoginDataChoiceSheet(prompt: prompt) { choice in
                    model.resolveFirstLoginDataChoice(choice)
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(HiveColorToken.backgroundMid.color)
            }
            .onAppear { handleAppAppear() }
            #if canImport(AppIntents)
            .onReceive(NotificationCenter.default.publisher(for: HiveIntentRequestStore.didChangeNotification)) { _ in
                processPendingIntentRequests()
            }
            #endif
    }

    @ViewBuilder
    private var rootContent: some View {
        if !model.isAppleAuthenticated {
            HiveAppleLoginGate(
                onAuthenticated: {
                    model.validateAppleCredentialState()
                },
                onContinueAsGuest: {
                    model.continueAsGuestForNow()
                }
            )
        } else {
            ZStack(alignment: .trailing) {
                nativeShell
                if let runtimeNotice {
                    HiveRuntimeStatusBanner(
                        notice: runtimeNotice,
                        onDismiss: {
                            model.errorText = nil
                            if model.topicDominanceWarning != nil {
                                model.dismissTopicDominanceWarningForSession()
                            }
                        },
                        onOpenSettings: {
                            model.chatVisible = false
                            model.commandPaletteVisible = false
                            openSettingsWindow()
                        }
                    )
                    .frame(maxWidth: 420)
                    .padding(.top, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                if model.commandPaletteVisible {
                    activeScrim
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            model.commandPaletteVisible = false
                        }
                }
                if model.commandPaletteVisible {
                    HiveCommandPalette(
                        query: $model.commandText,
                        onCommand: handleCommand,
                        commandAvailability: { command in
                            model.commandAvailability(for: command)
                        },
                        onDismiss: { model.commandPaletteVisible = false }
                    )
                    .transition(.opacity)
                }
                if !hasSeenOnboarding {
                    HiveOnboardingOverlay(
                        onSkip: { setHasSeenOnboarding(true) },
                        onPreviewStep: { surface, step in
                            withAnimation(HiveMotion.panel) {
                                model.selectedSurface = surface
                                if step == 4 {
                                    model.selectedSourceID = model.sourcePresentations.first?.id
                                } else if surface != .rawInputs {
                                    model.selectedSourceID = nil
                                }
                            }
                        },
                        onStart: { sourcePluginRequest in
                            setHasSeenOnboarding(true)
                            model.selectedSurface = .rawInputs
                            model.configureStartupSourcePlugins(sourcePluginRequest)
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    .zIndex(50)
                }
                if hasSeenOnboarding && dailyUseTipsVisible {
                    HiveDailyUseTipsOverlay(
                        onUseTemplate: useDailyUseTemplate,
                        onDismiss: { dailyUseTipsVisible = false }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    .zIndex(45)
                }
                if hasSeenOnboarding && model.liveVisible {
                    HiveLiveAssistantOverlay(
                        text: $model.liveText,
                        spokenText: model.liveSpokenText,
                        spokenSequence: model.liveSpokenSequence,
                        isWorking: model.isWorking,
                        statusText: model.liveStatusText,
                        onSubmit: { model.submitLiveAssistantPrompt($0) },
                        onCaptureScreen: {
                            model.captureCurrentPage(command: "Capture the current screen for Hive Live.")
                        },
                        onClose: { model.closeLiveAssistant() }
                    )
                    .frame(width: 560)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(40)
                }
            }
        }
    }

    private var nativeShell: some View {
        HStack(spacing: 0) {
            if sidebarVisible {
                nativeSidebar
                    .frame(width: HiveLayoutMetrics.sidebarWidth)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            ZStack(alignment: .topLeading) {
                detailShell
                if !sidebarVisible {
                    navigatorRestoreButton
                        .padding(.top, HiveSpacing.md)
                        .padding(.leading, HiveSpacing.md)
                        .transition(.scale(scale: 0.94, anchor: .topLeading).combined(with: .opacity))
                }
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(HiveColorToken.backgroundDeep.color)
        .animation(HiveMotion.panel, value: sidebarVisible)
        .animation(HiveMotion.panel, value: model.chatVisible)
    }

    private var detailShell: some View {
        HStack(spacing: 0) {
            ZStack {
                mainSurface
                    .id(model.selectedSurface.id)
                    .transition(surfaceScrollDirection.transition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(HiveColorToken.backgroundDeep.color.opacity(colorScheme == .dark ? 0.08 : 0.18))
            .clipped()
            .animation(HiveMotion.sidebarPageScroll, value: model.selectedSurface)
            if model.chatVisible && model.selectedSurface != .swarm {
                chatSidePanel
                    .frame(width: HiveLayoutMetrics.sheetWidth)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
    }

    private var chatSidePanel: some View {
        HiveChatSheet(
            text: $model.chatText,
            entries: model.chatEntries,
            statusText: model.chatStatusText,
            onSend: { model.sendChat() },
            onFileAnswer: { model.fileLastChatAnswerToWiki() },
            onClose: { model.chatVisible = false }
        )
        .modifier(HiveGlassShell(level: .chatSheet))
        .padding(.vertical, 12)
        .padding(.trailing, 12)
        .frame(maxHeight: .infinity)
    }

    private var nativeSidebar: some View {
        HiveLiquidGlassSurface(placement: .navigation) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Spacer(minLength: 0)
                    HiveToolbarIconButton(.sidebar, accessibilityLabel: "Collapse Navigator", active: true) {
                        setSidebarVisible(false)
                    }
                    .help("Collapse Navigator")
                }
                .frame(height: 36)
                .padding(.horizontal, HiveSpacing.sm)
                .padding(.bottom, HiveSpacing.sm)
                ForEach(HivePrimarySurface.allCases) { surface in
                    Button {
                        selectSurface(surface)
                    } label: {
                        HiveSidebarRow(
                            surface: surface,
                            selected: model.selectedSurface == surface,
                            selectionNamespace: sidebarSelectionNamespace
                        )
                    }
                    .buttonStyle(HiveControlPressStyle())
                    .help("Show \(surface.displayTitle)")
                    .accessibilityHint("Shows \(surface.displayTitle).")
                }
                Spacer(minLength: 0)
                Rectangle()
                    .fill(HiveColorToken.scaffoldFaint.color.opacity(0.18))
                    .frame(height: 1)
                    .padding(.horizontal, HiveSpacing.lg)
                    .padding(.bottom, HiveSpacing.sm)
                Button {
                    openSettingsWindow()
                } label: {
                    HiveSidebarActionRow(symbol: .settings, title: "Settings")
                }
                .buttonStyle(.plain)
                .help("Open Settings")
                .accessibilityLabel("Settings")
            }
            .padding(.horizontal, HiveSpacing.sm)
            .padding(.top, HiveSpacing.xl)
            .padding(.bottom, HiveSpacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(HiveColorToken.backgroundDeep.color)
    }

    private var navigatorRestoreButton: some View {
        HiveToolbarIconButton(.sidebar, accessibilityLabel: "Show Navigator", active: true) {
            setSidebarVisible(true)
        }
        .help("Show Navigator")
        .zIndex(12)
    }

    private static func defaultBool(_ key: String, fallback: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return fallback }
        return UserDefaults.standard.bool(forKey: key)
    }

    private func setHasSeenOnboarding(_ value: Bool) {
        hasSeenOnboarding = value
        if value {
            HiveOnboardingStore.markCompleted()
        } else {
            HiveOnboardingStore.resetForReplay()
        }
    }

    private func handleAppAppear() {
        let isAuthenticated = model.refreshAppleAuthentication()
        model.validateAppleCredentialState()
        if isAuthenticated {
            model.refreshFromStore()
        }
        if isAuthenticated {
            processPendingIntentRequests()
        }
        guard !didRegisterAppOpen else { return }
        didRegisterAppOpen = true

        let defaults = UserDefaults.standard
        let openCount = defaults.integer(forKey: "hive.appOpenCount") + 1
        defaults.set(openCount, forKey: "hive.appOpenCount")

        let lastShownOpen = defaults.integer(forKey: "hive.dailyUseTips.lastShownOpen")
        if hasSeenOnboarding,
           (2...3).contains(openCount),
           lastShownOpen != openCount {
            dailyUseTipsVisible = true
            defaults.set(openCount, forKey: "hive.dailyUseTips.lastShownOpen")
        }
    }

    private func useDailyUseTemplate(_ template: String) {
        model.commandPaletteVisible = false
        model.chatVisible = true
        model.chatText = template
        dailyUseTipsVisible = false
    }

    private func processPendingIntentRequests() {
        #if canImport(AppIntents)
        guard model.isAppleAuthenticated else {
            let blockedRequests = HiveIntentRequestStore.consumePending()
            if !blockedRequests.isEmpty {
                model.errorText = "Sign in to Hive before using Hive shortcuts."
            }
            return
        }
        let requests = HiveIntentRequestStore.consumePending()
        guard !requests.isEmpty else { return }
        for request in requests {
            handleIntentRequest(request)
        }
        #endif
    }

    #if canImport(AppIntents)
    private func handleIntentRequest(_ request: HiveIntentRequest) {
        switch request.route {
        case .requiresLogin:
            model.errorText = "Sign in to Hive before using Hive shortcuts."
        case .quickCapture:
            model.selectedSurface = .rawInputs
            if let text = request.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                model.ingestText(text)
            }
        case .feedHive, .importEvidence:
            model.selectedSurface = .rawInputs
        case .askHive:
            model.chatVisible = true
            if let query = request.query?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
                model.chatText = query
                model.sendChat()
            }
        case .openWiki:
            model.selectedSurface = .wiki
            if let query = request.query?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty,
               let page = model.wikiPages.first(where: { $0.title.localizedCaseInsensitiveContains(query) || query.localizedCaseInsensitiveContains($0.title) }) {
                model.selectedPageID = page.id
            }
        case .showGraph:
            model.selectedSurface = .graph
            if let query = request.query?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
                model.graphSearchText = query
                model.graphSearchVisible = true
            }
        case .consolidateArticles:
            model.selectedSurface = .wiki
        case .captureCurrentPage:
            model.selectedSurface = .rawInputs
            model.captureCurrentPage(command: "Capture the current page as Field evidence for Hive.")
        case .downloadAttachments:
            model.selectedSurface = .wiki
            model.downloadAttachmentsForSelectedWikiPage()
        case .summarizeRecentInputs:
            model.selectedSurface = .rawInputs
            model.ask("What changed recently in the Field?")
        case .runMemoryMaintenance:
            model.refreshKnowledge()
        case .toggleMenuBar:
            let visible = UserDefaults.standard.object(forKey: "hive.menuBarExtraVisible") as? Bool ?? true
            UserDefaults.standard.set(!visible, forKey: "hive.menuBarExtraVisible")
        }
    }
    #endif

    private func setSidebarVisible(_ value: Bool) {
        sidebarVisible = value
        UserDefaults.standard.set(value, forKey: "hive.sidebarVisible")
    }

    private var appearanceMode: HiveAppearanceMode {
        HiveAppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var activeScrim: Color {
        if model.commandPaletteVisible {
            return colorScheme == .dark
                ? HiveColorToken.backgroundDeep.color.opacity(0.76)
                : HiveColorToken.backgroundDeep.color.opacity(0.22)
        }
        return colorScheme == .dark
            ? HiveColorToken.backgroundDeep.color.opacity(0.44)
            : HiveColorToken.backgroundDeep.color.opacity(0.12)
    }

    private var runtimeNotice: HiveRuntimeStatusNotice? {
        if model.errorText != nil {
            return HiveRuntimeStatusNotice(
                symbol: .conflict,
                title: "Hive needs attention",
                message: "Review settings or try the last action again.",
                actionTitle: "Settings",
                dismissible: true
            )
        }
        if model.isWorking {
            return HiveRuntimeStatusNotice(
                symbol: .synthesizing,
                title: "Updating The Colony",
                message: "Hive is reading the Field and refreshing The Hive.",
                actionTitle: nil,
                dismissible: false
            )
        }
        if model.selectedSurface == .rawInputs,
           !model.topicDominanceDismissedForSession,
           let warning = model.topicDominanceWarning {
            return HiveRuntimeStatusNotice(
                symbol: .conflict,
                title: "Topic dominance detected",
                message: "\(warning.topic) has \(warning.claimCount) of \(warning.totalClaims) claims (\(Int((warning.ratio * 100).rounded()))%). Add broader sources to reduce answer skew.",
                actionTitle: nil,
                dismissible: true
            )
        }
        return nil
    }

    @ViewBuilder
    private var mainSurface: some View {
        switch model.selectedSurface {
        case .rawInputs:
            HStack(spacing: 0) {
                RawInputsSurface(
                    sources: model.sourcePresentations,
                    rawSources: model.rawSourcePresentations,
                    clusters: model.rawInputClusters,
                    organismState: model.organismState,
                    selectedSourceID: model.selectedSourceID,
                    onSelect: { model.selectedSourceID = $0 },
                    onImport: { model.ingest(urls: $0) },
                    onSubmitText: { model.ingestText($0) },
                    onRequestImport: openImportPanel,
                    onSynthesize: { model.refreshKnowledge() },
                    onProcessNow: { model.processSourceNow(sourceID: $0) },
                    onRemoveSource: { model.removeRawSource(sourceID: $0) },
                    onPreviewSource: { model.previewSource(sourceID: $0) },
                    onReprocessSource: { model.extractMoreFromSource(sourceID: $0) },
                    isWorking: model.isWorking
                )
                if let source = model.selectedSource {
                    let presentation = model.sourcePresentations.first { $0.sourceID == source.id }
                        ?? SourcePresentationModel(source: source)
                    Divider()
                    SourceInspector(source: source, presentation: presentation) { question in
                        model.ask("For \(SourcePresentationModel.naturalTitle(for: source)): \(question)")
                    } onArchive: {
                        model.archive(sourceID: source.id)
                    } onForget: {
                        model.forget(sourceID: source.id)
                    } onClose: {
                        model.selectedSourceID = nil
                    }
                    .frame(width: HiveLayoutMetrics.sourceInspectorWidth)
                    .frame(maxHeight: .infinity)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
            }
            .animation(HiveMotion.reveal, value: model.selectedSourceID)
        case .wiki:
            WikiSurface(
                pages: model.wikiPages,
                claims: model.claims,
                sources: model.rawSourcePresentations,
                selectedPageID: model.selectedPageID,
                selectedClaimID: model.selectedClaimID,
                onSelectPage: { model.selectedPageID = $0 },
                onSelectClaim: { model.selectedClaimID = $0 },
                onCloseClaimInspector: { model.selectedClaimID = nil },
                onClaimAction: { action, claimID in model.applyClaimAction(action, claimID: claimID) },
                onSavePage: { pageID, markdown in model.saveWiki(pageID: pageID, markdown: markdown) },
                onConsolidateArticles: { pageIDs in model.consolidateWikiArticles(pageIDs: pageIDs) },
                onDeleteArticles: { pageIDs in model.deleteWikiArticles(pageIDs: pageIDs) },
                onOpenGraphNode: { pageID, title, claimID in
                    model.openGraph(pageID: pageID, title: title, claimID: claimID)
                },
                onAskWiki: { question in
                    model.ask(question)
                }
            )
        case .graph:
            Group {
                if graphUsesAppKitCanvas {
                    HiveAppKitGraphSurface(
                        graph: model.graph,
                        selectedNodeID: model.selectedNodeID,
                        onSelectNode: { model.selectedNodeID = $0 }
                    )
                } else {
                    HiveGraphSurface(
                        graph: model.graph,
                        changeAnimationList: model.graphAnimationList,
                        selectedNodeID: model.selectedNodeID,
                        searchText: model.graphSearchText,
                        searchVisible: model.graphSearchVisible,
                        onSelectNode: { model.selectedNodeID = $0 },
                        onOpenWiki: { nodeID in model.openWiki(forGraphNodeID: nodeID) },
                        onSearchChange: { model.graphSearchText = $0 },
                        onNodeFeedback: { action, nodeID in model.applyGraphNodeAction(action, nodeID: nodeID) },
                        onConfirmPlacement: { nodeID, x, y in model.confirmGraphPlacement(nodeID: nodeID, x: x, y: y) },
                        onAskNode: { question in
                            model.ask(question)
                        },
                        onReindex: { plan in model.reindexHive(plan: plan) },
                        onImportDocuments: openImportPanel,
                        externalReindexRequestID: model.graphReindexRequestID
                    )
                    .overlay(HiveAccessibilityNodeOverlay(nodes: model.visibleGraphNodes) { model.selectedNodeID = $0 })
                }
            }
        case .swarm:
            SwarmSurface(
                model: model,
                onCommand: handleCommand,
                onOpenImportPanel: openImportPanel
            )
        }
    }

    private func selectSurface(_ surface: HivePrimarySurface) {
        let previousSurface = model.selectedSurface
        if previousSurface != surface {
            surfaceScrollDirection = surface.sidebarOrder >= previousSurface.sidebarOrder ? .forward : .backward
        }
        withAnimation(AnimationKit.pageTransition(previousSurface == surface ? HiveMotion.focus : HiveMotion.sidebarPageScroll)) {
            model.selectedSurface = surface
            model.chatVisible = false
            model.commandPaletteVisible = false
            model.selectedSourceID = nil
            model.selectedClaimID = nil
            model.selectedNodeID = nil
        }
    }

    private func handleCommand(_ command: HiveCommand) {
        if command == .settings {
            model.commandText = ""
            model.commandPaletteVisible = false
            model.chatVisible = false
            model.settingsVisible = false
            openSettingsWindow()
            return
        }
        model.executeCommand(command)
        if command == .addSources {
            openImportPanel()
        }
    }

    private func openSettingsWindow() {
        model.commandPaletteVisible = false
        model.chatVisible = false
        model.settingsVisible = true
    }

    private func openImportPanel() {
        #if os(macOS)
        model.commandPaletteVisible = false
        model.chatVisible = false
        model.settingsVisible = false
        model.selectedSurface = .rawInputs
        HiveMacWindowPresenter.presentFieldImportPanel { urls in
            model.ingest(urls: urls)
        }
        #endif
    }
}

private extension HiveMacRootView {
    var settingsVisibleBinding: Binding<Bool> {
        Binding(
            get: { model.settingsVisible },
            set: { model.settingsVisible = $0 }
        )
    }
}

#if os(macOS)
private struct HiveWindowChromeConfigurator: NSViewRepresentable {
    var colorScheme: ColorScheme

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: view.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        let chromeColor = NSColor.hiveChromeBackground(for: colorScheme)
        window.styleMask.insert(.fullSizeContentView)
        window.backgroundColor = chromeColor
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = true
        window.isMovableByWindowBackground = false
        window.appearance = colorScheme == .dark ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unified
        }
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = chromeColor.cgColor
    }
}

private extension NSColor {
    static func hiveChromeBackground(for colorScheme: ColorScheme) -> NSColor {
        let hex = colorScheme == .dark
            ? HiveColorToken.backgroundDeep.rawValue
            : HiveColorToken.backgroundDeep.lightRawValue
        let components = hiveChromeComponents(hex)
        return NSColor(
            calibratedRed: components.channel0,
            green: components.channel1,
            blue: components.channel2,
            alpha: 1
        )
    }

    private static func hiveChromeComponents(_ hex: String) -> (channel0: CGFloat, channel1: CGFloat, channel2: CGFloat) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let channel0 = CGFloat((value >> 16) & 0xFF) / 255
        let channel1 = CGFloat((value >> 8) & 0xFF) / 255
        let channel2 = CGFloat(value & 0xFF) / 255
        return (channel0, channel1, channel2)
    }
}
#endif

private extension HivePrimarySurface {
    var sidebarOrder: Int {
        HivePrimarySurface.allCases.firstIndex(of: self) ?? 0
    }

    var symbolName: HiveSymbolName {
        switch self {
        case .rawInputs:
            return .rawInputs
        case .wiki:
            return .wiki
        case .graph:
            return .hiveGraph
        case .swarm:
            return .liveAssistant
        }
    }
}

private struct HiveRuntimeStatusNotice: Hashable {
    var symbol: HiveSymbolName
    var title: String
    var message: String
    var actionTitle: String?
    var dismissible: Bool
}

private struct HiveRuntimeStatusBanner: View {
    var notice: HiveRuntimeStatusNotice
    var onDismiss: () -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HiveSymbol(
                notice.symbol,
                size: 17,
                active: notice.symbol == .synthesizing,
                motion: notice.symbol == .synthesizing ? .variableColor : .pulse,
                motionValue: notice.hashValue
            )
            VStack(alignment: .leading, spacing: 2) {
                HiveText(notice.title, role: .scaffoldAction)
                HiveText(notice.message, role: .scaffoldBody)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            if let actionTitle = notice.actionTitle {
                HiveSymbolButton(.settings, title: actionTitle, compact: true, action: onOpenSettings)
            }
            if notice.dismissible {
                HiveSymbolButton(.close, title: nil, compact: true, action: onDismiss)
            }
        }
        .padding(12)
        .modifier(HiveGlassShell(level: .popover))
        .accessibilityElement(children: .combine)
    }
}

private struct HiveHoneyBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            HiveColorToken.backgroundDeep.color
            LinearGradient(
                colors: [
                    HiveAmbientPalette.honeyHighlight(for: colorScheme).opacity(colorScheme == .dark ? 0.12 : 0.2),
                    HiveAmbientPalette.honeyGold(for: colorScheme).opacity(colorScheme == .dark ? 0.1 : 0.16),
                    HiveAmbientPalette.honeyAmber(for: colorScheme).opacity(colorScheme == .dark ? 0.08 : 0.1),
                    HiveColorToken.backgroundDeep.color.opacity(0.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [
                    HiveAmbientPalette.honeyHighlight(for: colorScheme).opacity(colorScheme == .dark ? 0.2 : 0.22),
                    HiveAmbientPalette.honeyGold(for: colorScheme).opacity(colorScheme == .dark ? 0.15 : 0.16),
                    HiveColorToken.backgroundDeep.color.opacity(0.0)
                ],
                center: UnitPoint(x: 0.22, y: 0.18),
                startRadius: 24,
                endRadius: 680
            )
            RadialGradient(
                colors: [
                    HiveAmbientPalette.honeyGold(for: colorScheme).opacity(colorScheme == .dark ? 0.14 : 0.12),
                    HiveAmbientPalette.honeyAmber(for: colorScheme).opacity(colorScheme == .dark ? 0.12 : 0.08),
                    HiveColorToken.backgroundDeep.color.opacity(0.0)
                ],
                center: .bottomTrailing,
                startRadius: 64,
                endRadius: 700
            )
            RadialGradient(
                colors: [
                    HiveAmbientPalette.meadowWarmth(for: colorScheme).opacity(colorScheme == .dark ? 0.08 : 0.12),
                    HiveColorToken.backgroundDeep.color.opacity(0.0)
                ],
                center: UnitPoint(x: 0.08, y: 0.88),
                startRadius: 30,
                endRadius: 520
            )
        }
    }
}

private struct HiveSidebarRow: View {
    var surface: HivePrimarySurface
    var selected: Bool
    var selectionNamespace: Namespace.ID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false

    var body: some View {
        HStack(spacing: HiveSpacing.sm) {
            HiveSymbol(
                surface.symbolName,
                size: 16,
                active: selected,
                rendering: .monochrome(selected ? HiveColorToken.waxAmber.color : HiveColorToken.nectarMuted.color)
            )
            .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            Text(surface.displayTitle)
                .font(HiveTypography.sidebarItem(selected: selected))
                .foregroundStyle(selected ? HiveColorToken.nectarText.color : HiveColorToken.nectarMuted.color)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, HiveSpacing.lg)
        .frame(height: 36)
        .background(sidebarRowBackground)
        .scaleEffect(reduceMotion ? 1 : (hovered ? 1.018 : 1), anchor: .center)
        .offset(x: reduceMotion ? 0 : (hovered ? 2 : 0), y: reduceMotion ? 0 : (hovered ? -1 : 0))
        .shadow(
            color: HiveColorToken.backgroundDeep.color.opacity(hovered || selected ? 0.16 : 0),
            radius: hovered || selected ? 10 : 0,
            x: 0,
            y: hovered || selected ? 5 : 0
        )
        .contentShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
        .onHover { value in
            withAnimation(HiveMotion.hoverLift) {
                hovered = value
            }
        }
        .animation(HiveMotion.hoverLift, value: hovered)
        .animation(HiveMotion.sidebarSelection, value: selected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(surface.displayTitle)
    }

    private var sidebarRowBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous)
                .fill(hovered && !selected ? HiveColorToken.cellSurface.color : Color.clear)
            if selected {
                RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous)
                    .fill(HiveColorToken.waxAmber.color.opacity(hovered ? 0.16 : 0.12))
                    .matchedGeometryEffect(
                        id: "sidebar-selected-surface",
                        in: selectionNamespace,
                        properties: .frame,
                        anchor: .center
                    )
            }
        }
    }
}

private struct HiveSidebarActionRow: View {
    var symbol: HiveSymbolName
    var title: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false

    var body: some View {
        HStack(spacing: HiveSpacing.sm) {
            HiveSymbol(symbol, size: 16, rendering: .monochrome(hovered ? HiveColorToken.waxAmber.color : HiveColorToken.nectarMuted.color))
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            Text(title)
                .font(HiveTypography.hiveBodyMed)
                .foregroundStyle(hovered ? HiveColorToken.nectarText.color : HiveColorToken.nectarMuted.color)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, HiveSpacing.lg)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous)
                .fill(hovered ? HiveColorToken.cellSurface.color : Color.clear)
        )
        .scaleEffect(reduceMotion ? 1 : (hovered ? 1.018 : 1), anchor: .center)
        .offset(x: reduceMotion ? 0 : (hovered ? 2 : 0), y: reduceMotion ? 0 : (hovered ? -1 : 0))
        .shadow(
            color: HiveColorToken.backgroundDeep.color.opacity(hovered ? 0.16 : 0),
            radius: hovered ? 10 : 0,
            x: 0,
            y: hovered ? 5 : 0
        )
        .contentShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
        .onHover { value in
            withAnimation(HiveMotion.hoverLift) {
                hovered = value
            }
        }
        .animation(HiveMotion.hoverLift, value: hovered)
    }
}

private struct HiveSettingsSheet: View {
    @EnvironmentObject private var model: HiveAppModel
    @Binding var appearanceModeRaw: String
    @Binding var interfaceScale: Double
    var onClose: () -> Void
    @State private var showsResetConfirmation = false
    @State private var showsResetFinalConfirmation = false
    @State private var integrityStatus = ""
    @AppStorage("hive.showSystemItemsInField") private var showSystemItems = false
    @AppStorage("hive.autoUpdateColonyOnCapture") private var autoUpdateColony = true
    @AppStorage("hive.colonyUpdateFrequency") private var updateFrequency = "After capture"
    @AppStorage(HiveMaintenanceSchedule.enabledKey, store: UserDefaults(suiteName: HiveMaintenanceSchedule.defaultsSuiteName)) private var morningBriefingEnabled = HiveMaintenanceSchedule.defaultEnabled
    @AppStorage(HiveMaintenanceSchedule.hourKey, store: UserDefaults(suiteName: HiveMaintenanceSchedule.defaultsSuiteName)) private var morningBriefingHour = HiveMaintenanceSchedule.defaultHour
    @AppStorage(HiveMaintenanceSchedule.minuteKey, store: UserDefaults(suiteName: HiveMaintenanceSchedule.defaultsSuiteName)) private var morningBriefingMinute = HiveMaintenanceSchedule.defaultMinute
    @State private var customAutomationVisible = false
    @State private var customAutomationGoal = ""
    @State private var customAutomationSources = ""
    @State private var customAutomationCadence = ""
    @State private var customAutomationFrequency = ""
    @State private var customAutomationTime = ""
    @State private var customAutomationDuration = ""
    @State private var customAutomationOutput = ""
    @State private var automationReadiness = HiveAutomationReadinessReport.current()

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Color scheme", selection: $appearanceModeRaw) {
                        ForEach(HiveAppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode.rawValue)
                        }
                    }
                    LabeledContent("Interface zoom") {
                        HStack(spacing: HiveSpacing.sm) {
                            Button {
                                interfaceScale = HiveInterfaceScale.normalized(interfaceScale - HiveInterfaceScale.step)
                            } label: {
                                HiveSymbol(.markIncidental, size: 13)
                            }
                            .buttonStyle(.plain)
                            .disabled(interfaceScale <= HiveInterfaceScale.minimum)
                            .accessibilityLabel("Zoom interface out")

                            Text(HiveInterfaceScale.label(for: interfaceScale))
                                .font(HiveTypography.hiveBodyMed)
                                .foregroundStyle(HiveColorToken.nectarText.color)
                                .monospacedDigit()
                                .frame(minWidth: 46)

                            Button {
                                interfaceScale = HiveInterfaceScale.normalized(interfaceScale + HiveInterfaceScale.step)
                            } label: {
                                HiveSymbol(.feedHive, size: 13, active: true)
                            }
                            .buttonStyle(.plain)
                            .disabled(interfaceScale >= HiveInterfaceScale.maximum)
                            .accessibilityLabel("Zoom interface in")
                        }
                    }
                    LabeledContent("Accent") {
                        HStack(spacing: HiveSpacing.sm) {
                            RoundedRectangle(cornerRadius: HiveRadius.sm, style: .continuous)
                                .fill(HiveColorToken.waxAmber.color)
                                .frame(width: 14, height: 14)
                            Text("Amber")
                                .foregroundStyle(HiveColorToken.nectarMuted.color)
                        }
                    }
                }

                Section("Memory") {
                    Toggle("Show system items in Field", isOn: $showSystemItems)
                    Toggle("Auto-update Colony on capture", isOn: $autoUpdateColony)
                    Picker("Colony update frequency", selection: $updateFrequency) {
                        Text("After capture").tag("After capture")
                        Text("Daily").tag("Daily")
                        Text("Manual").tag("Manual")
                    }
                }

                Section("Automations") {
                    VStack(alignment: .leading, spacing: HiveSpacing.sm) {
                        HStack {
                            HStack(spacing: HiveSpacing.sm) {
                                HiveSymbol(.synthesizing, size: 14, active: automationReadiness.settings.morningBriefingEnabled)
                                Text(automationReadiness.morningStatusTitle)
                            }
                            Spacer()
                            Button("Run Now") {
                                model.runMorningBriefingNow()
                                refreshAutomationReadiness()
                            }
                            .disabled(!morningBriefingEnabled)
                        }
                    }
                    Toggle("Morning Briefing", isOn: $morningBriefingEnabled)
                    Picker("Briefing hour", selection: $morningBriefingHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(Self.hourLabel(hour)).tag(hour)
                        }
                    }
                    .disabled(!morningBriefingEnabled)
                    Picker("Briefing minute", selection: $morningBriefingMinute) {
                        Text(":00").tag(0)
                        Text(":15").tag(15)
                        Text(":30").tag(30)
                        Text(":45").tag(45)
                    }
                    .disabled(!morningBriefingEnabled)
                    if !automationReadiness.settings.customAutomations.isEmpty {
                        ForEach(automationReadiness.settings.customAutomations) { automation in
                            LabeledContent(automation.title, value: automation.scheduleSummary)
                        }
                    }
                    Button {
                        withAnimation(HiveMotion.panel) {
                            customAutomationVisible.toggle()
                        }
                    } label: {
                        HStack(spacing: HiveSpacing.sm) {
                            HiveSymbol(.runMaintenance, size: 14, active: true)
                            Text("Create Automation")
                        }
                    }
                    if customAutomationVisible {
                        TextField("Goal", text: $customAutomationGoal)
                        TextField("Sources Hive may read", text: $customAutomationSources)
                        TextField("Frequency", text: $customAutomationFrequency)
                        TextField("Preferred time", text: $customAutomationTime)
                        TextField("Duration or stop rule", text: $customAutomationDuration)
                        TextField("Review policy", text: $customAutomationCadence)
                        TextField("Output page or action", text: $customAutomationOutput)
                        Button("Create Automation Request") {
                            addCustomAutomationRequest()
                        }
                        .disabled(customAutomationGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section("Privacy") {
                    LabeledContent {
                        Text("On this device")
                            .foregroundStyle(HiveColorToken.nectarMuted.color)
                    } label: {
                        HStack(spacing: HiveSpacing.sm) {
                            HiveSymbol(.localOnly, size: 14)
                            Text("Data location")
                        }
                    }
                    Button("Export all data") {
                        model.exportAllData()
                    }
                    Button("Run Integrity Check") {
                        integrityStatus = model.runIntegrityCheck()
                    }
                    if !integrityStatus.isEmpty {
                        Text(integrityStatus)
                            .font(HiveTypography.hiveBody)
                            .foregroundStyle(integrityStatus.contains("ok") ? HiveColorToken.sealed.color : HiveColorToken.conflict.color)
                    }
                    Button("Reset Hive", role: .destructive) {
                        showsResetConfirmation = true
                    }
                    .confirmationDialog(
                        "Reset Hive?",
                        isPresented: $showsResetConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Continue", role: .destructive) {
                            showsResetFinalConfirmation = true
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This removes derived memory and rebuilds an empty workspace. Field backups are preserved in Application Support.")
                    }
                    .alert("Confirm Reset", isPresented: $showsResetFinalConfirmation) {
                        Button("Reset Hive", role: .destructive) {
                            model.resetHive()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This cannot be undone. A backup of Hive.sqlite will be saved before reset.")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Development")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Local")
                    Link("Documentation", destination: URL(string: "https://developer.apple.com/design/human-interface-guidelines/")!)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(HiveColorToken.backgroundDeep.color)
            .navigationTitle("Hive Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onClose()
                    } label: {
                        HStack(spacing: HiveSpacing.sm) {
                            HiveSymbol(.confirmed, size: 14, active: true)
                            Text("Done")
                        }
                    }
                }
            }
        }
        .tint(HiveColorToken.waxAmber.color)
        .onAppear(perform: refreshAutomationReadiness)
        .onChange(of: morningBriefingEnabled) { _, _ in persistAutomationSchedule() }
        .onChange(of: morningBriefingHour) { _, _ in persistAutomationSchedule() }
        .onChange(of: morningBriefingMinute) { _, _ in persistAutomationSchedule() }
    }

    private static func hourLabel(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let date = Calendar.current.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private func persistAutomationSchedule() {
        var settings = HiveAutomationSettingsStore.load()
        if morningBriefingEnabled {
            settings.enabledKinds.insert(.morningBriefing)
        } else {
            settings.enabledKinds.remove(.morningBriefing)
        }
        settings.morningBriefingHour = morningBriefingHour
        settings.morningBriefingMinute = morningBriefingMinute
        HiveAutomationSettingsStore.save(settings)
        refreshAutomationReadiness()
    }

    private func refreshAutomationReadiness() {
        automationReadiness = HiveAutomationReadinessReport.current()
    }

    private func formattedAutomationDate(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = Calendar.current.isDateInToday(date) ? .none : .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func addCustomAutomationRequest() {
        let title = customAutomationGoal
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .prefix(5)
            .joined(separator: " ")
        let prompt = [
            HiveAutomationCatalog.template(for: .custom).promptTemplate,
            "Goal: \(customAutomationGoal)",
            "Sources: \(customAutomationSources)",
            "Frequency: \(customAutomationFrequency)",
            "Preferred time: \(customAutomationTime)",
            "Duration or stop rule: \(customAutomationDuration)",
            "Review policy: \(customAutomationCadence)",
            "Output: \(customAutomationOutput)",
            "Create this as an automation proposal first."
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "\n")
        var request = HiveStartupSourcePluginCatalog.load()
        request.prompt = prompt
        request.pasteLocation = ""
        var settings = HiveAutomationSettingsStore.load()
        settings.enabledKinds.insert(.custom)
        settings.customAutomations.insert(HiveCustomAutomationDefinition(
            title: title.isEmpty ? "Custom Automation" : title,
            goal: customAutomationGoal,
            sources: customAutomationSources,
            cadence: customAutomationCadence,
            frequency: customAutomationFrequency,
            preferredTime: customAutomationTime,
            duration: customAutomationDuration,
            output: customAutomationOutput
        ), at: 0)
        HiveAutomationSettingsStore.save(settings)
        model.configureStartupSourcePlugins(request)
        customAutomationVisible = false
        customAutomationGoal = ""
        customAutomationSources = ""
        customAutomationCadence = ""
        customAutomationFrequency = ""
        customAutomationTime = ""
        customAutomationDuration = ""
        customAutomationOutput = ""
        refreshAutomationReadiness()
    }
}

private struct HiveOnboardingOverlay: View {
    var onSkip: () -> Void
    var onPreviewStep: (HivePrimarySurface, Int) -> Void
    var onStart: (HiveStartupSourcePluginRequest) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var step = 0
    @State private var sourcePluginRequest = HiveStartupSourcePluginCatalog.load()

    private let steps = [
        OnboardingStep(
            title: "Connect what Hive may read",
            body: "Start with Google Drive, links, uploads, Downloads, local disk, or browser history. Hive gets more useful as you add more real sources, because it can connect and consolidate more of what matters. Privacy comes first: Hive waits for a pasted location or explicit capture before reading private material, uses on-device AI when available, and uses a cloud key only after you turn it on.",
            symbol: HiveSymbolName.sourcePlugins,
            surface: .rawInputs,
            actionTitle: "Show Field",
            showsSourcePlugins: true
        ),
        OnboardingStep(
            title: "Add something messy",
            body: "Fill the Field with real material you already have: saved articles, notes, screenshots, meeting transcripts, project docs, book highlights, podcast takeaways, bookmarks, or pasted research. Do not rename it. Do not clean it up. If you have nothing ready, talk to Hive for a few minutes about your work and goals, then save that as the first source.",
            symbol: HiveSymbolName.rawInputs,
            surface: .rawInputs,
            actionTitle: "Show Field"
        ),
        OnboardingStep(
            title: "Let Swarm run mornings",
            body: "Morning Briefing is on by default. Pick a time in Settings > Automations and Hive will gather approved new sources, process Field items from the last 24 hours, check open actions, update The Colony and The Hive, then write a Swarm-only briefing page.",
            symbol: HiveSymbolName.runMaintenance,
            surface: .swarm,
            actionTitle: "Show Swarm"
        ),
        OnboardingStep(
            title: "Read the organized version",
            body: "Hive turns Field sources into organized Colony articles and improves existing pages before making new ones.",
            symbol: HiveSymbolName.wiki,
            surface: .wiki,
            actionTitle: "Show The Colony"
        ),
        OnboardingStep(
            title: "Ask in context",
            body: "Select a Field item, Colony article, fact, or Hive cell. The first control is always an ask box for that exact thing.",
            symbol: HiveSymbolName.command,
            surface: .rawInputs,
            actionTitle: "Show ask box"
        ),
        OnboardingStep(
            title: "Open the map",
            body: "The Hive stays wordless until you need it. Hover to identify a cell, click to inspect, then jump into its Colony article.",
            symbol: HiveSymbolName.hiveGraph,
            surface: .graph,
            actionTitle: "Show The Hive"
        )
    ]

    var body: some View {
        ZStack {
            onboardingScrim
                .ignoresSafeArea()
            HiveHoneyBackdrop()
                .opacity(colorScheme == .dark ? 0.76 : 0.5)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            HiveText("Welcome to Hive", role: .nectarTitle)
                            HiveText("Add to the Field. Read The Colony. Open The Hive.", role: .scaffoldBody)
                        }
                        Spacer()
                        HiveSymbolButton(.close, title: "Skip", compact: true, action: onSkip)
                            .keyboardShortcut(.escape, modifiers: [])
                    }
                    HStack(alignment: .top, spacing: 18) {
                        HiveSymbol(current.symbol, size: 30, active: true, motion: .replace, motionValue: step)
                            .frame(width: 58, height: 58)
                            .background(HiveColorToken.waxAmber.color.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.surfaceCornerRadius, style: .continuous))
                        VStack(alignment: .leading, spacing: 10) {
                            HiveText("Step \(step + 1) of \(steps.count)", role: .scaffoldLabel)
                            HiveText(current.title, role: .nectarCardTitle)
                                .fixedSize(horizontal: false, vertical: true)
                            HiveText(current.body, role: .nectarBody, lineSpacing: 7)
                                .foregroundStyle(HiveColorToken.nectarMuted.color)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if current.showsSourcePlugins {
                        HiveStartupSourcePluginSetup(
                            selections: $sourcePluginRequest.selections,
                            pasteLocation: $sourcePluginRequest.pasteLocation,
                            prompt: $sourcePluginRequest.prompt,
                            compact: false
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    HStack(spacing: 8) {
                        ForEach(steps.indices, id: \.self) { index in
                            Button {
                                withAnimation(HiveMotion.panel) { step = index }
                            } label: {
                                Capsule()
                                    .fill(index == step ? HiveColorToken.waxAmber.color : HiveColorToken.scaffoldFaint.color.opacity(0.58))
                                    .frame(width: index == step ? 32 : 12, height: 7)
                                    .animation(HiveMotion.focus, value: step)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Show step \(index + 1): \(steps[index].title)")
                            .accessibilityHint("Moves the walkthrough to this step.")
                        }
                        Spacer()
                        if let surface = current.surface {
                            HiveSymbolButton(current.symbol, title: current.actionTitle, active: true, compact: true) {
                                onPreviewStep(surface, step)
                            }
                        }
                        if step > 0 {
                            HiveSymbolButton(.recenter, title: "Back", compact: true) {
                                withAnimation(HiveMotion.panel) { step -= 1 }
                            }
                        }
                        HiveSymbolButton(step == steps.count - 1 ? .confirmed : .showGraph, title: step == steps.count - 1 ? "Start Using Hive" : "Next", active: true, compact: true) {
                            withAnimation(HiveMotion.panel) {
                                if step == steps.count - 1 {
                                    onStart(HiveStartupSourcePluginCatalog.sanitizedRequest(sourcePluginRequest))
                                } else {
                                    step += 1
                                }
                            }
                        }
                        .keyboardShortcut(.return, modifiers: [])
                    }
                }
                .padding(30)
                .frame(maxWidth: 580)
                .modifier(HiveGlassShell(level: .modal))
                .shadow(color: HiveColorToken.backgroundDeep.color.opacity(0.28), radius: 28, x: 0, y: 18)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Hive walkthrough, step \(step + 1) of \(steps.count): \(current.title)")
                HiveText("Optional. Replay this anytime from Help > Hive Tutorial.", role: .scaffoldLabel)
                    .foregroundStyle(HiveColorToken.scaffoldGray.color)
                    .frame(maxWidth: 580, alignment: .center)
            }
            .padding(.horizontal, 18)
        }
        .onAppear {
            if let surface = current.surface {
                onPreviewStep(surface, step)
            }
        }
        .onChange(of: step) { _, _ in
            if let surface = current.surface {
                onPreviewStep(surface, step)
            }
        }
    }

    private var current: OnboardingStep {
        steps[min(max(step, 0), steps.count - 1)]
    }

    private var onboardingScrim: Color {
        colorScheme == .dark
            ? HiveColorToken.backgroundDeep.color.opacity(0.52)
            : HiveColorToken.backgroundDeep.color.opacity(0.14)
    }
}

private struct OnboardingStep {
    var title: String
    var body: String
    var symbol: HiveSymbolName
    var surface: HivePrimarySurface?
    var actionTitle: String
    var showsSourcePlugins: Bool = false
}

private struct HiveDailyUseTipsOverlay: View {
    var onUseTemplate: (String) -> Void
    var onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private let cards = DailyUseTipCard.all

    var body: some View {
        ZStack {
            (colorScheme == .dark ? HiveColorToken.backgroundDeep.color.opacity(0.5) : HiveColorToken.backgroundDeep.color.opacity(0.14))
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    HiveSymbol(.synthesizing, size: 30, active: true, motion: .pulse, motionValue: cards.count)
                        .frame(width: 58, height: 58)
                        .background(HiveColorToken.waxAmber.color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.surfaceCornerRadius, style: .continuous))
                    VStack(alignment: .leading, spacing: 7) {
                        HiveText("Use Hive every day", role: .nectarTitle)
                        HiveText("The loop is simple: add new sources, ask The Colony questions, then let Hive check its own work.", role: .nectarBody, lineSpacing: 6)
                            .foregroundStyle(HiveColorToken.nectarMuted.color)
                    }
                    Spacer()
                    HiveSymbolButton(.close, title: nil, compact: true, action: onDismiss)
                        .keyboardShortcut(.escape, modifiers: [])
                }

                VStack(spacing: 10) {
                    ForEach(cards) { card in
                        DailyUseTipRow(card: card) {
                            onUseTemplate(card.template)
                        }
                    }
                }

                HStack(spacing: 10) {
                    HiveSymbolButton(.chat, title: "What do you recommend?", active: true, compact: true) {
                        onUseTemplate(Self.recommendationTemplate)
                    }
                    Spacer()
                    HiveSymbolButton(.confirmed, title: "Done", compact: true, action: onDismiss)
                }
            }
            .padding(26)
            .frame(maxWidth: 680)
            .modifier(HiveGlassShell(level: .modal))
            .shadow(color: HiveColorToken.backgroundDeep.color.opacity(0.28), radius: 28, x: 0, y: 18)
        }
        .padding(.horizontal, 18)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Hive daily-use tips")
    }

    private static let recommendationTemplate = "What do you recommend I do next in Hive based on The Colony and my recent Field sources?"
}

private struct DailyUseTipCard: Identifiable {
    var id: String { title }
    var title: String
    var body: String
    var template: String
    var symbol: HiveSymbolName

    static let all: [DailyUseTipCard] = [
        DailyUseTipCard(
            title: "Ingest new sources",
            body: "Drop or clip one article, note, screenshot, transcript, bookmark, or document into Field. Hive should fold it into existing Colony pages before creating new ones.",
            template: "I just added a source to Field. Read it, extract the key ideas, update existing Colony articles before creating new ones, refresh The Colony index and log, flag contradictions, and show me what changed.",
            symbol: .rawInputs
        ),
        DailyUseTipCard(
            title: "Ask The Colony",
            body: "Once The Colony has a few real articles, ask synthesis questions. Save useful answers back into The Colony so each question improves the next one.",
            template: "Based only on The Colony, what are the three biggest gaps in my understanding right now? Give me the answer with the Colony entries you used, and tell me which answer is worth saving back into The Colony.",
            symbol: .chat
        ),
        DailyUseTipCard(
            title: "Run a health check",
            body: "Use this as quality control. Hive should find contradictions, orphans, repeated concepts without pages, and claims that may be outdated.",
            template: "Review The Colony. Find contradictions between pages, orphan pages with no inbound links, repeated concepts with no dedicated page, and claims that seem outdated based on newer Field sources. Write a temporary health report and propose fixes.",
            symbol: .runMaintenance
        )
    ]
}

private struct DailyUseTipRow: View {
    var card: DailyUseTipCard
    var onUseTemplate: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HiveSymbol(card.symbol, size: 20, active: true)
                .frame(width: 36, height: 36)
                .background(HiveColorToken.waxAmber.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.controlCornerRadius, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                HiveText(card.title, role: .nectarCardTitle)
                HiveText(card.body, role: .scaffoldBody, lineSpacing: 5)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                HiveText(card.template, role: .scaffoldLabel, lineSpacing: 4)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(HiveColorToken.raisedSurface.color.opacity(0.42), in: RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
            }
            HiveSymbolButton(.send, title: "Use template", active: true, compact: true, action: onUseTemplate)
        }
        .padding(12)
        .background(HiveColorToken.cellSurface.color.opacity(0.52), in: RoundedRectangle(cornerRadius: HiveLayoutMetrics.surfaceCornerRadius, style: .continuous))
    }
}

public struct HiveMenuBarPopover: View {
    @EnvironmentObject private var model: HiveAppModel
    private let onImportDocuments: () -> Void
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void

    public init(
        onImportDocuments: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onImportDocuments = onImportDocuments
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MenuBarHeaderView(
                claimCount: model.claims.count,
                sourceCount: model.visibleSources.count,
                captureState: captureStateLabel
            )
            MenuBarActionRow(symbol: .importAction, title: "Import Docs", detail: "Choose documents, files, or folders for Field.", active: true, action: onImportDocuments)
            MenuBarActionRow(symbol: .settings, title: "Settings", detail: "Open Hive settings.", active: false, action: onOpenSettings)
            Rectangle()
                .fill(HiveColorToken.scaffoldFaint.color.opacity(0.22))
                .frame(height: 1)
                .padding(.vertical, 2)
            MenuBarActionRow(symbol: .signOut, title: "Quit Hive", detail: "Quit the Hive app.", active: false, destructive: true, action: onQuit)
            MenuBarFooterView(captureState: captureStateLabel)
        }
        .padding(8)
        .frame(width: 268)
        .foregroundStyle(HiveColorToken.nectarText.color)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.xl, style: .continuous)
                .fill(menuBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.xl, style: .continuous)
                .stroke(HiveColorToken.waxAmber.color.opacity(0.08), lineWidth: 0.6)
        )
        .overlay(HiveGrainLayer().allowsHitTesting(false).opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: HiveRadius.xl, style: .continuous))
        .shadow(color: HiveColorToken.backgroundDeep.color.opacity(0.34), radius: 18, x: 0, y: 10)
    }

    private var menuBackground: Color {
        HiveColorToken.backgroundDeep.color
    }

    private var captureStateLabel: String {
        if model.isWorking {
            return "Capturing"
        }
        let queued = model.visibleSources.filter { $0.status == .queued }.count
        if queued > 0 {
            return "Queued \(queued)"
        }
        return "Idle"
    }
}

private struct MenuBarHeaderView: View {
    var claimCount: Int
    var sourceCount: Int
    var captureState: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HiveText("Hive", role: .scaffoldLabel)
                Spacer()
                HiveText(captureState, role: .scaffoldBody)
                    .foregroundStyle(HiveColorToken.waxAmber.color)
            }
            HStack(spacing: 8) {
                capsule("Claims", value: claimCount)
                capsule("Field", value: sourceCount)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private func capsule(_ title: String, value: Int) -> some View {
        HStack(spacing: 4) {
            HiveText(title, role: .scaffoldBody)
            HiveText("\(value)", role: .scaffoldLabel)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(HiveColorToken.raisedSurface.color.opacity(0.6), in: Capsule())
    }
}

private struct MenuBarFooterView: View {
    var captureState: String

    var body: some View {
        HStack(spacing: 8) {
            HiveSymbol(.status, size: 11, active: true, rendering: .monochrome(HiveColorToken.waxAmber.color))
            HiveText("Capture state: \(captureState)", role: .scaffoldBody)
                .foregroundStyle(HiveColorToken.nectarMuted.color)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
}

private struct MenuBarActionRow: View {
    var symbol: HiveSymbolName
    var title: String
    var detail: String
    var active: Bool
    var destructive: Bool = false
    var action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                HiveSymbol(symbol, size: 18, active: active, rendering: .monochrome(iconColor))
                    .frame(width: 28, height: 28)
                HiveText(title, role: .scaffoldAction)
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(height: 38)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: HiveRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: HiveRadius.lg, style: .continuous))
        .onHover { value in
            withAnimation(HiveMotion.focus) { hovered = value }
        }
        .help(detail)
    }

    private var iconColor: Color {
        destructive ? HiveColorToken.conflict.color : (active ? HiveColorToken.waxAmberBright.color : HiveColorToken.nectarMuted.color)
    }

    private var titleColor: Color {
        destructive ? HiveColorToken.conflict.color : HiveColorToken.nectarText.color
    }

    private var rowBackground: Color {
        if hovered { return HiveColorToken.waxAmber.color.opacity(0.16) }
        return active ? HiveColorToken.waxAmber.color.opacity(0.08) : Color.clear
    }

}

private struct SourceInspector: View {
    var source: SourceRecord
    var presentation: SourcePresentationModel
    var onAsk: (String) -> Void
    var onArchive: () -> Void
    var onForget: () -> Void
    var onClose: () -> Void
    @State private var trailOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Spacer()
                HiveText(presentation.relativeAge, role: .scaffoldBody)
                HiveSymbolButton(.close, title: nil, compact: true, action: onClose)
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .overlay(alignment: .topTrailing) {
                HiveSymbol(.localOnly, size: 10, rendering: .monochrome(HiveColorToken.scaffoldFaint.color))
                    .help("Stored on this device")
                    .padding(.trailing, 44)
            }
            HiveText(presentation.title, role: .nectarTitle, lineSpacing: 10)
                .lineLimit(4)
                .minimumScaleFactor(0.78)
            if let preview = presentation.attachmentPreview {
                SourceAttachmentPreviewPanel(preview: preview)
            }
            HiveText(summaryText, role: .nectarBody, lineSpacing: 8)
                .foregroundStyle(HiveColorToken.nectarMuted.color)
            HiveContextAskSurface(
                title: "Ask about this Field item",
                placeholder: "Ask what it adds or whether it matters"
            ) { question in
                onAsk(question)
            }
            Spacer()
            VStack(spacing: 10) {
                inspectorAction(trailOpen ? "Hide details" : "Show details", symbol: .explain, active: trailOpen) {
                    withAnimation(HiveMotion.standard) {
                        trailOpen.toggle()
                    }
                }
                if trailOpen {
                    HiveText("Hive reads this only when you inspect the source trail.", role: .scaffoldBody)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                inspectorAction("Archive", symbol: .archive, action: onArchive)
                inspectorAction("Forget Item", symbol: .forget, active: false, action: onForget)
            }
        }
        .padding(20)
        .background(HiveColorToken.backgroundMid.color)
    }

    private func inspectorAction(
        _ title: String,
        symbol: HiveSymbolName,
        active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        HiveSymbolButton(
            symbol,
            title: title,
            active: active,
            motion: active ? .pulse : .none,
            motionValue: active ? 1 : 0,
            action: action
        )
    }

    private var summaryText: String {
        let trimmed = presentation.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No summary yet" : trimmed
    }
}

private struct SourceAttachmentPreviewPanel: View {
    var preview: SourceAttachmentPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                SourceAttachmentPreviewArtwork(preview: preview, width: 88, height: 68)
                VStack(alignment: .leading, spacing: 6) {
                    HiveText(preview.kindLabel, role: .scaffoldLabel)
                    HiveText(preview.displayName, role: .nectarCardTitle, lineSpacing: 5)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .help(preview.displayName)
                    HiveText(preview.detailLine, role: .scaffoldBody)
                        .foregroundStyle(HiveColorToken.scaffoldGray.color)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            if let snippet = preview.extractedSnippet {
                Divider()
                HiveText(snippet, role: .nectarBody, lineSpacing: 6)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .lineLimit(4)
            }
        }
        .padding(14)
        .background(HiveColorToken.cellSurface.color.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(preview.kindLabel) \(preview.displayName). \(preview.detailLine)")
    }
}

private struct RawSourcePreviewSheet: View {
    var preview: RawSourcePreview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HiveSpacing.lg) {
                    HStack(spacing: HiveSpacing.sm) {
                        HiveSymbol(.rawSourcesSheet, size: 18, active: true)
                        HiveText(preview.kindLabel.capitalized, role: .scaffoldLabel)
                        Spacer()
                        if let localPath = preview.localPath {
                            HiveText(URL(fileURLWithPath: localPath).lastPathComponent, role: .scaffoldBody)
                                .foregroundStyle(HiveColorToken.nectarMuted.color)
                                .lineLimit(1)
                        }
                    }
                    Text(preview.text)
                        .font(HiveTypography.hiveBody)
                        .foregroundStyle(HiveColorToken.nectarText.color)
                        .textSelection(.enabled)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(HiveSpacing.xl)
            }
            .navigationTitle(preview.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct ProcessingResultView: View {
    var result: ProcessingResultSummary
    var onOpenColony: () -> Void
    var onOpenHive: () -> Void
    var onRetry: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HiveSpacing.xl) {
                    if result.learned.isEmpty && result.colonyChanges.isEmpty {
                        emptyResult
                    } else {
                        if !result.learned.isEmpty {
                            resultSection("Added to The Hive", symbol: .hiveGraph) {
                                ForEach(result.learned) { node in
                                    HStack {
                                        HiveText(node.title, role: .nectarBody)
                                            .lineLimit(2)
                                        Spacer()
                                        HiveText(String(format: "(%.2f, %.2f)", node.x, node.y), role: .scaffoldLabel)
                                    }
                                }
                                HiveActionButton("View in Hive", symbol: .showGraph, action: onOpenHive)
                            }
                        }
                        if !result.colonyChanges.isEmpty {
                            resultSection("Updated Colony", symbol: .wiki) {
                                ForEach(result.colonyChanges) { change in
                                    HStack {
                                        HiveText(change.title, role: .nectarBody)
                                            .lineLimit(2)
                                        Spacer()
                                        HiveText("+\(change.newClaimCount)", role: .scaffoldLabel)
                                            .foregroundStyle(HiveColorToken.waxAmber.color)
                                    }
                                }
                                HiveActionButton("View in Colony", symbol: .openWiki, action: onOpenColony)
                            }
                        }
                    }
                    resultSection("Skipped (low signal)", symbol: .conflict) {
                        ForEach(result.skipped) { skipped in
                            VStack(alignment: .leading, spacing: 4) {
                                HiveText(skipped.text, role: .nectarBody)
                                HiveText(skipped.reason, role: .scaffoldBody)
                                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                            }
                        }
                    }
                }
                .padding(HiveSpacing.xl)
            }
            .navigationTitle("\(result.learnedCount) things learned from \(result.sourceName)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                dismiss()
            }
        }
    }

    private var emptyResult: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            HiveSymbol(.runMaintenance, size: 22, active: true)
            HiveText("Nothing new was extracted.", role: .nectarTitle)
            HiveText("The source may already be represented in your knowledge base, or the content may not have met the signal threshold.", role: .nectarBody, lineSpacing: 6)
                .foregroundStyle(HiveColorToken.nectarMuted.color)
            HiveActionButton("Re-process", symbol: .runMaintenance, action: onRetry)
        }
        .padding(HiveSpacing.lg)
        .background(HiveColorToken.cellSurface.color.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: HiveRadius.lg, style: .continuous))
    }

    private func resultSection<Content: View>(
        _ title: String,
        symbol: HiveSymbolName,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            HStack(spacing: HiveSpacing.sm) {
                HiveSymbol(symbol, size: 16, active: true)
                HiveText(title, role: .scaffoldLabel)
            }
            VStack(alignment: .leading, spacing: HiveSpacing.sm) {
                content()
            }
        }
        .padding(HiveSpacing.lg)
        .background(HiveColorToken.cellSurface.color.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: HiveRadius.lg, style: .continuous))
    }
}
