import Foundation

// MARK: - SitePermissionPolicy

/// Pure policy helpers shared by the browser runtime and tests. WebKit owns the
/// actual OS permission prompt; this type decides whether Hive should consult,
/// bypass, or persist a site-level decision before calling WebKit.
public enum SitePermissionPolicy {

    /// Canonicalizes a host for permission lookup without retaining a URL or path.
    /// Host permissions are case-insensitive and a trailing DNS dot is equivalent
    /// to the undotted form. `www.` is intentionally retained: it can represent a
    /// distinct origin and silently merging it would broaden a user's grant.
    public static func normalizedHost(_ host: String) -> String {
        var value = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while value.hasSuffix(".") { value.removeLast() }
        return value
    }

    /// Resolves a stored decision. Private tabs never inherit or write durable
    /// decisions: they always return `.ask`, keeping the ephemeral browsing mode
    /// conservative and preventing a normal-profile grant from widening into a
    /// private session.
    public static func state(
        forHost host: String,
        kind: SitePermissionKind,
        permissions: [SitePermission],
        isPrivate: Bool
    ) -> SitePermissionState {
        guard !isPrivate else { return .ask }
        let normalized = normalizedHost(host)
        return permissions.first {
            normalizedHost($0.host) == normalized && $0.kind == kind
        }?.state ?? .ask
    }

    /// Records a decision in a copied permission list. Private tabs return the
    /// original list unchanged, so callers can use this helper without a second
    /// privacy guard and without accidentally persisting a private grant.
    public static func applying(
        _ state: SitePermissionState,
        forHost host: String,
        kind: SitePermissionKind,
        to permissions: [SitePermission],
        isPrivate: Bool
    ) -> [SitePermission] {
        guard !isPrivate else { return permissions }
        var updated = permissions
        updated.setPermission(host: normalizedHost(host), kind: kind, state: state)
        return updated
    }

    /// User-activated links are intentional navigation and remain usable even when
    /// script-created popups are denied. For script-created windows, `.deny` blocks
    /// the request; `.ask` preserves the existing tab-routing behavior for now.
    public static func allowsNewWindow(
        navigationType: NavigationIntent,
        permission: SitePermissionState
    ) -> Bool {
        if navigationType == .userActivatedLink { return true }
        return permission != .deny
    }

    public enum NavigationIntent: Sendable, Equatable {
        case userActivatedLink
        case scriptOrUnknown
    }
}
