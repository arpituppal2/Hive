import SwiftUI
import HiveCore
import HiveDesignSystem
import HiveMacApp
import HiveUI
import AppKit
import Carbon

@MainActor
private final class HiveAppPreferences: ObservableObject {
    @Published private(set) var sidebarVisible: Bool
    @Published private(set) var menuBarExtraVisible: Bool
    @Published private(set) var menuBarQuickCaptureEnabled: Bool
    @Published private(set) var shortcutRevision = 0

    private let defaults: UserDefaults
    private var observer: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sidebarVisible = Self.defaultBool("hive.sidebarVisible", fallback: true, defaults: defaults)
        menuBarExtraVisible = Self.defaultBool("hive.menuBarExtraVisible", fallback: true, defaults: defaults)
        menuBarQuickCaptureEnabled = Self.defaultBool("hive.menuBarQuickCaptureEnabled", fallback: true, defaults: defaults)
        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: defaults,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshFromDefaults()
            }
        }
    }

    func setSidebarVisible(_ visible: Bool) {
        guard sidebarVisible != visible else { return }
        sidebarVisible = visible
        defaults.set(visible, forKey: "hive.sidebarVisible")
    }

    func setMenuBarExtraVisible(_ visible: Bool) {
        guard menuBarExtraVisible != visible else { return }
        menuBarExtraVisible = visible
        defaults.set(visible, forKey: "hive.menuBarExtraVisible")
    }

    private func refreshFromDefaults() {
        let nextSidebarVisible = Self.defaultBool("hive.sidebarVisible", fallback: true, defaults: defaults)
        let nextMenuBarExtraVisible = Self.defaultBool("hive.menuBarExtraVisible", fallback: true, defaults: defaults)
        let nextQuickCaptureEnabled = Self.defaultBool("hive.menuBarQuickCaptureEnabled", fallback: true, defaults: defaults)
        shortcutRevision += 1
        if sidebarVisible != nextSidebarVisible {
            sidebarVisible = nextSidebarVisible
        }
        if menuBarExtraVisible != nextMenuBarExtraVisible {
            menuBarExtraVisible = nextMenuBarExtraVisible
        }
        if menuBarQuickCaptureEnabled != nextQuickCaptureEnabled {
            menuBarQuickCaptureEnabled = nextQuickCaptureEnabled
        }
    }

    private static func defaultBool(_ key: String, fallback: Bool, defaults: UserDefaults) -> Bool {
        defaults.object(forKey: key) as? Bool ?? fallback
    }
}

private struct HiveSettingsWindowContent: View {
    @EnvironmentObject private var model: HiveAppModel
    @AppStorage("hive.appearanceMode") private var appearanceModeRaw = HiveAppearanceMode.system.rawValue
    @AppStorage("hive.menuBarExtraVisible") private var menuBarExtraVisible = true
    @AppStorage("hive.menuBarQuickCaptureEnabled") private var menuBarQuickCaptureEnabled = true

