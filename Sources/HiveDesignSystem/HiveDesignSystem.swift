import Foundation
import SwiftUI
import HiveCore
#if canImport(CoreText)
import CoreText
#endif
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

public enum HiveHIGPrinciple: String, CaseIterable, Sendable {
    case hierarchy
    case harmony
    case consistency
    case accessibility
    case materialRestraint
    case platformConvention
    case userControl

    public var implementationRule: String {
        switch self {
        case .hierarchy:
            return "Controls and navigation elevate above content; content remains the primary readable layer."
        case .harmony:
            return "Use platform-native spacing, rounded geometry, SF Symbols, and adaptive appearances before custom chrome."
        case .consistency:
            return "Shared wrappers own symbols, solid surfaces, motion, type, color, and control behavior across every Hive surface."
        case .accessibility:
            return "Every control has a label, reduced-motion fallback, sufficient target size, and non-color state signal."
        case .materialRestraint:
            return "Use the login preview's solid honey and obsidian surfaces across app chrome; avoid translucent material treatments."
        case .platformConvention:
            return "Prefer familiar Apple controls, keyboard behavior, focus behavior, and system adaptation over one-off gestures."
        case .userControl:
            return "Destructive, timed, AI-derived, or ambiguous actions require visible confirmation or reversible review."
        }
    }
}

public enum HiveSurfaceLayerRole: String, CaseIterable, Sendable {
    case button
    case navigation
    case toolbar
    case search
    case commandPalette
    case chatSheet
    case inspector
    case popover
    case modal
    case rawInputList
    case wikiProse
    case graphCanvas
    case contentRow
    case settingsRow
}

public enum HiveHIGPolicy {
    public static let humanInterfaceGuidelinesURL = "https://developer.apple.com/design/human-interface-guidelines/"
    public static let materialsGuidelinesURL = "https://developer.apple.com/design/human-interface-guidelines/materials"
    public static let accessibilityGuidelinesURL = "https://developer.apple.com/design/human-interface-guidelines/accessibility"
    public static let sfSymbolsGuidelinesURL = "https://developer.apple.com/design/human-interface-guidelines/sf-symbols"
    public static let buttonsGuidelinesURL = "https://developer.apple.com/design/human-interface-guidelines/buttons"
    public static let toolbarsGuidelinesURL = "https://developer.apple.com/design/human-interface-guidelines/toolbars"
    public static let searchGuidelinesURL = "https://developer.apple.com/design/human-interface-guidelines/search-fields"
    public static let listsAndTablesGuidelinesURL = "https://developer.apple.com/design/human-interface-guidelines/lists-and-tables"
    public static let dragAndDropGuidelinesURL = "https://developer.apple.com/design/human-interface-guidelines/drag-and-drop"
    public static let colorGuidelinesURL = "https://developer.apple.com/design/human-interface-guidelines/color"
    public static let textViewsGuidelinesURL = "https://developer.apple.com/design/human-interface-guidelines/text-views"
    public static let feedbackGuidelinesURL = "https://developer.apple.com/design/human-interface-guidelines/feedback"
    public static let motionGuidelinesURL = "https://developer.apple.com/design/human-interface-guidelines/motion"
    public static let onboardingGuidelinesURL = "https://developer.apple.com/design/human-interface-guidelines/onboarding"
    public static let writingGuidelinesURL = "https://developer.apple.com/design/human-interface-guidelines/writing"
    public static let offeringHelpGuidelinesURL = "https://developer.apple.com/design/human-interface-guidelines/offering-help"
    public static let settingsGuidelinesURL = "https://developer.apple.com/design/human-interface-guidelines/settings"
    public static let typographyGuidelinesURL = "https://developer.apple.com/design/human-interface-guidelines/typography"

    public static let minimumMacTextSize: CGFloat = 16
    public static let minimumMacControlTarget: CGFloat = 44
    public static let minimumTouchControlTarget: CGFloat = 44
    public static let minimumGraphAccessibilityTarget: CGFloat = 44

    public static let usesSharedSymbolWrapper = true
    public static let usesSharedGlassWrapper = false
    public static let usesSharedSolidSurfaceWrapper = true
    public static let modelOutputIsProposalOnly = true

    public static func liquidGlassAllowed(in role: HiveSurfaceLayerRole) -> Bool {
        switch role {
        case .button, .navigation, .toolbar, .search, .commandPalette, .chatSheet, .inspector, .popover, .modal, .rawInputList, .wikiProse, .graphCanvas, .contentRow, .settingsRow:
            return false
        }
    }

    public static func targetSize(compact: Bool) -> CGFloat {
        compact ? minimumMacControlTarget : minimumTouchControlTarget
    }

    public static func accessibilityHint(for action: String) -> String {
        "Performs \(action) immediately."
    }
}

public enum HiveDesignDocumentPolicy {
    public static let sourceDocument = "APPLE DESIGN DOC"

