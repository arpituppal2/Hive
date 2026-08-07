import Foundation
import WebKit
import HiveCore

// MARK: - WebViewAutofillController
//
// Manages credential autofill for WKWebView. When a page finishes loading,
// the controller queries the KeychainPasswordStore for credentials matching
// the current domain and injects them into login forms via JavaScript.
//
// The user must explicitly approve autofill for each domain (permission is
// stored in ChromeUserPrefs.sitePermissions). Without approval, credentials
// are never injected — the user sees a prompt in the omnibar instead.

@MainActor
public final class WebViewAutofillController {

    /// The credential store to query. nil = autofill disabled.
    private let passwordStore: KeychainPasswordStore?

    /// Whether the user has globally enabled password autofill.
    public var isAutofillEnabled: Bool = true

    public init(passwordStore: KeychainPasswordStore?) {
        self.passwordStore = passwordStore
    }

    // MARK: - Public API

    /// Called by WebViewContainer.Coordinator when a page finishes loading.
    /// Queries credentials for the given host and, if the user has granted
    /// autofill permission for this domain, injects them.
    ///
    /// - Parameters:
    ///   - webView: The webview to inject credentials into.
    ///   - host: The host (domain) of the loaded page.
    ///   - hasAutofillPermission: Whether the user has granted autofill for this domain.
    /// - Returns: The number of credentials injected (0 if none found or not permitted).
    @discardableResult
    public func autofillIfPermitted(in webView: WKWebView,
                                    host: String,
                                    hasAutofillPermission: Bool) async -> Int {
        guard isAutofillEnabled,
              hasAutofillPermission,
              let store = passwordStore else { return 0 }

        guard let credentials = try? await store.getAll(forDomain: host),
              !credentials.isEmpty else { return 0 }

        return await injectCredentials(credentials, into: webView)
    }

    /// Inject a list of credentials into the webview's login forms via JavaScript.
    /// Returns the number of forms that were successfully filled.
    @discardableResult
    public func injectCredentials(_ credentials: [Credential],
                                   into webView: WKWebView) async -> Int {
        guard !credentials.isEmpty else { return 0 }

        // Build a JS array of {username, password} objects.
        let jsonArray = credentials.map { cred in
            let escapedUser = cred.username.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "'", with: "\\'")
            let escapedPass = cred.password.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "'", with: "\\'")
            return "{username:'\(escapedUser)',password:'\(escapedPass)'}"
        }.joined(separator: ",")

        let js = """
        (function() {
            var creds = [\(jsonArray)];
            var filled = 0;
            // Find all forms on the page
            var forms = document.querySelectorAll('form');
            for (var f = 0; f < forms.length; f++) {
                var form = forms[f];
                var usernameField = null;
                var passwordField = null;
                // Find username field (input[type=email], input[type=text], input[name*=user])
                var inputs = form.querySelectorAll('input');
                for (var i = 0; i < inputs.length; i++) {
                    var inp = inputs[i];
                    var t = (inp.type || '').toLowerCase();
                    var n = (inp.name || '').toLowerCase();
                    var id = (inp.id || '').toLowerCase();
                    var autocomplete = (inp.autocomplete || '').toLowerCase();
                    if (t === 'password') {
                        passwordField = inp;
                    } else if (!usernameField && (t === 'email' || t === 'text' || autocomplete === 'username' ||
                           n.indexOf('user') !== -1 || n.indexOf('email') !== -1 ||
                           id.indexOf('user') !== -1 || id.indexOf('email') !== -1)) {
                        usernameField = inp;
                    }
                }
                // Fill first credential that matches
                if (usernameField && passwordField) {
                    usernameField.value = creds[0].username;
                    passwordField.value = creds[0].password;
                    // Fire input events so JS frameworks detect the change
                    usernameField.dispatchEvent(new Event('input', {bubbles:true}));
                    usernameField.dispatchEvent(new Event('change', {bubbles:true}));
                    passwordField.dispatchEvent(new Event('input', {bubbles:true}));
                    passwordField.dispatchEvent(new Event('change', {bubbles:true}));
                    filled++;
                }
            }
            return filled;
        })();
        """

        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(js) { result, error in
                if let count = result as? Int {
                    continuation.resume(returning: count)
                } else {
                    continuation.resume(returning: 0)
                }
            }
        }
    }

    /// Shows a credential picker when multiple credentials exist for a domain.
    /// Returns the selected credential, or nil if the user cancelled.
    public func pickCredential(from credentials: [Credential],
                                forHost host: String) async -> Credential? {
        guard credentials.count > 1 else { return credentials.first }
        // For now, return the first credential. A proper picker UI (NSAlert or
        // a native popover) is the next slice.
        return credentials.first
    }
}