    var body: some View {
        Group {
            if !model.isAppleAuthenticated {
                HiveAppleLoginGate(
                    onAuthenticated: {
                        model.validateAppleCredentialState()
                    },
                    onContinueAsGuest: {
                        model.continueAsGuestForNow()
                    }
                )
                .frame(minWidth: 520, minHeight: 520)
                .tint(HiveColorToken.waxAmber.color)
            } else {
                HiveSettingsSurface(
                    attachmentPathDescription: "Saved article images stay available locally, even if the original page changes.",
                    sourcePluginStatusText: model.sourcePluginStatusText,
                    learningSettings: Binding(
                        get: { model.learningSettings },
                        set: { model.updateLearningSettings($0) }
                    ),
                    appearanceMode: $appearanceModeRaw,
                    menuBarExtraVisible: $menuBarExtraVisible,
                    menuBarQuickCaptureEnabled: $menuBarQuickCaptureEnabled,
                    onReplayTutorial: {
                        UserDefaults.standard.set(false, forKey: "hive.hasSeenOnboarding")
                        NSApp.activate(ignoringOtherApps: true)
                    },
                    onRunMorningBriefing: {
                        model.runMorningBriefingNow()
                        NSApp.activate(ignoringOtherApps: true)
                    },
                    onConfigureSourcePlugins: { request in
                        model.configureStartupSourcePlugins(request)
                    },
                    onChooseSourcePluginFiles: { request in
                        openSourcePluginImportPanel(request)
                    },
                    onChooseBrowserHistory: { request in
                        openBrowserHistoryImportPanel(request)
                    },
                    onConfirmAxesAndReindex: { _ in
                        model.requestHiveReindex()
                        NSApp.activate(ignoringOtherApps: true)
                        NSApp.keyWindow?.close()
                    },
                    onAppleAccountChanged: { account in
                        if account == nil {
                            model.signOutAppleAccount()
                            HiveMacWindowPresenter.showMainWindow()
                            NSApp.keyWindow?.close()
                        } else {
                            model.validateAppleCredentialState()
                        }
                    },
                    commandAvailability: { command in
                        model.commandAvailability(for: command)
                    },
                    onCommand: { command in
                        model.executeCommand(command)
                        NSApp.activate(ignoringOtherApps: true)
                    },
                    onClose: {
                        NSApp.keyWindow?.close()
                    }
                )
                .frame(
                    minWidth: HiveLayoutMetrics.settingsWindowMinWidth,
                    idealWidth: HiveLayoutMetrics.settingsWindowIdealWidth,
                    minHeight: HiveLayoutMetrics.settingsWindowMinHeight,
                    idealHeight: HiveLayoutMetrics.settingsWindowIdealHeight
                )
                .tint(HiveColorToken.waxAmber.color)
            }
        }
        .sheet(item: $model.firstLoginDataChoicePrompt) { prompt in
            HiveFirstLoginDataChoiceSheet(prompt: prompt) { choice in
                model.resolveFirstLoginDataChoice(choice)
            }
            .tint(HiveColorToken.waxAmber.color)
        }
    }

    private func openSourcePluginImportPanel(_ request: HiveStartupSourcePluginRequest) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = "Choose the files or folders Hive should add to Field."
        panel.begin { response in
            if response == .OK {
                model.configureStartupSourcePlugins(request, uploadedURLs: panel.urls)
            }
        }
    }

    private func openBrowserHistoryImportPanel(_ request: HiveStartupSourcePluginRequest) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = "Choose a browser profile folder or History file so Hive can import it with your permission."
        panel.begin { response in
            if response == .OK {
                model.configureStartupSourcePlugins(request, browserHistoryURLs: panel.urls)
            }
        }
    }
}