    public static let supportsAccessibilityAudit = true
    public static let textSupportsReadableMinimums = true
    public static let avoidsLightWeightsForSmallText = true
    public static let colorNeverCarriesMeaningAlone = true
    public static let colorsHaveLightDarkAndContrastVariants = true
    public static let avoidsRepeatingBrandLogoInChrome = true
    public static let usesSFSymbolsForCommonInterfaceIcons = true
    public static let layoutSeparatesControlsFromContent = true
    public static let layoutUsesSafeEdgePadding = true
    public static let controlsHaveLogicalGroupingAndBreathingRoom = true
    public static let liquidGlassIsControlLayerOnly = false
    public static let liquidGlassColorIsSparse = false
    public static let solidHoneyObsidianSurfacesOnly = true
    public static let motionIsPurposefulAndOptional = true
    public static let privacyRequestsAreContextual = true
    public static let localizationUsesSystemMirroringWherePossible = true
    public static let writingIsPlainAndActionable = true
    public static let typographyUsesTwoRegisters = true
    public static let typographyUsesSystemForControls = true
    public static let typographyUsesSerifOnlyForAuthoredMemory = true
    public static let typographyAvoidsCondensedAndLightChrome = true

    public static let maximumTextButtonsInToolbarRow = 2
    public static let maximumGlyphButtonsInToolbarRow = 3
    public static let minimumReadableMacTextSize: CGFloat = 15

    public static func toolbarRowIsCompliant(textButtonCount: Int, glyphButtonCount: Int) -> Bool {
        textButtonCount <= maximumTextButtonsInToolbarRow
            && glyphButtonCount <= maximumGlyphButtonsInToolbarRow
    }

    public static func fontSizeIsReadable(_ size: CGFloat, isDecorativeOrBadge: Bool = false) -> Bool {
        isDecorativeOrBadge || size >= minimumReadableMacTextSize
    }

    public static var followsCoreDesignRules: Bool {
        supportsAccessibilityAudit
            && textSupportsReadableMinimums
            && avoidsLightWeightsForSmallText
            && colorNeverCarriesMeaningAlone
            && colorsHaveLightDarkAndContrastVariants
            && avoidsRepeatingBrandLogoInChrome
            && usesSFSymbolsForCommonInterfaceIcons
            && layoutSeparatesControlsFromContent
            && layoutUsesSafeEdgePadding
            && controlsHaveLogicalGroupingAndBreathingRoom
            && solidHoneyObsidianSurfacesOnly
            && motionIsPurposefulAndOptional
            && privacyRequestsAreContextual
            && localizationUsesSystemMirroringWherePossible
            && writingIsPlainAndActionable
            && toolbarRowIsCompliant(textButtonCount: maximumTextButtonsInToolbarRow, glyphButtonCount: maximumGlyphButtonsInToolbarRow)
            && fontSizeIsReadable(minimumReadableMacTextSize)
    }
}

public enum HiveAtmospherePolicy {
    public static let targetMood = "cozy but powerful"
    public static let usesBurnishedHoneyLightMode = true
    public static let usesObsidianDarkMode = true
    public static let surfacesUseWarmDepth = true
    public static let controlsFeelWeightyNotLoud = true
    public static let motionFeelsCalmAndResponsive = true
    public static let avoidsDecorativeNoise = true
    public static let keepsAccentSparse = true

    public static var followsCozyPowerRules: Bool {
        usesBurnishedHoneyLightMode
            && usesObsidianDarkMode
            && surfacesUseWarmDepth
            && controlsFeelWeightyNotLoud
            && motionFeelsCalmAndResponsive
            && avoidsDecorativeNoise
            && keepsAccentSparse
    }
}

public enum HiveMacOSDesignPolicy {
    public static let sourceDocument = "APPLE DESIGN DOC - Designing for macOS"

    public static let mainWindowUsesNativeScene = true
    public static let mainWindowIsFreelyResizable = true
    public static let supportsFullScreenMode = true
    public static let usesNativeSplitViewForLargeDisplays = true
    public static let avoidsDeepModalityOnLargeDisplays = true
    public static let commandsAreInMenuBar = true
    public static let toolbarActionsHaveMenuAlternates = true
    public static let supportsKeyboardOnlyWorkflows = true
    public static let supportsPointerAndTrackpadPrecision = true
    public static let supportsMultipleInputModes = true
    public static let preservesMenuBarAgentWhenWindowsClose = true
    public static let supportsPersonalization = true
    public static let keepsAdvancedSettingsDiscoverable = true

    public static var followsCoreMacOSRules: Bool {
        mainWindowUsesNativeScene
            && mainWindowIsFreelyResizable
            && supportsFullScreenMode
            && usesNativeSplitViewForLargeDisplays
            && avoidsDeepModalityOnLargeDisplays
            && commandsAreInMenuBar
            && toolbarActionsHaveMenuAlternates
            && supportsKeyboardOnlyWorkflows
            && supportsPointerAndTrackpadPrecision
            && supportsMultipleInputModes
            && preservesMenuBarAgentWhenWindowsClose
            && supportsPersonalization
            && keepsAdvancedSettingsDiscoverable
    }
}

public enum HiveComponentRole: String, CaseIterable, Sendable {
    case button
    case toolbar
    case searchField
    case sidebar
    case tabBar
    case menu
    case contextMenu
    case actionSheet
    case alert
    case popover
    case sheet
    case window
    case segmentedControl
    case slider
    case stepper
    case textField
    case progressIndicator
    case chart
}

public enum HiveComponentPolicy {
    public static let sourceDocument = "APPLE COMPONENTS DOC"
    public static let minimumButtonHitRegion: CGFloat = 44
    public static let maximumProminentButtonsPerView = 2
    public static let maximumToolbarGroups = 3
    public static let maximumContextMenuGroups = 3
    public static let maximumWideSegments = 7
    public static let maximumPhoneSegments = 5
    public static let menuBarExtraHeight: CGFloat = 24

