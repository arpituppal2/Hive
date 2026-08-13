//
//  BrowserState+Permissions.swift
//  Hive
//
//  Site-permission flow (Chrome parity): CEF permission requests are mapped
//  onto HiveCore's durable per-site decision model (SitePermissionPolicy),
//  auto-resolved from stored grants, or surfaced as a Chrome-style banner
//  prompt when the user must decide. Private tabs always prompt and their
//  answers are never persisted.
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - Permission kind mapping

/// Maps CEF permission classes onto HiveCore's durable per-site kinds and the
/// banner's display surface. Benign classes (clipboard, storage access) are
/// auto-granted; exotic classes never seen by the durable model default to
/// deny (matching the previous always-deny behavior, never an auto-grant).
enum PermissionKindMapper {

    /// Every CEF permission class, ordered for stable banner display.
    static let allKinds: [CefPermissionKind] = [
        .camera, .microphone, .geolocation, .notifications, .clipboard,
        .midi, .pointerLock, .storageAccess, .sensors, .windowManagement,
        .downloads, .other
    ]

    /// The bits actually present in a combined request, in stable order.
    static func kinds(in set: CefPermissionKind) -> [CefPermissionKind] {
        allKinds.filter { set.contains($0) }
    }

    /// Maps a CEF class to a durable per-site decision kind, if one exists.
    static func mappedKind(for kind: CefPermissionKind) -> SitePermissionKind? {
        switch kind {
        case .camera: return .camera
        case .microphone: return .microphone
        case .geolocation: return .location
        case .notifications: return .notifications
        case .downloads: return .automaticDownloads
        default: return nil
        }
    }

    /// Benign classes granted without a prompt (they carry no private data).
    static func isBenign(_ kind: CefPermissionKind) -> Bool {
        kind == .clipboard || kind == .storageAccess
    }

    /// SF Symbol for a CEF class (banner + settings rows).
    static func iconName(for kind: CefPermissionKind) -> String {
        switch kind {
        case .camera: return "camera.fill"
        case .microphone: return "mic.fill"
        case .geolocation: return "location.fill"
        case .notifications: return "bell.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .storageAccess: return "externaldrive.fill"
        case .pointerLock: return "cursorarrow.click.2"
        case .midi: return "pianokeys"
        case .sensors: return "gyroscope"
        case .windowManagement: return "macwindow"
        default: return "hand.raised.fill"
        }
    }

    /// Human label for a CEF class (banner + settings rows).
    static func displayName(for kind: CefPermissionKind) -> String {
        switch kind {
        case .camera: return "Camera"
        case .microphone: return "Microphone"
        case .geolocation: return "Location"
        case .notifications: return "Notifications"
        case .downloads: return "Automatic downloads"
        case .clipboard: return "Clipboard"
        case .storageAccess: return "Storage access"
        case .pointerLock: return "Pointer lock"
        case .midi: return "MIDI devices"
        case .sensors: return "Motion sensors"
        case .windowManagement: return "Window management"
        default: return "Additional capability"
        }
    }
}

// MARK: - SitePermissionKind display surface

extension SitePermissionKind {
    /// SF Symbol for the site-security settings rows.
    var iconName: String {
        switch self {
        case .camera: return "camera.fill"
        case .microphone: return "mic.fill"
        case .location: return "location.fill"
        case .notifications: return "bell.fill"
        case .popups: return "square.on.square"
        case .automaticDownloads: return "arrow.down.circle.fill"
        }
    }

    /// Human label for the site-security settings rows.
    var displayName: String {
        switch self {
        case .camera: return "Camera"
        case .microphone: return "Microphone"
        case .location: return "Location"
        case .notifications: return "Notifications"
        case .popups: return "Pop-ups"
        case .automaticDownloads: return "Automatic Downloads"
        }
    }
}

// MARK: - Pending prompt model

/// One permission request awaiting a user decision, shown in the
/// Chrome-style banner. Owns the retained CEF callback: dropping the entry
/// (resolve, dismiss, tab close, navigation) releases it via deinit.
struct PendingPermissionRequest: Identifiable {
    let id: UUID
    /// CEF's prompt id for matching `on_dismiss_permission_prompt`; 0 for
    /// media-access requests (which have no dismissal notification).
    let promptID: UInt64
    /// Full origin string as reported by CEF.
    let origin: String
    /// Normalized host shown in the banner and used for durable decisions.
    let host: String
    /// The requested permission classes (drives banner icons/labels).
    let kinds: CefPermissionKind
    /// Classes that map to durable per-site decisions (persisted on resolve).
    let mappedKinds: [SitePermissionKind]
    /// The tab that requested permission (used for navigation/close cleanup).
    let tabID: String
    /// Private-tab requests are never persisted and always prompt.
    let isPrivate: Bool
    let receivedAt: Date
    /// Retained CEF callback; resolve or drop to release the CEF reference.
    let callback: CefPermissionPromptCallback
}

// MARK: - BrowserState + Permissions

@MainActor
extension BrowserState {