@MainActor
private final class HiveLiveHotKeyController: ObservableObject {
    private weak var model: HiveAppModel?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func install(model: HiveAppModel) {
        self.model = model
        unregister()
        guard let shortcut = HiveKeyboardShortcut.parse(HiveCommandShortcutStore.shortcut(for: .live)),
              let keyCode = Self.keyCode(for: shortcut.key) else {
            return
        }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let pointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let controller = Unmanaged<HiveLiveHotKeyController>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    controller.openLive()
                }
                return noErr
            },
            1,
            &eventType,
            pointer,
            &eventHandler
        )
        guard installStatus == noErr else {
            eventHandler = nil
            return
        }
        let hotKeyID = EventHotKeyID(signature: Self.fourCharCode("HvLv"), id: 1)
        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode),
            Self.modifierFlags(for: shortcut.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if registerStatus != noErr {
            unregister()
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func openLive() {
        guard let model else { return }
        guard model.isAppleAuthenticated else {
            _ = model.refreshAppleAuthentication()
            HiveMacWindowPresenter.showMainWindow()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        model.openLiveAssistant()
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func modifierFlags(for modifiers: Set<HiveShortcutModifier>) -> UInt32 {
        var flags: UInt32 = 0
        if modifiers.contains(.command) { flags |= UInt32(cmdKey) }
        if modifiers.contains(.option) { flags |= UInt32(optionKey) }
        if modifiers.contains(.shift) { flags |= UInt32(shiftKey) }
        if modifiers.contains(.control) { flags |= UInt32(controlKey) }
        return flags
    }

    private static func keyCode(for key: String) -> Int? {
        switch key.uppercased() {
        case "A": return kVK_ANSI_A
        case "B": return kVK_ANSI_B
        case "C": return kVK_ANSI_C
        case "D": return kVK_ANSI_D
        case "E": return kVK_ANSI_E
        case "F": return kVK_ANSI_F
        case "G": return kVK_ANSI_G
        case "H": return kVK_ANSI_H
        case "I": return kVK_ANSI_I
        case "J": return kVK_ANSI_J
        case "K": return kVK_ANSI_K
        case "L": return kVK_ANSI_L
        case "M": return kVK_ANSI_M
        case "N": return kVK_ANSI_N
        case "O": return kVK_ANSI_O
        case "P": return kVK_ANSI_P
        case "Q": return kVK_ANSI_Q
        case "R": return kVK_ANSI_R
        case "S": return kVK_ANSI_S
        case "T": return kVK_ANSI_T
        case "U": return kVK_ANSI_U
        case "V": return kVK_ANSI_V
        case "W": return kVK_ANSI_W
        case "X": return kVK_ANSI_X
        case "Y": return kVK_ANSI_Y
        case "Z": return kVK_ANSI_Z
        case "0": return kVK_ANSI_0
        case "1": return kVK_ANSI_1
        case "2": return kVK_ANSI_2
        case "3": return kVK_ANSI_3
        case "4": return kVK_ANSI_4
        case "5": return kVK_ANSI_5
        case "6": return kVK_ANSI_6
        case "7": return kVK_ANSI_7
        case "8": return kVK_ANSI_8
        case "9": return kVK_ANSI_9
        case "COMMA": return kVK_ANSI_Comma
        case "SPACE": return kVK_Space
        case "RETURN": return kVK_Return
        case "ESCAPE": return kVK_Escape
        case "DELETE": return kVK_Delete
        default: return nil
        }
    }

    private static func fourCharCode(_ value: String) -> OSType {
        value.utf8.prefix(4).reduce(0) { partial, byte in
            (partial << 8) + OSType(byte)
        }
    }
}

private struct HiveLiveHotKeyBootstrap: View {
    @ObservedObject var controller: HiveLiveHotKeyController
    @ObservedObject var model: HiveAppModel
    var shortcutRevision: Int

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                controller.install(model: model)
            }
            .onChange(of: shortcutRevision) { _, _ in
                controller.install(model: model)
            }
            .accessibilityHidden(true)
    }
}

@MainActor
private final class SwarmQuickChatPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class SwarmQuickChatWindowController: NSObject, ObservableObject, NSWindowDelegate {
    private weak var model: HiveAppModel?
    private var panel: SwarmQuickChatPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private var isShowingFilePanel = false

    deinit {
        MainActor.assumeIsolated {
            removeOutsideDismissMonitors()
        }
    }

    func install(model: HiveAppModel) {
        self.model = model
        updateRootView()
    }

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let model else { return }
        guard model.isAppleAuthenticated else {
            _ = model.refreshAppleAuthentication()
            HiveMacWindowPresenter.showMainWindow()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        model.prepareQuickSwarmPopup()
        if panel == nil {
            makePanel()
        }
        updateRootView()
        guard let panel else { return }
        let finalFrame = targetFrame()
        let startFrame = finalFrame.offsetBy(dx: 0, dy: -18)
        panel.setFrame(startFrame, display: false)
        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKey()
        installOutsideDismissMonitors()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(finalFrame, display: true)
        }
    }

    func hide(markDismissed: Bool = true) {
        guard let panel, panel.isVisible else { return }
        removeOutsideDismissMonitors()
        if markDismissed {
            model?.markQuickSwarmPopupDismissed()
        }
        let hiddenFrame = panel.frame.offsetBy(dx: 0, dy: -14)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(hiddenFrame, display: true)
        } completionHandler: { [weak self, weak panel] in
            Task { @MainActor in
                guard let self, let panel else { return }
                panel.orderOut(nil)
                panel.alphaValue = 1
                panel.setFrame(self.targetFrame(), display: false)
            }
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !isShowingFilePanel else { return }
        hide()
    }

    private func makePanel() {
        let panel = SwarmQuickChatPanel(
            contentRect: targetFrame(),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        let hostingView = NSHostingView(rootView: rootView())
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        self.panel = panel
        self.hostingView = hostingView
    }

    private func rootView() -> AnyView {
        guard let model else {
            return AnyView(EmptyView())
        }
        return AnyView(
            SwarmQuickChatSurface(
                model: model,
                onAttach: { [weak self] in self?.openAttachmentPanel() },
                onOpenHive: { [weak self] in self?.openHive() },
                onDismiss: { [weak self] in self?.hide() }
            )
            .tint(HiveColorToken.waxAmber.color)
        )
    }

    private func updateRootView() {
        hostingView?.rootView = rootView()
    }

    private func openHive() {
        model?.openCurrentSwarmConversationInHive()
        hide(markDismissed: false)
        HiveMacWindowPresenter.showMainWindow()
    }

    private func openAttachmentPanel() {
        guard let model else { return }
        isShowingFilePanel = true
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.message = "Choose files to attach to this Swarm question."
        openPanel.begin { [weak self, weak model] response in
            Task { @MainActor in
                guard let self else { return }
                self.isShowingFilePanel = false
                if response == .OK {
                    model?.addSwarmAttachmentURLs(openPanel.urls)
                }
                self.panel?.makeKey()
            }
        }
    }

    private func targetFrame() -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 820)
        let width = min(748, max(520, visibleFrame.width - 80))
        let height = min(424, max(344, visibleFrame.height * 0.46))
        let x = visibleFrame.midX - width / 2
        let y = visibleFrame.minY + max(34, visibleFrame.height * 0.10)
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func installOutsideDismissMonitors() {
        removeOutsideDismissMonitors()
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            if event.window !== self.panel {
                self.hide()
            }
            return event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }
    }

    private func removeOutsideDismissMonitors() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }
}