    public static let allToolbarItemsMustHaveMenuCommands = true
    public static let closeUsesStandardSymbolOnly = true
    public static let usesSystemEditMenuForStandardEditing = true
    public static let contextMenusHideUnavailableItems = true
    public static let contextMenusOmitKeyboardShortcuts = true
    public static let actionSheetsAreForIntentionalChoices = true
    public static let alertsAreForProblemsOrStateChanges = true
    public static let sidebarsUseLiquidGlassLayer = false
    public static let sidebarsUseSolidSurfaceLayer = true
    public static let sidebarsAvoidCriticalBottomContent = true
    public static let searchStartsImmediately = true
    public static let progressPrefersDeterminateWhenPossible = true
    public static let progressOffersCancellationWhenSafe = true
    public static let segmentedControlsKeepOneContentKind = true
    public static let slidersUseLeadingMinimumTrailingMaximum = true
    public static let textFieldsUseLabelsAndPurposefulPlaceholders = true
    public static let chartsNeverUseColorOnly = true

    public static func requiresEllipsisWhenOpeningFurtherInput(_ opensFurtherInput: Bool) -> Bool {
        opensFurtherInput
    }

    public static func labelSatisfiesEllipsisRule(_ label: String, opensFurtherInput: Bool) -> Bool {
        guard requiresEllipsisWhenOpeningFurtherInput(opensFurtherInput) else {
            return !label.hasSuffix("…") && !label.hasSuffix("...")
        }
        return label.hasSuffix("…") || label.hasSuffix("...")
    }

    public static func searchPlaceholderIsSpecific(_ placeholder: String) -> Bool {
        let trimmed = placeholder.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        return !trimmed.isEmpty
            && !lower.hasPrefix("search")
            && !lower.contains("search for")
    }

    public static func buttonLabelStartsWithVerb(_ label: String) -> Bool {
        let first = label
            .replacingOccurrences(of: "…", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .first?
            .lowercased() ?? ""
        let verbs: Set<String> = [
            "add", "ask", "open", "show", "hide", "save", "download", "capture",
            "review", "update", "feed", "mark", "forget", "archive", "recenter",
            "clear", "send", "done", "replay", "run", "focus", "find"
        ]
        return verbs.contains(first)
    }

    public static var followsCoreComponentRules: Bool {
        minimumButtonHitRegion >= 44
            && maximumProminentButtonsPerView <= 2
            && maximumToolbarGroups <= 3
            && maximumContextMenuGroups <= 3
            && allToolbarItemsMustHaveMenuCommands
            && closeUsesStandardSymbolOnly
            && usesSystemEditMenuForStandardEditing
            && contextMenusHideUnavailableItems
            && contextMenusOmitKeyboardShortcuts
            && actionSheetsAreForIntentionalChoices
            && alertsAreForProblemsOrStateChanges
            && sidebarsUseSolidSurfaceLayer
            && sidebarsAvoidCriticalBottomContent
            && searchStartsImmediately
            && progressPrefersDeterminateWhenPossible
            && progressOffersCancellationWhenSafe
            && segmentedControlsKeepOneContentKind
            && slidersUseLeadingMinimumTrailingMaximum
            && textFieldsUseLabelsAndPurposefulPlaceholders
            && chartsNeverUseColorOnly
    }
}

public enum HivePatternPolicy {
    public static let sourceDocument = "APPLE PATTERNS DOC"

    public static let settingsOpenFromAppMenu = true
    public static let settingsUseCommandComma = true
    public static let settingsAvoidToolbarButtons = true
    public static let settingsTitleNamesAppWhenSinglePane = true
    public static let taskSpecificOptionsStayInContext = true
    public static let searchHasSingleObviousEntry = true
    public static let searchPlaceholderNamesScope = true
    public static let searchShowsScopeWhenHelpful = true
    public static let searchHistoryIsPrivate = true
    public static let dataEntryPrefersSystemSources = true
    public static let dataEntrySupportsDragDropAndPaste = true
    public static let dataEntryUsesChoicesWhenPossible = true
    public static let feedbackIsInlineByDefault = true
    public static let feedbackExplainsUnavailableActions = true
    public static let disabledCommandReasonsCanWrap = true
    public static let primaryContentLoadsWithoutAuxiliaryPanels = true
    public static let auxiliaryPanelsOpenAfterUserIntent = true
    public static let modalSurfacesRequireDismissal = true
    public static let modalSurfacesAvoidStacking = true
    public static let onboardingIsOptionalAndReplayable = true
    public static let onboardingUsesRealInteraction = true
    public static let helpAvoidsStandardControlExplanations = true
    public static let tooltipsDescribeSpecificAction = true

    public static func settingsPlacementIsCompliant(
        hasToolbarSettingsButton: Bool,
        hasAppSettingsCommand: Bool,
        usesCommandComma: Bool
    ) -> Bool {
        !hasToolbarSettingsButton
            && hasAppSettingsCommand
            && usesCommandComma
    }

