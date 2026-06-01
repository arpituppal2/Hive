import Foundation

public enum HiveSystemControlKind: String, Codable, CaseIterable, Sendable {
    case feedHive
    case quickCapture
    case askHive
    case runMaintenance
    case captureCurrentPage
}

public struct HiveSystemControlDescriptor: Codable, Hashable, Sendable {
    public var kind: HiveSystemControlKind
    public var title: String
    public var systemImageName: String
    public var offStateSystemImageName: String?
    public var placeholderValue: String
    public var requiresConfiguration: Bool
    public var hidesSensitiveContentWhenLocked: Bool
    public var requiresAuthenticationForSensitiveAction: Bool
    public var usesSymbolAnimationForStateChange: Bool
    public var opensAppDirectlyToRelatedContent: Bool
    public var benefitsWithoutLaunchingApp: Bool
    public var promptsForConfigurationWhenAdded: Bool
    public var canBeReconfigured: Bool

    public init(
        kind: HiveSystemControlKind,
        title: String,
        systemImageName: String,
        offStateSystemImageName: String? = nil,
        placeholderValue: String,
        requiresConfiguration: Bool,
        hidesSensitiveContentWhenLocked: Bool,
        requiresAuthenticationForSensitiveAction: Bool,
        usesSymbolAnimationForStateChange: Bool,
        opensAppDirectlyToRelatedContent: Bool,
        benefitsWithoutLaunchingApp: Bool = true,
        promptsForConfigurationWhenAdded: Bool = false,
        canBeReconfigured: Bool = true
    ) {
        self.kind = kind
        self.title = title
        self.systemImageName = systemImageName
        self.offStateSystemImageName = offStateSystemImageName
        self.placeholderValue = placeholderValue
        self.requiresConfiguration = requiresConfiguration
        self.hidesSensitiveContentWhenLocked = hidesSensitiveContentWhenLocked
        self.requiresAuthenticationForSensitiveAction = requiresAuthenticationForSensitiveAction
        self.usesSymbolAnimationForStateChange = usesSymbolAnimationForStateChange
        self.opensAppDirectlyToRelatedContent = opensAppDirectlyToRelatedContent
        self.benefitsWithoutLaunchingApp = benefitsWithoutLaunchingApp
        self.promptsForConfigurationWhenAdded = promptsForConfigurationWhenAdded
        self.canBeReconfigured = canBeReconfigured
    }
}

public enum HiveSystemControlCatalog {
    public static let controls: [HiveSystemControlDescriptor] = [
        HiveSystemControlDescriptor(
            kind: .feedHive,
            title: "Feed Hive",
            systemImageName: "tray.and.arrow.down",
            placeholderValue: "Add a note or file",
            requiresConfiguration: false,
            hidesSensitiveContentWhenLocked: true,
            requiresAuthenticationForSensitiveAction: false,
            usesSymbolAnimationForStateChange: true,
            opensAppDirectlyToRelatedContent: true
        ),
        HiveSystemControlDescriptor(
            kind: .quickCapture,
            title: "Quick Capture",
            systemImageName: "square.and.pencil",
            placeholderValue: "Capture a thought",
            requiresConfiguration: false,
            hidesSensitiveContentWhenLocked: true,
            requiresAuthenticationForSensitiveAction: false,
            usesSymbolAnimationForStateChange: true,
            opensAppDirectlyToRelatedContent: true
        ),
        HiveSystemControlDescriptor(
            kind: .askHive,
            title: "Ask Hive",
            systemImageName: "bubble.left.and.text.bubble.right",
            placeholderValue: "Ask from memory",
            requiresConfiguration: false,
            hidesSensitiveContentWhenLocked: true,
            requiresAuthenticationForSensitiveAction: false,
            usesSymbolAnimationForStateChange: true,
            opensAppDirectlyToRelatedContent: true
        ),
        HiveSystemControlDescriptor(
            kind: .runMaintenance,
            title: "Review Memory",
            systemImageName: "arrow.trianglehead.2.clockwise",
            placeholderValue: "Review sources",
            requiresConfiguration: false,
            hidesSensitiveContentWhenLocked: true,
            requiresAuthenticationForSensitiveAction: false,
            usesSymbolAnimationForStateChange: true,
            opensAppDirectlyToRelatedContent: true
        ),
        HiveSystemControlDescriptor(
            kind: .captureCurrentPage,
            title: "Capture Page",
            systemImageName: "camera.viewfinder",
            placeholderValue: "Current page",
            requiresConfiguration: true,
            hidesSensitiveContentWhenLocked: true,
            requiresAuthenticationForSensitiveAction: true,
            usesSymbolAnimationForStateChange: true,
            opensAppDirectlyToRelatedContent: true,
            promptsForConfigurationWhenAdded: true
        )
    ]