@MainActor
private final class SwarmQuickChatHotKeyController: ObservableObject {
    private weak var windowController: SwarmQuickChatWindowController?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var bothOptionKeysAreDown = false
    private var lastTriggerDate = Date.distantPast

    deinit {
        MainActor.assumeIsolated {
            unregister()
        }
    }

    func install(windowController: SwarmQuickChatWindowController) {
        self.windowController = windowController
        unregister()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged()
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] _ in
            Task { @MainActor in
                self?.handleFlagsChanged()
            }
        }
    }

    func unregister() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        bothOptionKeysAreDown = false
    }

    private func handleFlagsChanged() {
        let bothDown = Self.bothOptionKeysPressed()
        defer { bothOptionKeysAreDown = bothDown }
        guard bothDown, !bothOptionKeysAreDown else { return }
        let now = Date()
        guard now.timeIntervalSince(lastTriggerDate) > 0.36 else { return }
        lastTriggerDate = now
        windowController?.toggle()
    }

    private static func bothOptionKeysPressed() -> Bool {
        CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(kVK_Option))
            && CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(kVK_RightOption))
    }
}

private enum HiveShiftCapturePhase: Equatable {
    case idle
    case capturing
    case flying
    case confirming
    case sent
    case failed(String)
}

@MainActor
private final class HiveShiftCaptureHotKeyController: ObservableObject {
    @Published fileprivate var phase: HiveShiftCapturePhase = .idle
    @Published fileprivate var screenshotURL: URL?

    private weak var model: HiveAppModel?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var bothShiftKeysAreDown = false
    private var lastTriggerDate = Date.distantPast
    private var panel: NSPanel?
    private var hostingView: NSHostingView<HiveShiftCaptureOverlayView>?

    deinit {
        MainActor.assumeIsolated {
            unregister()
        }
    }