    public static func tooltipIsCompliant(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...75).contains(trimmed.count) else { return false }
        let first = trimmed
            .replacingOccurrences(of: "…", with: "")
            .split(separator: " ")
            .first?
            .description
            .trimmingCharacters(in: .punctuationCharacters)
            .lowercased() ?? ""
        let actionVerbs: Set<String> = [
            "add", "ask", "capture", "clear", "close", "download", "find",
            "focus", "hide", "mark", "open", "record", "recenter", "replay",
            "review", "save", "search", "send", "show", "stop", "toggle"
        ]
        return actionVerbs.contains(first)
    }

    public static var followsCorePatternRules: Bool {
        settingsOpenFromAppMenu
            && settingsUseCommandComma
            && settingsAvoidToolbarButtons
            && settingsTitleNamesAppWhenSinglePane
            && taskSpecificOptionsStayInContext
            && searchHasSingleObviousEntry
            && searchPlaceholderNamesScope
            && searchShowsScopeWhenHelpful
            && searchHistoryIsPrivate
            && dataEntryPrefersSystemSources
            && dataEntrySupportsDragDropAndPaste
            && dataEntryUsesChoicesWhenPossible
            && feedbackIsInlineByDefault
            && feedbackExplainsUnavailableActions
            && disabledCommandReasonsCanWrap
            && primaryContentLoadsWithoutAuxiliaryPanels
            && auxiliaryPanelsOpenAfterUserIntent
            && modalSurfacesRequireDismissal
            && modalSurfacesAvoidStacking
            && onboardingIsOptionalAndReplayable
            && onboardingUsesRealInteraction
            && helpAvoidsStandardControlExplanations
            && tooltipsDescribeSpecificAction
    }
}

public enum HiveInputPolicy {
    public static let sourceDocument = "APPLE INPUT DOC"

    public static let supportsFullKeyboardAccess = true
    public static let respectsStandardKeyboardShortcuts = true
    public static let customShortcutsAreForFrequentCommands = true
    public static let customDefaultsAvoidControlAsPrimaryModifier = true
    public static let customDefaultsAvoidSystemReservedCombos = true

    public static let allowedStandardShortcutMappings: [String: String] = [
        "addSources": "command o",
        "findMemory": "command f",
        "settings": "command comma"
    ]

    public static let reservedSystemShortcuts: Set<String> = [
        "command space",
        "option command space",
        "control command space",
        "command tab",
        "shift command tab",
        "control tab",
        "control shift tab",
        "escape",
        "command comma",
        "command period",
        "command question",
        "command a",
        "shift command a",
        "command c",
        "shift command c",
        "option command c",
        "control command c",
        "option command d",
        "control command d",
        "command f",
        "option command f",
        "control command f",
        "command h",
        "option command h",
        "command i",
        "option command i",
        "command j",
        "command m",
        "option command m",
        "command n",
        "command o",
        "command p",
        "shift command p",
        "command q",
        "shift command q",
        "option shift command q",
        "command s",
        "shift command s",
        "command t",
        "option command t",
        "command u",
        "command v",
        "shift command v",
        "option command v",
        "option shift command v",
        "control command v",
        "command w",
        "shift command w",
        "option command w",
        "command x",
        "command z",
        "shift command z"
    ]

    public static func normalizedShortcut(_ shortcut: String) -> String {
        let lower = shortcut.lowercased()
        var parts: [String] = []
        if lower.contains("control") || lower.contains("ctrl") || shortcut.contains("⌃") {
            parts.append("control")
        }
        if lower.contains("option") || lower.contains("alt") || shortcut.contains("⌥") {
            parts.append("option")
        }
        if lower.contains("shift") || shortcut.contains("⇧") {
            parts.append("shift")
        }
        if lower.contains("command") || lower.contains("cmd") || shortcut.contains("⌘") {
            parts.append("command")
        }

        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "+-"))
        let tokens = lower
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        let key = tokens.last { token in
            !["control", "ctrl", "option", "alt", "shift", "command", "cmd"].contains(token)
        }
        if let key {
            parts.append(key)
        }
        return parts.joined(separator: " ")
    }

    public static func defaultShortcutIsCompliant(commandID: String, shortcut: String) -> Bool {
        let normalized = normalizedShortcut(shortcut)
        if allowedStandardShortcutMappings[commandID] == normalized {
            return true
        }
        if normalized.hasPrefix("control ") {
            return false
        }
        return !reservedSystemShortcuts.contains(normalized)
    }

    public static var followsCoreInputRules: Bool {
        supportsFullKeyboardAccess
            && respectsStandardKeyboardShortcuts
            && customShortcutsAreForFrequentCommands
            && customDefaultsAvoidControlAsPrimaryModifier
            && customDefaultsAvoidSystemReservedCombos
            && defaultShortcutIsCompliant(commandID: "addSources", shortcut: "Command O")
            && defaultShortcutIsCompliant(commandID: "findMemory", shortcut: "Command F")
            && defaultShortcutIsCompliant(commandID: "settings", shortcut: "Command Comma")
            && defaultShortcutIsCompliant(commandID: "chat", shortcut: "Option Command A")
            && !defaultShortcutIsCompliant(commandID: "chat", shortcut: "Command Shift A")
            && !defaultShortcutIsCompliant(commandID: "downloadAttachments", shortcut: "Control Shift D")
            && !defaultShortcutIsCompliant(commandID: "fileAnswer", shortcut: "Command Shift S")
    }
}