    public static var containsOnlyGlanceableControls: Bool {
        controls.allSatisfy { control in
            !control.title.isEmpty
                && !control.systemImageName.isEmpty
                && !control.placeholderValue.isEmpty
                && control.benefitsWithoutLaunchingApp
                && control.canBeReconfigured
        }
    }

    public static var allSensitiveControlsAreProtected: Bool {
        controls.allSatisfy { control in
            guard control.requiresAuthenticationForSensitiveAction else {
                return control.hidesSensitiveContentWhenLocked
            }
            return control.hidesSensitiveContentWhenLocked && control.promptsForConfigurationWhenAdded
        }
    }
}

public enum HiveLiveActivityKind: String, Codable, CaseIterable, Sendable {
    case importSession
    case synthesisSession
}

public struct HiveLiveActivityDescriptor: Codable, Hashable, Sendable {
    public var kind: HiveLiveActivityKind
    public var title: String
    public var hasDefinedBeginningAndEnd: Bool
    public var maximumDurationHours: Int
    public var compactPresentationShowsDynamicInfo: Bool
    public var usesSingleActivityForMultipleRelatedEvents: Bool
    public var avoidsDuplicatePushNotifications: Bool
    public var opensRelatedDetailsOnTap: Bool
    public var usesDefaultStandByBackground: Bool
    public var animatesOnlyChangedElements: Bool
    public var lockScreenMinimumMargin: Int
    public var maximumCustomActions: Int
    public var hasCompactDynamicTextOrSymbol: Bool
    public var hasExplicitEndState: Bool

    public init(
        kind: HiveLiveActivityKind,
        title: String,
        hasDefinedBeginningAndEnd: Bool = true,
        maximumDurationHours: Int = 8,
        compactPresentationShowsDynamicInfo: Bool = true,
        usesSingleActivityForMultipleRelatedEvents: Bool = true,
        avoidsDuplicatePushNotifications: Bool = true,
        opensRelatedDetailsOnTap: Bool = true,
        usesDefaultStandByBackground: Bool = true,
        animatesOnlyChangedElements: Bool = true,
        lockScreenMinimumMargin: Int = 14,
        maximumCustomActions: Int = 2,
        hasCompactDynamicTextOrSymbol: Bool = true,
        hasExplicitEndState: Bool = true
    ) {
        self.kind = kind
        self.title = title
        self.hasDefinedBeginningAndEnd = hasDefinedBeginningAndEnd
        self.maximumDurationHours = maximumDurationHours
        self.compactPresentationShowsDynamicInfo = compactPresentationShowsDynamicInfo
        self.usesSingleActivityForMultipleRelatedEvents = usesSingleActivityForMultipleRelatedEvents
        self.avoidsDuplicatePushNotifications = avoidsDuplicatePushNotifications
        self.opensRelatedDetailsOnTap = opensRelatedDetailsOnTap
        self.usesDefaultStandByBackground = usesDefaultStandByBackground
        self.animatesOnlyChangedElements = animatesOnlyChangedElements
        self.lockScreenMinimumMargin = lockScreenMinimumMargin
        self.maximumCustomActions = maximumCustomActions
        self.hasCompactDynamicTextOrSymbol = hasCompactDynamicTextOrSymbol
        self.hasExplicitEndState = hasExplicitEndState
    }
}