    func install(model: HiveAppModel) {
        self.model = model
        unregister()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged()
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] _ in
            Task { @MainActor in
                self?.handleFlagsChanged()
            }
        }
    }

    func unregister() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        bothShiftKeysAreDown = false
    }

    func confirmSend() {
        guard let model else {
            dismiss()
            return
        }
        guard let screenshotURL else {
            phase = .failed("Screenshot was not captured.")
            return
        }
        model.selectedSurface = .rawInputs
        model.ingest(urls: [screenshotURL])
        withAnimation(HiveMotion.stamp) {
            phase = .sent
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.dismiss()
        }
    }

    func dismiss() {
        guard let panel else {
            phase = .idle
            screenshotURL = nil
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self, weak panel] in
            Task { @MainActor in
                panel?.orderOut(nil)
                panel?.alphaValue = 1
                self?.phase = .idle
                self?.screenshotURL = nil
            }
        }
    }

    private func handleFlagsChanged() {
        let bothDown = Self.bothShiftKeysPressed()
        defer { bothShiftKeysAreDown = bothDown }
        guard bothDown, !bothShiftKeysAreDown else { return }
        let now = Date()
        guard now.timeIntervalSince(lastTriggerDate) > 0.45 else { return }
        lastTriggerDate = now
        beginCaptureFlow()
    }

    private func beginCaptureFlow() {
        guard let model else { return }
        guard model.isAppleAuthenticated else {
            _ = model.refreshAppleAuthentication()
            HiveMacWindowPresenter.showMainWindow()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        guard phase == .idle else { return }
        screenshotURL = nil
        phase = .capturing
        showPanel()
        let targetURL = makeScreenshotTargetURL(model: model)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try Self.captureScreenshot(to: targetURL) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch result {
                case .success(let url):
                    self.screenshotURL = url
                    withAnimation(HiveMotion.panel) {
                        self.phase = .flying
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) { [weak self] in
                        guard let self, self.phase == .flying else { return }
                        withAnimation(HiveMotion.panel) {
                            self.phase = .confirming
                        }
                    }
                case .failure(let error):
                    withAnimation(HiveMotion.panel) {
                        self.phase = .failed(error.localizedDescription)
                    }
                }
            }
        }
    }

    private func showPanel() {
        if panel == nil {
            makePanel()
        }
        updateRootView()
        guard let panel else { return }
        let frame = targetFrame()
        panel.setFrame(frame, display: false)
        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    private func makePanel() {
        let panel = SwarmQuickChatPanel(
            contentRect: targetFrame(),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        let hostingView = NSHostingView(rootView: HiveShiftCaptureOverlayView(controller: self))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        self.panel = panel
        self.hostingView = hostingView
    }

    private func updateRootView() {
        hostingView?.rootView = HiveShiftCaptureOverlayView(controller: self)
    }

    private func targetFrame() -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        return screen?.frame ?? NSRect(x: 0, y: 0, width: 1200, height: 820)
    }

    private func makeScreenshotTargetURL(model: HiveAppModel) -> URL {
        let directory = model.paths.artifacts.appendingPathComponent("Quick Captures", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "shift-capture-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(8)).png"
        return directory.appendingPathComponent(name)
    }

    nonisolated private static func captureScreenshot(to targetURL: URL) throws -> URL {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", targetURL.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              FileManager.default.fileExists(atPath: targetURL.path) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return targetURL
    }

    private static func bothShiftKeysPressed() -> Bool {
        CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(kVK_Shift))
            && CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(kVK_RightShift))
    }
}

private struct HiveShiftCaptureOverlayView: View {
    @ObservedObject var controller: HiveShiftCaptureHotKeyController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                flashLayer
                thumbnail(in: proxy.size)
                if controller.phase == .confirming || controller.phase == .sent || isFailure {
                    confirmationCard
                        .padding(.top, 12)
                        .padding(.trailing, 18)
                        .transition(.scale(scale: 0.92, anchor: .topTrailing).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var flashLayer: some View {
        if controller.phase == .capturing {
            HiveColorToken.waxAmber.color
                .opacity(0.08)
                .overlay(
                    RoundedRectangle(cornerRadius: HiveRadius.xl, style: .continuous)
                        .stroke(HiveColorToken.waxAmberBright.color.opacity(0.26), lineWidth: 2)
                        .padding(10)
                )
                .transition(.opacity)
        } else {
            Color.clear
        }
    }

    private func thumbnail(in size: CGSize) -> some View {
        let isMenuPhase = controller.phase == .flying || controller.phase == .confirming || controller.phase == .sent || isFailure
        return thumbnailImage
            .frame(width: isMenuPhase ? 54 : 178, height: isMenuPhase ? 36 : 112)
            .clipShape(RoundedRectangle(cornerRadius: isMenuPhase ? HiveRadius.md : HiveRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: isMenuPhase ? HiveRadius.md : HiveRadius.lg, style: .continuous)
                    .stroke(HiveColorToken.waxAmber.color.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: HiveColorToken.waxAmber.color.opacity(0.18), radius: isMenuPhase ? 10 : 22, x: 0, y: isMenuPhase ? 5 : 14)
            .position(thumbnailPosition(in: size, menuPhase: isMenuPhase))
            .opacity(controller.phase == .idle ? 0 : 1)
            .animation(reduceMotion ? nil : HiveMotion.panel, value: controller.phase)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        if let url = controller.screenshotURL, let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: HiveRadius.lg, style: .continuous)
                .fill(HiveColorToken.raisedSurface.color)
                .overlay {
                    HiveSymbol(.screenshot, size: 32, active: true)
                }
        }
    }

    private func thumbnailPosition(in size: CGSize, menuPhase: Bool) -> CGPoint {
        if menuPhase {
            return CGPoint(x: max(36, size.width - 104), y: 32)
        }
        return CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private var confirmationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                HiveSymbol(statusSymbol, size: 18, active: true)
                    .frame(width: 28, height: 28)
                    .background(HiveColorToken.waxAmber.color.opacity(0.16), in: RoundedRectangle(cornerRadius: HiveRadius.md, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    HiveText(statusTitle, role: .scaffoldAction)
                    HiveText(statusDetail, role: .scaffoldLabel)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                }
            }
            if controller.phase == .confirming {
                HStack(spacing: 8) {
                    Button {
                        controller.dismiss()
                    } label: {
                        HiveText("Cancel", role: .scaffoldAction)
                            .frame(minWidth: 68)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 7)
                    .background(HiveColorToken.raisedSurface.color, in: RoundedRectangle(cornerRadius: HiveRadius.md, style: .continuous))

                    Button {
                        controller.confirmSend()
                    } label: {
                        HStack(spacing: 6) {
                            HiveSymbol(.send, size: 13, active: true)
                            HiveText("Send", role: .scaffoldAction)
                        }
                        .frame(minWidth: 74)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 7)
                    .background(HiveColorToken.waxAmber.color.opacity(0.24), in: RoundedRectangle(cornerRadius: HiveRadius.md, style: .continuous))
                }
            }
        }
        .padding(12)
        .frame(width: 258, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.xl, style: .continuous)
                .fill(HiveColorToken.backgroundDeep.color)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.xl, style: .continuous)
                .stroke(HiveColorToken.waxAmber.color.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: HiveColorToken.backgroundDeep.color.opacity(0.34), radius: 22, x: 0, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(statusTitle)
    }