public enum HiveLayoutMetrics {
    public static let windowOuterPadding: CGFloat = 20
    public static let windowLeadingPadding: CGFloat = 18
    public static let sidebarWidth: CGFloat = 180
    public static let toolbarTopPadding: CGFloat = 24
    public static let toolbarTrailingPadding: CGFloat = 32
    public static let contentMaxWidth: CGFloat = 1180
    public static let contentHorizontalPadding: CGFloat = 24
    public static let contentVerticalPadding: CGFloat = 24
    public static let readableLineWidth: CGFloat = 780
    public static let wikiArticleMaxWidth: CGFloat = 1080
    public static let wikiListWidth: CGFloat = 220
    public static let sourceInspectorWidth: CGFloat = 360
    public static let graphInspectorMinWidth: CGFloat = 420
    public static let graphInspectorMaxWidth: CGFloat = 520
    public static let settingsWidth: CGFloat = 680
    public static let settingsWindowMinWidth: CGFloat = 1_200
    public static let settingsWindowIdealWidth: CGFloat = 1_360
    public static let settingsWindowMinHeight: CGFloat = 560
    public static let settingsWindowIdealHeight: CGFloat = 684
    public static let sheetWidth: CGFloat = 360
    public static let safeEdgePadding: CGFloat = 28
    public static let smallCornerRadius: CGFloat = 6
    public static let compactCornerRadius: CGFloat = 6
    public static let controlCornerRadius: CGFloat = 6
    public static let rowCornerRadius: CGFloat = 10
    public static let surfaceCornerRadius: CGFloat = 14
    public static let prominentSurfaceCornerRadius: CGFloat = 20

    public static func graphInspectorWidth(for availableWidth: CGFloat) -> CGFloat {
        min(graphInspectorMaxWidth, max(graphInspectorMinWidth, availableWidth * 0.34))
    }
}

public enum HiveReadableSurface: String, CaseIterable, Sendable {
    case rawSources
    case wikiArticle
    case settings
    case inspector
    case graphOverlay

    public var maxWidth: CGFloat {
        switch self {
        case .rawSources:
            return HiveLayoutMetrics.contentMaxWidth
        case .wikiArticle:
            return HiveLayoutMetrics.wikiArticleMaxWidth
        case .settings:
            return HiveLayoutMetrics.settingsWidth
        case .inspector:
            return HiveLayoutMetrics.graphInspectorMaxWidth
        case .graphOverlay:
            return 360
        }
    }

    public var horizontalPadding: CGFloat {
        switch self {
        case .wikiArticle:
            return 48
        case .settings:
            return 36
        case .inspector:
            return 20
        case .graphOverlay:
            return 14
        case .rawSources:
            return HiveLayoutMetrics.contentHorizontalPadding
        }
    }

    public var verticalPadding: CGFloat {
        switch self {
        case .settings:
            return 36
        case .wikiArticle:
            return 34
        case .inspector:
            return 20
        case .graphOverlay:
            return 14
        case .rawSources:
            return HiveLayoutMetrics.contentVerticalPadding
        }
    }

    public var usesGlass: Bool {
        switch self {
        case .graphOverlay, .inspector, .rawSources, .wikiArticle, .settings:
            return false
        }
    }
}

public enum HiveInteractionPolicy {
    public static let hoverPreviewDelay: TimeInterval = 0.08
    public static let hoverDismissDelay: TimeInterval = 0.04
    public static let graphMinimumFramesPerSecond = 60
    public static let graphPreferredFramesPerSecond = 120
    public static let graphClusterNodeLimit = 96
    public static let graphDetailNodeLimit = 180
    public static let graphIdleEdgeLimit = 512
    public static let graphFocusedEdgeLimit = 512
    public static let graphViewportMargin: CGFloat = 160
    public static let interactionAnimationDuration: TimeInterval = 0.3
    public static let graphHoverUpdateInterval: TimeInterval = 1.0 / 60.0
    public static let graphHoverMinimumPointDelta: CGFloat = 5
}

public enum HiveColorToken: CaseIterable, Sendable {
    case backgroundDeep
    case backgroundMid
    case cellSurface
    case raisedSurface
    case waxAmber
    case waxAmberBright
    case waxAmberDeep
    case neuralGold
    case fieldMint
    case pollenBlue
    case orchidBloom
    case scaffoldGray
    case scaffoldFaint
    case nectarText
    case nectarMuted
    case sealed
    case conflict

    public var color: Color {
        Color.hiveAdaptive(light: lightHex, dark: darkHex)
    }

    public var lightRawValue: String {
        lightHex
    }

    public var rawValue: String {
        darkHex
    }

    private var darkHex: String {
        switch self {
        case .backgroundDeep:
            return "#0B0A08"
        case .backgroundMid:
            return "#14110E"
        case .cellSurface:
            return "#1D1A15"
        case .raisedSurface:
            return "#252017"
        case .waxAmber:
            return "#D8A21A"
        case .waxAmberBright:
            return "#E8B334"
        case .waxAmberDeep:
            return "#A97812"
        case .neuralGold:
            return "#D4A017"
        case .fieldMint:
            return "#9DB87A"
        case .pollenBlue:
            return "#8A8580"
        case .orchidBloom:
            return "#8A8580"
        case .scaffoldGray:
            return "#A69B8E"
        case .scaffoldFaint:
            return "#665C50"
        case .nectarText:
            return "#F0EAE0"
        case .nectarMuted:
            return "#B2A79A"
        case .sealed:
            return "#9DB87A"
        case .conflict:
            return "#C0392B"
        }
    }