public enum HiveLiveActivityCatalog {
    public static let activities: [HiveLiveActivityDescriptor] = [
        HiveLiveActivityDescriptor(kind: .importSession, title: "Adding sources"),
        HiveLiveActivityDescriptor(kind: .synthesisSession, title: "Reviewing memory")
    ]

    public static var allActivitiesAreBoundedAndGlanceable: Bool {
        activities.allSatisfy { activity in
            activity.hasDefinedBeginningAndEnd
                && activity.hasExplicitEndState
                && activity.maximumDurationHours <= 8
                && activity.compactPresentationShowsDynamicInfo
                && activity.hasCompactDynamicTextOrSymbol
                && activity.lockScreenMinimumMargin >= 14
                && activity.maximumCustomActions <= 4
                && activity.avoidsDuplicatePushNotifications
                && activity.animatesOnlyChangedElements
                && activity.opensRelatedDetailsOnTap
        }
    }
}

public struct HiveNotificationExperiencePolicy: Codable, Hashable, Sendable {
    public var requiresPermissionBeforeSending: Bool
    public var usesAlertsForErrorsInsteadOfNotifications: Bool
    public var avoidsInstructionOnlyNotifications: Bool
    public var updatesBadgesWhenOpened: Bool
    public var soundIsSupplementalOnly: Bool
    public var hidesPrivateContentInWatchShortLooks: Bool
    public var maximumCustomActions: Int
    public var keepsLockScreenContentNonSensitive: Bool
    public var avoidsDuplicateLiveActivityUpdates: Bool
    public var usesShortProfessionalSounds: Bool

    public init(
        requiresPermissionBeforeSending: Bool = true,
        usesAlertsForErrorsInsteadOfNotifications: Bool = true,
        avoidsInstructionOnlyNotifications: Bool = true,
        updatesBadgesWhenOpened: Bool = true,
        soundIsSupplementalOnly: Bool = true,
        hidesPrivateContentInWatchShortLooks: Bool = true,
        maximumCustomActions: Int = 4,
        keepsLockScreenContentNonSensitive: Bool = true,
        avoidsDuplicateLiveActivityUpdates: Bool = true,
        usesShortProfessionalSounds: Bool = true
    ) {
        self.requiresPermissionBeforeSending = requiresPermissionBeforeSending
        self.usesAlertsForErrorsInsteadOfNotifications = usesAlertsForErrorsInsteadOfNotifications
        self.avoidsInstructionOnlyNotifications = avoidsInstructionOnlyNotifications
        self.updatesBadgesWhenOpened = updatesBadgesWhenOpened
        self.soundIsSupplementalOnly = soundIsSupplementalOnly
        self.hidesPrivateContentInWatchShortLooks = hidesPrivateContentInWatchShortLooks
        self.maximumCustomActions = maximumCustomActions
        self.keepsLockScreenContentNonSensitive = keepsLockScreenContentNonSensitive
        self.avoidsDuplicateLiveActivityUpdates = avoidsDuplicateLiveActivityUpdates
        self.usesShortProfessionalSounds = usesShortProfessionalSounds
    }

    public var followsEfficiencyGuidance: Bool {
        requiresPermissionBeforeSending
            && usesAlertsForErrorsInsteadOfNotifications
            && avoidsInstructionOnlyNotifications
            && updatesBadgesWhenOpened
            && soundIsSupplementalOnly
            && hidesPrivateContentInWatchShortLooks
            && maximumCustomActions <= 4
            && keepsLockScreenContentNonSensitive
            && avoidsDuplicateLiveActivityUpdates
            && usesShortProfessionalSounds
    }
}

public enum HiveSystemExperiencePolicy {
    public static let notifications = HiveNotificationExperiencePolicy()
}