    private var isFailure: Bool {
        if case .failed = controller.phase { return true }
        return false
    }

    private var statusSymbol: HiveSymbolName {
        switch controller.phase {
        case .sent:
            return .confirmed
        case .failed:
            return .conflict
        default:
            return .screenshot
        }
    }

    private var statusTitle: String {
        switch controller.phase {
        case .sent:
            return "Sent to Field"
        case .failed:
            return "Capture needs permission"
        default:
            return "Send screenshot to Field?"
        }
    }

    private var statusDetail: String {
        switch controller.phase {
        case .sent:
            return "Hive will process it with the next Field batch."
        case .failed(let message):
            return message
        default:
            return "Both Shift keys captured the screen."
        }
    }
}

private struct SwarmQuickChatBootstrap: View {
    @ObservedObject var windowController: SwarmQuickChatWindowController
    @ObservedObject var hotKeyController: SwarmQuickChatHotKeyController
    @ObservedObject var model: HiveAppModel

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                windowController.install(model: model)
                hotKeyController.install(windowController: windowController)
            }
            .accessibilityHidden(true)
    }
}

private struct HiveShiftCaptureBootstrap: View {
    @ObservedObject var controller: HiveShiftCaptureHotKeyController
    @ObservedObject var model: HiveAppModel

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                controller.install(model: model)
            }
            .accessibilityHidden(true)
    }
}

@MainActor
private final class HiveAppLifecycleDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        .terminateNow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        HiveMacWindowPresenter.showMainWindow()
        return false
    }
}

@main
struct HiveExecutable: App {
    @NSApplicationDelegateAdaptor(HiveAppLifecycleDelegate.self) private var lifecycleDelegate
    @StateObject private var model = HiveAppModel()
    @StateObject private var preferences = HiveAppPreferences()
    @StateObject private var liveHotKey = HiveLiveHotKeyController()
    @StateObject private var quickChatWindow = SwarmQuickChatWindowController()
    @StateObject private var quickChatHotKey = SwarmQuickChatHotKeyController()
    @StateObject private var shiftCaptureHotKey = HiveShiftCaptureHotKeyController()