    private var lightHex: String {
        switch self {
        case .backgroundDeep:
            return "#D7AF55"
        case .backgroundMid:
            return "#E4C16B"
        case .cellSurface:
            return "#F0D88E"
        case .raisedSurface:
            return "#C08E28"
        case .waxAmber:
            return "#704900"
        case .waxAmberBright:
            return "#6A4300"
        case .waxAmberDeep:
            return "#493100"
        case .neuralGold:
            return "#8F6100"
        case .fieldMint:
            return "#6F8352"
        case .pollenBlue:
            return "#302207"
        case .orchidBloom:
            return "#302207"
        case .scaffoldGray:
            return "#382806"
        case .scaffoldFaint:
            return "#6D4E0D"
        case .nectarText:
            return "#130D04"
        case .nectarMuted:
            return "#3A2806"
        case .sealed:
            return "#68794F"
        case .conflict:
            return "#C0392B"
        }
    }
}

public enum HiveSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 48
}

public enum HiveRadius {
    public static let sm: CGFloat = 6
    public static let md: CGFloat = 10
    public static let lg: CGFloat = 14
    public static let xl: CGFloat = 20
    public static let full: CGFloat = 999
}

public enum HiveAmbientPalette {
    public static func honeyHighlight(for colorScheme: ColorScheme) -> Color {
        Color(hiveHex: colorScheme == .dark ? "#FFE5A2" : "#F0D27E")
    }

    public static func honeyGold(for colorScheme: ColorScheme) -> Color {
        Color(hiveHex: colorScheme == .dark ? "#E8A72A" : "#D49A22")
    }

    public static func honeyAmber(for colorScheme: ColorScheme) -> Color {
        Color(hiveHex: colorScheme == .dark ? "#B86E12" : "#A96E08")
    }

    public static func meadowWarmth(for colorScheme: ColorScheme) -> Color {
        Color(hiveHex: colorScheme == .dark ? "#5E7C31" : "#827228")
    }

}

public extension Color {
    static func hiveAdaptive(light: String, dark: String) -> Color {
        #if canImport(AppKit)
        return Color(NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua])
            let selected = match == .darkAqua ? dark : light
            let parts = hiveRGBComponents(selected)
            return NSColor(calibratedRed: parts.r, green: parts.g, blue: parts.b, alpha: 1)
        })
        #elseif canImport(UIKit) && !os(watchOS)
        return Color(UIColor { traits in
            let selected = traits.userInterfaceStyle == .dark ? dark : light
            let parts = hiveRGBComponents(selected)
            return UIColor(red: parts.r, green: parts.g, blue: parts.b, alpha: 1)
        })
        #else
        return Color(hiveHex: dark)
        #endif
    }

    init(hiveHex: String) {
        let components = Self.hiveRGBComponents(hiveHex)
        self.init(red: components.r, green: components.g, blue: components.b)
    }

    private static func hiveRGBComponents(_ hex: String) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(cleaned, radix: 16) ?? 0
        let red = CGFloat((value >> 16) & 0xff) / 255.0
        let green = CGFloat((value >> 8) & 0xff) / 255.0
        let valuePart = CGFloat(value & 0xff) / 255.0
        return (red, green, valuePart)
    }
}

public enum HiveAppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case dark
    case light

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .system:
            return "System"
        case .dark:
            return "Dark"
        case .light:
            return "Light"
        }
    }

    public var preferredScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }
}

public enum HiveIdentity {
    public static let productName = "Hive"
    public static let voice = "A private AI memory vault that writes and rewrites itself under your control."
    public static let visualNorthStar = "Honey-warm local memory: Field raw files, The Colony articles, and The Hive graph."
    public static let interactionNorthStar = "every movement explains where knowledge came from or what changed"
}

public enum HiveFontName {
    public static let nectarBody = "Newsreader16pt-Regular"
    public static let nectarBodyMedium = "Newsreader16pt-Medium"
    public static let nectarBodySemibold = "Newsreader16pt-SemiBold"
    public static let nectarCaption = "Newsreader6pt-Medium"
}

public enum HiveFontRegistrar {
    private static let fontFiles = [
        "Newsreader16pt-Regular",
        "Newsreader16pt-Medium",
        "Newsreader16pt-SemiBold",
        "Newsreader6pt-Medium"
    ]

    public static func registerBundledFonts() {
        #if canImport(CoreText)
        var registeredNames = Set<String>()
        for name in fontFiles {
            guard registeredNames.insert(name).inserted else { continue }
            guard let url = fontURL(named: name) else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        #endif
    }

    private static func fontURL(named name: String) -> URL? {
        let manager = FileManager.default
        let directCandidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent("Hive_HiveDesignSystem.bundle/\(name).ttf"),
            Bundle.main.resourceURL?.appendingPathComponent("Hive_HiveDesignSystem.bundle/Fonts/\(name).ttf"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Hive_HiveDesignSystem.bundle/\(name).ttf"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Hive_HiveDesignSystem.bundle/Fonts/\(name).ttf")
        ]
        if let url = directCandidates.compactMap({ $0 }).first(where: { manager.fileExists(atPath: $0.path) }) {
            return url
        }
        return Bundle.module.url(forResource: name, withExtension: "ttf")
            ?? Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
    }

