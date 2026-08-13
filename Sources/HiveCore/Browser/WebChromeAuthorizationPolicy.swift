import Foundation

/// Pure authorization rules shared by the native bridge and contract tests.
///
/// The vendored CEF bridge does not provide browser/frame identity, so a
/// per-session token is the only trustworthy audience boundary available to
/// privileged actions. Per-tab start pages may use their own token for the
/// read-only start-data endpoint, but they must never invoke mutations.
public enum WebChromeAuthorizationPolicy: Sendable {
    public static func allowsPrivilegedAction(token: String, shellToken: String) -> Bool {
        !token.isEmpty && token == shellToken
    }

    public static func audience(
        token: String,
        shellToken: String,
        normalToken: String,
        privateToken: String
    ) -> Audience? {
        if token == shellToken { return .shell }
        if token == normalToken { return .normalStart }
        if token == privateToken { return .privateStart }
        return nil
    }

    public enum Audience: Equatable, Sendable {
        case shell
        case normalStart
        case privateStart
    }
}