    init() {
        HiveFontRegistrar.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            HiveMacRootView()
                .environmentObject(model)
                .onAppear {
                    liveHotKey.install(model: model)
                    quickChatWindow.install(model: model)
                    quickChatHotKey.install(windowController: quickChatWindow)
                    shiftCaptureHotKey.install(model: model)
                }
                .onChange(of: preferences.shortcutRevision) { _, _ in
                    liveHotKey.install(model: model)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.automatic)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit Hive") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
            CommandGroup(after: .sidebar) {
                Button(preferences.sidebarVisible ? "Hide Navigator" : "Show Navigator") {
                    preferences.setSidebarVisible(!preferences.sidebarVisible)
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    openSettingsPanel()
                }
                .keyboardShortcut(shortcutKey(for: .settings), modifiers: shortcutModifiers(for: .settings))
            }
            CommandMenu("Memory") {
                Button("Add to Field…") {
                    openImportPanel()
                }
                .keyboardShortcut(shortcutKey(for: .addSources), modifiers: shortcutModifiers(for: .addSources))

                Button("Ask Hive") {
                    guard requireAuthenticatedEntryPoint() else { return }
                    model.commandPaletteVisible = false
                    model.settingsVisible = false
                    model.chatVisible = true
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(shortcutKey(for: .chat), modifiers: shortcutModifiers(for: .chat))

                Button("Hive Live") {
                    guard requireAuthenticatedEntryPoint() else { return }
                    model.openLiveAssistant()
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(shortcutKey(for: .live), modifiers: shortcutModifiers(for: .live))

                Button("Swarm Quick Chat") {
                    guard requireAuthenticatedEntryPoint() else { return }
                    quickChatWindow.show()
                }
                .keyboardShortcut(.space, modifiers: [.option])

                Button("Command Palette…") {
                    guard requireAuthenticatedEntryPoint() else { return }
                    model.commandPaletteVisible = true
                }
                .keyboardShortcut("k", modifiers: [.command])

                Divider()

                Button("Field") {
                    guard requireAuthenticatedEntryPoint() else { return }
                    model.chatVisible = false
                    model.settingsVisible = false
                    model.selectedSurface = .rawInputs
                }
                .keyboardShortcut(shortcutKey(for: .rawSources), modifiers: shortcutModifiers(for: .rawSources))
                Button("The Colony") {
                    guard requireAuthenticatedEntryPoint() else { return }
                    model.chatVisible = false
                    model.settingsVisible = false
                    model.selectedSurface = .wiki
                }
                .keyboardShortcut(shortcutKey(for: .wiki), modifiers: shortcutModifiers(for: .wiki))
                Button("The Hive") {
                    guard requireAuthenticatedEntryPoint() else { return }
                    model.chatVisible = false
                    model.settingsVisible = false
                    model.selectedSurface = .graph
                }
                .keyboardShortcut(shortcutKey(for: .graph), modifiers: shortcutModifiers(for: .graph))
                Button("Search The Hive…") {
                    guard requireAuthenticatedEntryPoint() else { return }
                    model.chatVisible = false
                    model.settingsVisible = false
                    model.selectedSurface = .graph
                    model.graphSearchVisible = true
                }
                .keyboardShortcut(shortcutKey(for: .findMemory), modifiers: shortcutModifiers(for: .findMemory))

                Divider()

                Button("Review Field") {
                    guard requireAuthenticatedEntryPoint() else { return }
                    model.refreshKnowledge()
                }
                .keyboardShortcut(shortcutKey(for: .reviewMemory), modifiers: shortcutModifiers(for: .reviewMemory))
                .disabled(!model.commandAvailability(for: .reviewMemory).isEnabled)

                Button("Download Colony Images") {
                    guard requireAuthenticatedEntryPoint() else { return }
                    model.downloadAttachmentsForSelectedWikiPage()
                }
                .keyboardShortcut(shortcutKey(for: .downloadAttachments), modifiers: shortcutModifiers(for: .downloadAttachments))
                .disabled(!model.commandAvailability(for: .downloadAttachments).isEnabled)
                Button("Create Slide Deck") {
                    guard requireAuthenticatedEntryPoint() else { return }
                    model.createSlideDeckFromSelectedWikiPage()
                }
                .keyboardShortcut(shortcutKey(for: .createSlideDeck), modifiers: shortcutModifiers(for: .createSlideDeck))
                .disabled(!model.commandAvailability(for: .createSlideDeck).isEnabled)
                Button("Save Last Answer to The Colony") {
                    guard requireAuthenticatedEntryPoint() else { return }
                    model.fileLastChatAnswerToWiki()
                }
                .keyboardShortcut(shortcutKey(for: .fileAnswer), modifiers: shortcutModifiers(for: .fileAnswer))
                .disabled(!model.commandAvailability(for: .fileAnswer).isEnabled)
                Button("Capture Current Page") {
                    guard requireAuthenticatedEntryPoint() else { return }
                    model.captureCurrentPage(command: "Capture the current page as Field evidence for Hive.")
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Divider()

                Button("Show Hive") {
                    HiveMacWindowPresenter.showMainWindow()
                }
                .keyboardShortcut("h", modifiers: [.option])
                Button("Show Tutorial") {
                    guard requireAuthenticatedEntryPoint() else { return }
                    UserDefaults.standard.set(false, forKey: "hive.hasSeenOnboarding")
                    HiveMacWindowPresenter.showMainWindow()
                }
            }
            CommandGroup(replacing: .help) {
                Button("Hive Tutorial") {
                    guard requireAuthenticatedEntryPoint() else { return }
                    UserDefaults.standard.set(false, forKey: "hive.hasSeenOnboarding")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Button("Open Field") {
                    guard requireAuthenticatedEntryPoint() else { return }
                    model.selectedSurface = .rawInputs
                    NSApp.activate(ignoringOtherApps: true)
                }
                Button("Open The Colony") {
                    guard requireAuthenticatedEntryPoint() else { return }
                    model.selectedSurface = .wiki
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }

        MenuBarExtra(
            isInserted: Binding(
                get: { preferences.menuBarExtraVisible },
                set: { preferences.setMenuBarExtraVisible($0) }
            )
        ) {
            HiveMenuBarPopover(
                onImportDocuments: openImportPanel,
                onOpenSettings: openSettingsPanel,
                onQuit: { NSApp.terminate(nil) }
            )
                .environmentObject(model)
                .tint(HiveColorToken.waxAmber.color)
        } label: {
            HiveMenuBarIcon()
                .overlay(
                    ZStack {
                        HiveLiveHotKeyBootstrap(
                            controller: liveHotKey,
                            model: model,
                            shortcutRevision: preferences.shortcutRevision
                        )
                        SwarmQuickChatBootstrap(
                            windowController: quickChatWindow,
                            hotKeyController: quickChatHotKey,
                            model: model
                        )
                        HiveShiftCaptureBootstrap(
                            controller: shiftCaptureHotKey,
                            model: model
                        )
                    }
                )
        }
        .menuBarExtraStyle(.window)

        Settings {
            HiveSettingsWindowContent()
                .environmentObject(model)
        }
    }

    private func openSettingsPanel() {
        guard requireAuthenticatedEntryPoint() else { return }
        model.commandPaletteVisible = false
        model.chatVisible = false
        model.settingsVisible = false
        HiveMacWindowPresenter.showSettingsWindow()
    }

    private func openImportPanel() {
        guard requireAuthenticatedEntryPoint() else { return }
        model.commandPaletteVisible = false
        model.chatVisible = false
        model.settingsVisible = false
        model.selectedSurface = .rawInputs
        HiveMacWindowPresenter.showMainWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            HiveMacWindowPresenter.presentFieldImportPanel { urls in
                model.ingest(urls: urls)
            }
        }
    }

    private func requireAuthenticatedEntryPoint() -> Bool {
        model.refreshAppleAuthentication()
        guard model.isAppleAuthenticated else {
            HiveMacWindowPresenter.showMainWindow()
            NSApp.activate(ignoringOtherApps: true)
            return false
        }
        return true
    }

    private func shortcutKey(for command: HiveCommand) -> KeyEquivalent {
        _ = preferences.shortcutRevision
        return Self.shortcutDefinition(for: command).key
    }

    private func shortcutModifiers(for command: HiveCommand) -> SwiftUI.EventModifiers {
        _ = preferences.shortcutRevision
        return Self.shortcutDefinition(for: command).modifiers
    }

    private static func shortcutDefinition(for command: HiveCommand) -> (key: KeyEquivalent, modifiers: SwiftUI.EventModifiers) {
        parseShortcut(HiveCommandShortcutStore.shortcut(for: command))
            ?? parseShortcut(command.defaultShortcut)
            ?? (KeyEquivalent("k"), [.command])
    }

    private static func parseShortcut(_ shortcut: String) -> (key: KeyEquivalent, modifiers: SwiftUI.EventModifiers)? {
        guard let parsed = HiveKeyboardShortcut.parse(shortcut) else { return nil }
        var modifiers = SwiftUI.EventModifiers()
        if parsed.modifiers.contains(.command) {
            modifiers.insert(.command)
        }
        if parsed.modifiers.contains(.shift) {
            modifiers.insert(.shift)
        }
        if parsed.modifiers.contains(.option) {
            modifiers.insert(.option)
        }
        if parsed.modifiers.contains(.control) {
            modifiers.insert(.control)
        }

        switch parsed.key.lowercased() {
        case "comma":
            return (KeyEquivalent(","), modifiers)
        case "space":
            return (KeyEquivalent(" "), modifiers)
        case "escape", "esc":
            return (.escape, modifiers)
        case "delete", "backspace":
            return (.delete, modifiers)
        case "return", "enter":
            return (.return, modifiers)
        default:
            guard let character = parsed.key.lowercased().first else { return nil }
            return (KeyEquivalent(character), modifiers)
        }
    }
}