    public static var bundledFontCount: Int {
        fontFiles.count
    }
}

public enum HiveTypographyRegister: String, CaseIterable, Sendable {
    case systemChrome
    case authoredMemory
}

public enum HiveInterfaceScale {
    public static let storageKey = "hive.interfaceScale"
    public static let defaultValue: Double = 1
    public static let minimum: Double = 0.85
    public static let maximum: Double = 1.2
    public static let step: Double = 0.05

    public static func normalized(_ value: Double) -> Double {
        min(max(value, minimum), maximum)
    }

    public static var current: Double {
        let stored = UserDefaults.standard.object(forKey: storageKey) as? Double
        return normalized(stored ?? defaultValue)
    }

    public static func fontSize(_ baseSize: CGFloat) -> CGFloat {
        baseSize * CGFloat(current)
    }

    public static func label(for value: Double) -> String {
        "\(Int((normalized(value) * 100).rounded()))%"
    }
}

public enum HiveTypography {
    public static let registerCount = HiveTypographyRegister.allCases.count
    public static let usesCondensedChrome = false
    public static let usesLightChromeWeights = false
    public static let chromeMinimumSize = HiveHIGPolicy.minimumMacTextSize

    public static var hiveHero: Font { Font.system(size: HiveInterfaceScale.fontSize(28), weight: .semibold, design: .default) }
    public static var hiveTitle: Font { Font.system(size: HiveInterfaceScale.fontSize(20), weight: .semibold, design: .default) }
    public static var hiveBody: Font { Font.system(size: HiveInterfaceScale.fontSize(14), weight: .regular, design: .default) }
    public static var hiveBodyMed: Font { Font.system(size: HiveInterfaceScale.fontSize(14), weight: .medium, design: .default) }
    public static var hiveCaption: Font { Font.system(size: HiveInterfaceScale.fontSize(12), weight: .regular, design: .default) }
    public static var hiveMeta: Font { Font.system(size: HiveInterfaceScale.fontSize(11), weight: .regular, design: .default) }

    public static var chromeLabel: Font { hiveBodyMed }
    public static var chromeMicro: Font { hiveMeta }
    public static var chromeBody: Font { hiveBody }
    public static var chromeBodyEmphasized: Font { hiveBodyMed }
    public static var chromeAction: Font { hiveBodyMed }
    public static var chromeTitle: Font { hiveTitle }
    public static var chromeSearch: Font { hiveBody }
    public static var chromeShortcut: Font { hiveMeta }
    public static var chromeFootnote: Font { hiveCaption }
    public static var chromeFootnoteEmphasized: Font { Font.system(size: HiveInterfaceScale.fontSize(12), weight: .medium, design: .default) }
    public static var chromeCaption: Font { hiveCaption }
    public static var monospaceFootnote: Font { Font.system(size: HiveInterfaceScale.fontSize(12), weight: .regular, design: .monospaced) }

    public static var memoryCardTitle: Font { hiveBodyMed }
    public static var memoryBody: Font { hiveBody }
    public static var memoryBodyLarge: Font { hiveBody }
    public static var memoryTitle: Font { hiveHero }
    public static var memoryQuestion: Font { hiveTitle }
    public static var memoryEditor: Font { hiveBody }

    public static func sidebarItem(selected: Bool) -> Font {
        Font.system(size: HiveInterfaceScale.fontSize(14), weight: .medium, design: .default)
    }

    public static func segmentedOption(selected: Bool) -> Font {
        Font.system(size: HiveInterfaceScale.fontSize(16), weight: selected ? .semibold : .medium, design: .default)
    }

    public static func graphInspectorTitle(size: CGFloat) -> Font {
        Font.system(size: HiveInterfaceScale.fontSize(size), weight: .semibold, design: .default)
    }
}

public enum HiveTypeRole: Sendable {
    case scaffoldLabel
    case scaffoldMicro
    case scaffoldBody
    case scaffoldAction
    case nectarCardTitle
    case nectarBody
    case nectarTitle
    case nectarQuestion
}

public struct HiveTypeStyle: Sendable {
    public var font: Font
    public var tracking: CGFloat
    public var color: Color
    public var uppercase: Bool

    public init(font: Font, tracking: CGFloat, color: Color, uppercase: Bool = false) {
        self.font = font
        self.tracking = tracking
        self.color = color
        self.uppercase = uppercase
    }
}

public enum HiveTypeSystem {
    public static func style(_ role: HiveTypeRole) -> HiveTypeStyle {
        switch role {
        case .scaffoldLabel:
            return HiveTypeStyle(
                font: HiveTypography.chromeLabel,
                tracking: 0,
                color: HiveColorToken.scaffoldGray.color,
                uppercase: false
            )
        case .scaffoldMicro:
            return HiveTypeStyle(
                font: HiveTypography.chromeMicro,
                tracking: 0.3,
                color: HiveColorToken.scaffoldFaint.color,
                uppercase: false
            )
        case .scaffoldBody:
            return HiveTypeStyle(
                font: HiveTypography.chromeBody,
                tracking: 0,
                color: HiveColorToken.scaffoldGray.color
            )
        case .scaffoldAction:
            return HiveTypeStyle(
                font: HiveTypography.chromeAction,
                tracking: 0,
                color: HiveColorToken.waxAmberBright.color,
                uppercase: false
            )
        case .nectarCardTitle:
            return HiveTypeStyle(
                font: HiveTypography.memoryCardTitle,
                tracking: 0,
                color: HiveColorToken.nectarText.color
            )
        case .nectarBody:
            return HiveTypeStyle(
                font: HiveTypography.memoryBodyLarge,
                tracking: 0,
                color: HiveColorToken.nectarText.color
            )
        case .nectarTitle:
            return HiveTypeStyle(
                font: HiveTypography.memoryTitle,
                tracking: 0,
                color: HiveColorToken.nectarText.color
            )
        case .nectarQuestion:
            return HiveTypeStyle(
                font: HiveTypography.memoryQuestion,
                tracking: 0,
                color: HiveColorToken.nectarText.color
            )
        }
    }
}

