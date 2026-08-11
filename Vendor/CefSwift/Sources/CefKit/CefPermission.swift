import CCef
import Foundation

/// A class of permission a page can request. Maps the
/// `cef_permission_request_types_t` and `cef_media_access_permission_types_t`
/// bit flags onto a Swift `OptionSet`.
public struct CefPermissionKind: OptionSet, Sendable, Hashable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let camera = CefPermissionKind(rawValue: 1 << 0)
    public static let microphone = CefPermissionKind(rawValue: 1 << 1)
    public static let geolocation = CefPermissionKind(rawValue: 1 << 2)
    public static let notifications = CefPermissionKind(rawValue: 1 << 3)
    public static let clipboard = CefPermissionKind(rawValue: 1 << 4)
    public static let midi = CefPermissionKind(rawValue: 1 << 5)
    public static let pointerLock = CefPermissionKind(rawValue: 1 << 6)
    public static let storageAccess = CefPermissionKind(rawValue: 1 << 7)
    public static let sensors = CefPermissionKind(rawValue: 1 << 8)
    public static let windowManagement = CefPermissionKind(rawValue: 1 << 9)
    public static let downloads = CefPermissionKind(rawValue: 1 << 10)
    /// Any requested permission not mapped to a more specific case above.
    public static let other = CefPermissionKind(rawValue: 1 << 31)

    /// Maps `cef_permission_request_types_t` flags (used by
    /// `on_show_permission_prompt`).
    static func fromRequestTypes(_ value: UInt32) -> CefPermissionKind {
        var kinds: CefPermissionKind = []
        func test(_ cef: cef_permission_request_types_t, _ kind: CefPermissionKind) {
            if value & UInt32(cef.rawValue) != 0 { kinds.insert(kind) }
        }
        test(CEF_PERMISSION_TYPE_CAMERA_STREAM, .camera)
        test(CEF_PERMISSION_TYPE_CAMERA_PAN_TILT_ZOOM, .camera)
        test(CEF_PERMISSION_TYPE_MIC_STREAM, .microphone)
        test(CEF_PERMISSION_TYPE_GEOLOCATION, .geolocation)
        test(CEF_PERMISSION_TYPE_NOTIFICATIONS, .notifications)
        test(CEF_PERMISSION_TYPE_CLIPBOARD, .clipboard)
        test(CEF_PERMISSION_TYPE_MIDI_SYSEX, .midi)
        test(CEF_PERMISSION_TYPE_POINTER_LOCK, .pointerLock)
        test(CEF_PERMISSION_TYPE_STORAGE_ACCESS, .storageAccess)
        test(CEF_PERMISSION_TYPE_TOP_LEVEL_STORAGE_ACCESS, .storageAccess)
        test(CEF_PERMISSION_TYPE_SENSORS, .sensors)
        test(CEF_PERMISSION_TYPE_WINDOW_MANAGEMENT, .windowManagement)
        test(CEF_PERMISSION_TYPE_MULTIPLE_DOWNLOADS, .downloads)
        // Anything requested but unmapped: surface as .other so the app can
        // make an informed allow/deny decision rather than silently dropping.
        let mappedMask: UInt32 =
            UInt32(CEF_PERMISSION_TYPE_CAMERA_STREAM.rawValue)
            | UInt32(CEF_PERMISSION_TYPE_CAMERA_PAN_TILT_ZOOM.rawValue)
            | UInt32(CEF_PERMISSION_TYPE_MIC_STREAM.rawValue)
            | UInt32(CEF_PERMISSION_TYPE_GEOLOCATION.rawValue)
            | UInt32(CEF_PERMISSION_TYPE_NOTIFICATIONS.rawValue)
            | UInt32(CEF_PERMISSION_TYPE_CLIPBOARD.rawValue)
            | UInt32(CEF_PERMISSION_TYPE_MIDI_SYSEX.rawValue)
            | UInt32(CEF_PERMISSION_TYPE_POINTER_LOCK.rawValue)
            | UInt32(CEF_PERMISSION_TYPE_STORAGE_ACCESS.rawValue)
            | UInt32(CEF_PERMISSION_TYPE_TOP_LEVEL_STORAGE_ACCESS.rawValue)
            | UInt32(CEF_PERMISSION_TYPE_SENSORS.rawValue)
            | UInt32(CEF_PERMISSION_TYPE_WINDOW_MANAGEMENT.rawValue)
            | UInt32(CEF_PERMISSION_TYPE_MULTIPLE_DOWNLOADS.rawValue)
        if value & ~mappedMask != 0 { kinds.insert(.other) }
        return kinds
    }

    /// Maps `cef_media_access_permission_types_t` flags (used by
    /// `on_request_media_access_permission`).
    static func fromMediaTypes(_ value: UInt32) -> CefPermissionKind {
        var kinds: CefPermissionKind = []
        if value & UInt32(CEF_MEDIA_PERMISSION_DEVICE_AUDIO_CAPTURE.rawValue) != 0 { kinds.insert(.microphone) }
        if value & UInt32(CEF_MEDIA_PERMISSION_DEVICE_VIDEO_CAPTURE.rawValue) != 0 { kinds.insert(.camera) }
        if value & UInt32(CEF_MEDIA_PERMISSION_DESKTOP_AUDIO_CAPTURE.rawValue) != 0 { kinds.insert(.microphone) }
        if value & UInt32(CEF_MEDIA_PERMISSION_DESKTOP_VIDEO_CAPTURE.rawValue) != 0 { kinds.insert(.camera) }
        return kinds
    }

    /// Re-encodes media kinds back to `cef_media_access_permission_types_t`
    /// flags for the allow path (CEF requires the allowed mask to be a subset
    /// of the requested mask).
    func mediaMask(within requested: UInt32) -> UInt32 {
        var mask: UInt32 = 0
        if contains(.microphone) {
            mask |= UInt32(CEF_MEDIA_PERMISSION_DEVICE_AUDIO_CAPTURE.rawValue)
            mask |= UInt32(CEF_MEDIA_PERMISSION_DESKTOP_AUDIO_CAPTURE.rawValue)
        }
        if contains(.camera) {
            mask |= UInt32(CEF_MEDIA_PERMISSION_DEVICE_VIDEO_CAPTURE.rawValue)
            mask |= UInt32(CEF_MEDIA_PERMISSION_DESKTOP_VIDEO_CAPTURE.rawValue)
        }
        return mask & requested
    }
}