    /// The host a CEF origin string represents. Origins arrive as URLs
    /// (``https://example.com``); tolerate bare hosts defensively.
    static func hostFromOrigin(_ origin: String) -> String {
        if let url = URL(string: origin), let host = url.host {
            return SitePermissionPolicy.normalizedHost(host)
        }
        return SitePermissionPolicy.normalizedHost(origin)
    }

    /// Routes one CEF permission request through the durable policy. Returns
    /// `true` always — Hive owns permission resolution (no CEF default UI).
    /// Benign classes are granted, exotic classes denied, stored decisions
    /// auto-resolved, and everything unresolved surfaces as a banner prompt.
    func handlePermissionRequest(
        _ request: CefPermissionRequest,
        callback: CefPermissionPromptCallback,
        tabID: String,
        isPrivate: Bool
    ) -> Bool {
        let kinds = PermissionKindMapper.kinds(in: request.kinds)
        var mappedKinds: [SitePermissionKind] = []
        var hasBenign = false
        var hasExotic = false
        for kind in kinds {
            if let mapped = PermissionKindMapper.mappedKind(for: kind) {
                mappedKinds.append(mapped)
            } else if PermissionKindMapper.isBenign(kind) {
                hasBenign = true
            } else {
                hasExotic = true
            }
        }

        // Exotic/unmapped classes are denied conservatively — the previous
        // always-deny behavior, never an auto-grant of an unknown class.
        if hasExotic {
            callback.resolve(allow: false)
            return true
        }

        // Only benign classes were requested — grant them quietly.
        if mappedKinds.isEmpty {
            callback.resolve(allow: hasBenign)
            return true
        }

        switch SitePermissionPolicy.resolution(
            requestedKinds: mappedKinds,
            permissions: sitePermissions,
            isPrivate: isPrivate
        ) {
        case .allow:
            callback.resolve(allow: true)
            return true
        case .deny:
            callback.resolve(allow: false)
            return true
        case .prompt:
            let prompt = PendingPermissionRequest(
                id: UUID(),
                promptID: request.promptID,
                origin: request.origin,
                host: Self.hostFromOrigin(request.origin),
                kinds: request.kinds,
                mappedKinds: mappedKinds,
                tabID: tabID,
                isPrivate: isPrivate,
                receivedAt: Date(),
                callback: callback
            )
            // A site re-requesting while its prompt is still open replaces the
            // stale entry (its CEF callback is released) instead of stacking a
            // duplicate. The queue is also capped so a pathological flood can
            // never grow the banner backlog without bound.
            if let existing = pendingPermissionRequests.firstIndex(where: {
                $0.host == prompt.host && $0.mappedKinds == prompt.mappedKinds
            }) {
                pendingPermissionRequests.remove(at: existing)
            }
            if pendingPermissionRequests.count >= 4 {
                pendingPermissionRequests.removeFirst()
            }
            pendingPermissionRequests.append(prompt)
            return true
        }
    }

    /// Resolves the front prompt from the banner. The decision is persisted
    /// per kind for non-private tabs; private decisions are session-only.
    func resolvePermissionPrompt(allow: Bool) {
        guard let prompt = pendingPermissionRequests.first else { return }
        pendingPermissionRequests.removeFirst()
        prompt.callback.resolve(allow: allow)
        if !prompt.isPrivate && !prompt.mappedKinds.isEmpty {
            var updated = sitePermissions
            for kind in prompt.mappedKinds {
                updated = SitePermissionPolicy.applying(
                    allow ? .allow : .deny,
                    forHost: prompt.host,
                    kind: kind,
                    to: updated,
                    isPrivate: false
                )
            }
            sitePermissions = updated
        }
    }

    /// Drops a pending prompt that CEF dismissed (page closed or navigated
    /// away). Releasing the entry frees the retained callback.
    func dismissPermissionPrompt(promptID: UInt64) {
        guard promptID != 0 else { return }
        pendingPermissionRequests.removeAll { $0.promptID == promptID }
    }

    /// Drops every pending prompt belonging to a tab (tab closed, or the
    /// page navigated away — media requests have no CEF dismissal notice).
    func dropPendingPermissionPrompts(forTabID tabID: String) {
        pendingPermissionRequests.removeAll { $0.tabID == tabID }
    }

    /// Records a per-site decision from the site-security popover. Private
    /// tabs cannot write durable entries (the policy applies a no-op).
    func setSitePermission(
        _ state: SitePermissionState,
        forHost host: String,
        kind: SitePermissionKind,
        isPrivate: Bool
    ) {
        sitePermissions = SitePermissionPolicy.applying(
            state,
            forHost: host,
            kind: kind,
            to: sitePermissions,
            isPrivate: isPrivate
        )
    }

    /// Removes every stored decision for a host (site-settings reset).
    func resetSitePermissions(forHost host: String) {
        var updated = sitePermissions
        updated.removeAll(forHost: SitePermissionPolicy.normalizedHost(host))
        sitePermissions = updated
    }

    /// The effective stored decision for a host, honoring private browsing.
    func permissionState(
        forHost host: String,
        kind: SitePermissionKind,
        isPrivate: Bool
    ) -> SitePermissionState {
        SitePermissionPolicy.state(
            forHost: host,
            kind: kind,
            permissions: sitePermissions,
            isPrivate: isPrivate
        )
    }
}