public struct HiveText: View {
    private let value: String
    private let role: HiveTypeRole
    private let lineSpacing: CGFloat

    public init(_ value: String, role: HiveTypeRole, lineSpacing: CGFloat = 0) {
        self.value = value
        self.role = role
        self.lineSpacing = lineSpacing
    }

    public var body: some View {
        let style = HiveTypeSystem.style(role)
        Text(style.uppercase ? value.uppercased() : value)
            .font(style.font)
            .tracking(style.tracking)
            .foregroundStyle(style.color)
            .lineSpacing(lineSpacing)
    }
}

public enum HiveOrganismState: String, CaseIterable, Sendable {
    case resting = "Resting"
    case foraging = "Foraging"
    case digesting = "Digesting"
    case synthesizing = "Synthesizing"
    case confused = "Confused — tap to help"
    case understood = "Understood"
}

public enum HiveStatusTranslator {
    public static func organismState(for status: RecordStatus) -> HiveOrganismState {
        switch SourcePresentationModel.status(for: status) {
        case .resting:
            return .resting
        case .foraging:
            return .foraging
        case .digesting:
            return .digesting
        case .synthesizing:
            return .synthesizing
        case .confused:
            return .confused
        case .understood:
            return .understood
        }
    }

    public static func globalState(sources: [SourceRecord]) -> HiveOrganismState {
        if sources.contains(where: { $0.status == .failed }) { return .confused }
        if sources.contains(where: { $0.status == .extracting }) { return .digesting }
        if sources.contains(where: { $0.status == .needsReview }) { return .synthesizing }
        if sources.contains(where: { $0.status == .queued || $0.status == .discovered }) { return .foraging }
        return sources.isEmpty ? .resting : .understood
    }

    public static func confidencePhrase(_ value: Double, evidenceCount: Int = 0) -> String {
        let base = SourcePresentationModel.confidenceLanguage(value)
        if evidenceCount <= 0 { return "The hive is \(base)." }
        let noun = evidenceCount == 1 ? "source" : "sources"
        return "The hive is \(base) based on \(evidenceCount) \(noun)."
    }
}

public enum HiveMotion {
    public static let welcome = Animation.spring(response: 0.72, dampingFraction: 0.9, blendDuration: 0.08)
    public static let reveal = Animation.spring(response: 0.52, dampingFraction: 0.88, blendDuration: 0.06)
    public static let standard = Animation.spring(response: 0.4, dampingFraction: 0.84, blendDuration: 0.04)
    public static let control = Animation.spring(response: 0.32, dampingFraction: 0.88, blendDuration: 0.03)
    public static let panel = Animation.spring(response: 0.48, dampingFraction: 0.86, blendDuration: 0.06)
    public static let focus = Animation.spring(response: 0.28, dampingFraction: 0.9, blendDuration: 0.03)
    public static let hoverLift = Animation.spring(response: 0.34, dampingFraction: 1.18, blendDuration: 0.02)
    public static let sidebarSelection = Animation.spring(response: 0.42, dampingFraction: 1.14, blendDuration: 0.04)
    public static let sidebarPageScroll = Animation.spring(response: 0.56, dampingFraction: 1.08, blendDuration: 0.06)
    public static let causal = Animation.spring(response: 0.44, dampingFraction: 0.88, blendDuration: 0.04)
    public static let waxFill = Animation.spring(response: 0.58, dampingFraction: 0.9, blendDuration: 0.06)
    public static let formation = Animation.interpolatingSpring(mass: 0.92, stiffness: 78, damping: 17, initialVelocity: 0.05)
    public static let stamp = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0.04)
    public static let breathing = Animation.timingCurve(0.33, 0.0, 0.18, 1.0, duration: 1.45).repeatForever(autoreverses: true)
    public static let glow = Animation.timingCurve(0.32, 0.0, 0.2, 1.0, duration: 1.8).repeatForever(autoreverses: true)
    public static let settle = Animation.timingCurve(0.2, 0.0, 0.16, 1.0, duration: 1.2)
    public static let drift = Animation.timingCurve(0.18, 0.0, 0.16, 1.0, duration: 0.48)
    public static let scrub = Animation.timingCurve(0.24, 0.0, 0.2, 1.0, duration: 0.032)
}

public struct HiveControlPressStyle: ButtonStyle {
    public init() {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.965 : 1))
            .brightness(configuration.isPressed ? 0.04 : 0)
    }
}

public struct HexagonShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for index in 0..<6 {
            let angle = CGFloat.pi / 6 + CGFloat(index) * CGFloat.pi / 3
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