/// How to resolve a ``CefPermissionRequest``.
public enum CefPermissionDecision: Sendable, Equatable {
    /// Grant the request.
    case allow
    /// Refuse the request.
    case deny
    /// Dismiss without a decision (the page may ask again).
    case dismiss
}

/// A permission request delivered to
/// ``CefBrowserDelegate/browser(_:requestsPermission:)``.
public struct CefPermissionRequest: Sendable, Equatable {
    /// The permission classes requested (may combine several).
    public var kinds: CefPermissionKind
    /// The origin (scheme + host) requesting permission.
    public var origin: String
    /// CEF's prompt identifier from `on_show_permission_prompt`, used to match
    /// the later `on_dismiss_permission_prompt` notification. 0 for media
    /// access requests, which have no dismissal notification.
    public var promptID: UInt64

    public init(kinds: CefPermissionKind, origin: String, promptID: UInt64 = 0) {
        self.kinds = kinds
        self.origin = origin
        self.promptID = promptID
    }
}

/// Resolves an in-flight permission request. Call exactly one of
/// ``resolve(allow:)`` or ``dismiss()`` — either synchronously from the
/// delegate or later from your own UI (the same retained-callback pattern as
/// ``CefJSDialogCallback``).
///
/// The wrapper owns the CEF callback's +1 reference: it is released on the
/// first resolution (or in `deinit` if the app never resolves it, e.g. when
/// CEF dismisses the prompt because the page navigated away).
public final class CefPermissionPromptCallback: @unchecked Sendable {
    private enum Backing {
        case prompt(UnsafeMutablePointer<cef_permission_prompt_callback_t>)
        case media(UnsafeMutablePointer<cef_media_access_callback_t>, requestedMask: UInt32)
    }

    private let backing: Backing
    private var consumed = false

    /// Takes ownership of a +1 `cef_permission_prompt_callback_t` reference
    /// (from `on_show_permission_prompt`).
    init(prompt: UnsafeMutablePointer<cef_permission_prompt_callback_t>) {
        backing = .prompt(prompt)
    }

    /// Takes ownership of a +1 `cef_media_access_callback_t` reference (from
    /// `on_request_media_access_permission`), remembering the requested mask
    /// so the allow path can pass it back unchanged.
    init(media: UnsafeMutablePointer<cef_media_access_callback_t>, requestedMask: UInt32) {
        backing = .media(media, requestedMask: requestedMask)
    }

    deinit {
        if !consumed {
            releaseBacking()
        }
    }

    private func releaseBacking() {
        switch backing {
        case .prompt(let raw):
            cefRelease(UnsafeMutableRawPointer(raw))
        case .media(let raw, _):
            cefRelease(UnsafeMutableRawPointer(raw))
        }
    }

    /// Grants or refuses the request. For media access the allow path passes
    /// the originally requested mask (CEF requires the allowed mask to be a
    /// subset of the requested mask; granting the full request is therefore
    /// exactly the requested mask).
    public func resolve(allow: Bool) {
        guard !consumed else { return }
        consumed = true
        switch backing {
        case .prompt(let raw):
            let decision: CefPermissionDecision = allow ? .allow : .deny
            raw.pointee.cont?(raw, decision.cefResult)
        case .media(let raw, let requestedMask):
            if allow {
                raw.pointee.cont?(raw, requestedMask)
            } else {
                raw.pointee.cancel?(raw)
            }
        }
        releaseBacking()
    }

    /// Dismisses without a decision (the page may ask again). Maps to
    /// ``CefPermissionDecision/dismiss`` for permission prompts and `cancel`
    /// for media access.
    public func dismiss() {
        guard !consumed else { return }
        consumed = true
        switch backing {
        case .prompt(let raw):
            raw.pointee.cont?(raw, CefPermissionDecision.dismiss.cefResult)
        case .media(let raw, _):
            raw.pointee.cancel?(raw)
        }
        releaseBacking()
    }
}

extension CefPermissionDecision {
    /// Maps to the `cef_permission_request_result_t` continue value.
    var cefResult: cef_permission_request_result_t {
        switch self {
        case .allow: return CEF_PERMISSION_RESULT_ACCEPT
        case .deny: return CEF_PERMISSION_RESULT_DENY
        case .dismiss: return CEF_PERMISSION_RESULT_DISMISS
        }
    }
}
