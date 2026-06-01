import Foundation
import SwiftUI
import HiveCore
import HiveDesignSystem

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif
#if os(macOS) && canImport(Security)
import Security
#endif
#if os(macOS) && canImport(AppKit)
import AppKit
#endif
#if os(iOS) && canImport(UIKit)
import UIKit
#endif

#if canImport(AuthenticationServices)
@MainActor
private final class HiveGoogleSignInCoordinator: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func signIn() async throws -> HiveGoogleAccount {
        let configuration = try HiveGoogleSignInConfiguration.current()
        let verifier = Self.makeCodeVerifier()
        let state = Self.makeCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)
        let authorizationURL = try configuration.authorizationURL(codeChallenge: challenge, state: state)

        let callbackURL: URL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: configuration.callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: HiveGoogleSignInError.missingCallback)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            if !session.start() {
                continuation.resume(throwing: HiveGoogleSignInError.couldNotStart)
            }
        }
        session = nil

        let code = try Self.authorizationCode(from: callbackURL, expectedState: state)
        let token = try await configuration.exchange(code: code, verifier: verifier)
        let profile = try await configuration.profile(from: token)
        return HiveGoogleAccount(
            googleUserID: profile.subject,
            displayName: profile.name,
            email: profile.email,
            authorizedAt: Date()
        )
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
        #if os(macOS) && canImport(AppKit)
            return NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? NSWindow()
        #elseif os(iOS) && canImport(UIKit)
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? UIWindow()
        #else
            return ASPresentationAnchor()
        #endif
        }
    }

    private static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        #if canImport(Security)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess {
            return Data(bytes).base64URLEncodedString()
        }
        #endif
        return "\(UUID().uuidString)\(UUID().uuidString)"
            .replacingOccurrences(of: "-", with: "")
    }

    private static func codeChallenge(for verifier: String) -> String {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
        #else
        return verifier
        #endif
    }

    private static func authorizationCode(from url: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw HiveGoogleSignInError.invalidCallback
        }
        let items = components.queryItems ?? []
        if let error = items.first(where: { $0.name == "error" })?.value {
            throw HiveGoogleSignInError.authorizationRejected(error)
        }
        guard items.first(where: { $0.name == "state" })?.value == expectedState else {
            throw HiveGoogleSignInError.stateMismatch
        }
        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw HiveGoogleSignInError.missingAuthorizationCode
        }
        return code
    }
}

private struct HiveGoogleSignInConfiguration {
    var clientID: String
    var reversedClientID: String

    var callbackScheme: String { reversedClientID }
    var redirectURI: String { "\(reversedClientID):/oauth2redirect" }

    static func current(bundle: Bundle = .main) throws -> HiveGoogleSignInConfiguration {
        let environment = ProcessInfo.processInfo.environment
        let clientID = (bundle.object(forInfoDictionaryKey: "GIDClientID") as? String)
            ?? environment["HIVE_GOOGLE_CLIENT_ID"]
        let reversedClientID = (bundle.object(forInfoDictionaryKey: "HiveGoogleReversedClientID") as? String)
            ?? environment["HIVE_GOOGLE_REVERSED_CLIENT_ID"]
        guard let clientID = cleaned(clientID), let reversedClientID = cleaned(reversedClientID) else {
            throw HiveGoogleSignInError.missingConfiguration
        }
        return HiveGoogleSignInConfiguration(clientID: clientID, reversedClientID: reversedClientID)
    }

    func authorizationURL(codeChallenge: String, state: String) throws -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "prompt", value: "select_account")
        ]
        guard let url = components?.url else { throw HiveGoogleSignInError.missingConfiguration }
        return url
    }

    func exchange(code: String, verifier: String) async throws -> HiveGoogleTokenResponse {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            throw HiveGoogleSignInError.missingConfiguration
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: verifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI)
        ]
        var body = URLComponents()
        body.queryItems = bodyItems
        request.httpBody = body.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw HiveGoogleSignInError.tokenExchangeFailed
        }
        return try JSONDecoder().decode(HiveGoogleTokenResponse.self, from: data)
    }

    func profile(from token: HiveGoogleTokenResponse) async throws -> HiveGoogleProfile {
        if let idToken = token.idToken,
           let profile = HiveGoogleProfile(idToken: idToken) {
            return profile
        }
        guard let accessToken = token.accessToken,
              let url = URL(string: "https://openidconnect.googleapis.com/v1/userinfo") else {
            throw HiveGoogleSignInError.missingProfile
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw HiveGoogleSignInError.missingProfile
        }
        return try JSONDecoder().decode(HiveGoogleProfile.self, from: data)
    }

    private static func cleaned(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct HiveGoogleTokenResponse: Decodable {
    var accessToken: String?
    var idToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
    }
}

private struct HiveGoogleProfile: Decodable {
    var subject: String
    var email: String?
    var name: String?

    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case email
        case name
    }

    init(subject: String, email: String?, name: String?) {
        self.subject = subject
        self.email = email
        self.name = name
    }

    init?(idToken: String) {
        let separator = Character(UnicodeScalar(46)!)
        let parts = idToken.split(separator: separator)
        guard parts.count >= 2,
              let data = Data(base64URLEncoded: String(parts[1])),
              let profile = try? JSONDecoder().decode(HiveGoogleProfile.self, from: data) else {
            return nil
        }
        self = profile
    }
}

private enum HiveGoogleSignInError: LocalizedError {
    case missingConfiguration
    case couldNotStart
    case missingCallback
    case invalidCallback
    case stateMismatch
    case missingAuthorizationCode
    case authorizationRejected(String)
    case tokenExchangeFailed
    case missingProfile

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Google sign-in is not configured for this Hive build. Set HIVE_GOOGLE_CLIENT_ID and HIVE_GOOGLE_REVERSED_CLIENT_ID, then rebuild."
        case .couldNotStart:
            return "Hive could not open the Google sign-in window."
        case .missingCallback, .invalidCallback:
            return "Google sign-in did not return a valid response."
        case .stateMismatch:
            return "Google sign-in returned an unexpected session. Try again."
        case .missingAuthorizationCode:
            return "Google did not return an authorization code."
        case .authorizationRejected(let reason):
            return "Google sign-in was canceled or rejected: \(reason)."
        case .tokenExchangeFailed:
            return "Hive could not finish Google sign-in. Check the OAuth client and URL scheme."
        case .missingProfile:
            return "Hive could not read the Google account profile."
        }
    }
}

private extension Data {
    init?(base64URLEncoded value: String) {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - base64.count % 4
        if padding < 4 {
            base64.append(String(repeating: "=", count: padding))
        }
        self.init(base64Encoded: base64)
    }

    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
#endif

public struct HiveAppleAccountSection: View {
    @State private var account: HiveAuthenticatedAccount?
    @State private var statusMessage: String?
    @State private var signInReadinessFailure: String?
    @State private var signInFailed = false
    @Environment(\.colorScheme) private var colorScheme
    #if canImport(AuthenticationServices)
    @StateObject private var googleSignInCoordinator = HiveGoogleSignInCoordinator()
    #endif
    private let onAccountChanged: (HiveAuthenticatedAccount?) -> Void
    private let centered: Bool

    public init(centered: Bool = false, onAccountChanged: @escaping (HiveAuthenticatedAccount?) -> Void = { _ in }) {
        self.centered = centered
        self.onAccountChanged = onAccountChanged
    }

    public var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 12) {
            if let account {
                signedInView(account)
            } else {
                signedOutView
            }
        }
        .onAppear {
            account = HiveAccountStore.load()
            refreshSignInReadiness()
        }
        .accessibilityElement(children: .contain)
    }

    private func signedInView(_ account: HiveAuthenticatedAccount) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                HiveSymbol(account.provider == .apple ? .appleAccount : .googleAccount, size: 18, active: true)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.statusLabel)
                        .font(HiveTypography.chromeAction)
                        .lineLimit(HiveAppleAccountPolicy.statusTextLineLimit)
                    Text(account.displayLabel)
                        .font(HiveTypography.chromeBody)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                        .lineLimit(HiveAppleAccountPolicy.accountIdentifierLineLimit)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .layoutPriority(1)
                Spacer(minLength: 12)
                HiveSymbolButton(.signOut, title: "Sign Out", compact: true) {
                    HiveAppleAccountStore.clear()
                    HiveGoogleAccountStore.clear()
                    HiveAccountStore.clear()
                    HiveGuestAccessStore.clear()
                    self.account = nil
                    onAccountChanged(nil)
                    statusMessage = "Signed out of Hive."
                }
            }
            Text(account.syncAnchorDescription)
                .font(HiveTypography.chromeFootnote)
                .foregroundStyle(HiveColorToken.nectarMuted.color)
                .fixedSize(horizontal: false, vertical: true)
            if account.usesPrivateRelay {
                Text("Hive is using the private relay address you chose with Apple.")
                    .font(HiveTypography.chromeFootnote)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(HiveColorToken.cellSurface.color.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
    }

    private var signedOutView: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 12) {
            Text("Continue with Apple or Google to keep the same Hive identity across your devices.")
                .font(HiveTypography.chromeBody)
                .foregroundStyle(HiveColorToken.nectarMuted.color)
                .multilineTextAlignment(centered ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: HiveSpacing.sm) {
                appleButton
                    .frame(minWidth: CGFloat(HiveAppleAccountPolicy.minimumButtonWidth), minHeight: 46)
                    .frame(maxWidth: centered ? 360 : 280, alignment: centered ? .center : .leading)
                googleButton
                    .frame(minWidth: CGFloat(HiveAppleAccountPolicy.minimumButtonWidth), minHeight: 44)
                    .frame(maxWidth: centered ? 360 : 280, alignment: centered ? .center : .leading)
            }
            .padding(.vertical, max(3, 44 * HiveAppleAccountPolicy.minimumButtonMarginRatio * 0.5))
            if let statusMessage {
                Text(statusMessage)
                    .font(HiveTypography.chromeFootnote)
                    .foregroundStyle(signInFailed ? HiveColorToken.conflict.color : HiveColorToken.nectarMuted.color)
                    .multilineTextAlignment(centered ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Sign in with Apple or Google is required before Hive can open your Field, Colony, Hive graph, or Swarm.")
                .font(HiveTypography.chromeFootnote)
                .foregroundStyle(HiveColorToken.scaffoldFaint.color)
                .multilineTextAlignment(centered ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: centered ? 430 : .infinity, alignment: centered ? .center : .leading)
    }

    @ViewBuilder
    private var googleButton: some View {
        #if canImport(AuthenticationServices)
        Button {
            Task {
                await handleGoogleSignIn()
            }
        } label: {
            HStack(spacing: HiveSpacing.sm) {
                HiveSymbol(.googleAccount, size: 15, active: true)
                    .accessibilityHidden(true)
                Text("Continue with Google")
                    .font(HiveTypography.chromeAction)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(HiveColorToken.nectarText.color)
            .background(HiveColorToken.cellSurface.color.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.compactCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continue with Google")
        .help("Uses Google's OpenID Connect sign-in flow. Configure the Hive build with a Google OAuth client ID.")
        #else
        Button("Continue with Google") {
            signInFailed = true
            statusMessage = "Google sign-in is unavailable on this platform."
        }
        .buttonStyle(HiveGlassButtonStyle())
        #endif
    }

    @ViewBuilder
    private var appleButton: some View {
        #if canImport(AuthenticationServices)
        if let signInReadinessFailure {
            Button {
                signInFailed = true
                statusMessage = signInReadinessFailure
            } label: {
                HStack(spacing: 8) {
                    HiveSymbol(.appleAccount, size: 15, active: false)
                    Text("Apple-signed build required")
                        .font(HiveTypography.chromeAction)
                }
                .frame(maxWidth: .infinity, minHeight: 46)
                .foregroundStyle(HiveColorToken.scaffoldFaint.color)
            }
            .buttonStyle(.plain)
            .disabled(true)
            .background(HiveColorToken.cellSurface.color.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.compactCornerRadius, style: .continuous))
            .accessibilityLabel("Apple-signed build required")
            .help(signInReadinessFailure)
        } else {
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleSignInResult(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .cornerRadius(HiveLayoutMetrics.compactCornerRadius)
            .accessibilityLabel("Continue with Apple")
        }
        #else
        Button("Continue with Apple") {
            signInFailed = true
            statusMessage = "Sign in with Apple is unavailable on this platform."
        }
        .buttonStyle(HiveGlassButtonStyle())
        #endif
    }

    #if canImport(AuthenticationServices)
    private func refreshSignInReadiness() {
        #if os(macOS) && canImport(Security)
        guard account == nil else { return }
        if let failure = Self.currentBuildSignInReadinessFailure() {
            signInReadinessFailure = failure
            signInFailed = true
            statusMessage = failure
            return
        }
        signInReadinessFailure = nil
        #endif
    }

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                signInFailed = true
                statusMessage = "Apple did not return an account credential. Try again."
                return
            }
            let name = credential.fullName.flatMap(Self.formattedName)
            let account = HiveAppleAccount(
                appleUserID: credential.user,
                displayName: name,
                email: credential.email,
                authorizedAt: Date()
            )
            HiveAppleAccountStore.save(account)
            self.account = account.authenticatedAccount
            onAccountChanged(account.authenticatedAccount)
            signInFailed = false
            statusMessage = "Using Sign in with Apple."
            verifyCredentialState(for: account)
        case .failure(let error):
            signInFailed = true
            statusMessage = Self.userFacingError(error)
        }
    }

    private func handleGoogleSignIn() async {
        do {
            let googleAccount = try await googleSignInCoordinator.signIn()
            HiveGoogleAccountStore.save(googleAccount)
            self.account = googleAccount.authenticatedAccount
            self.onAccountChanged(googleAccount.authenticatedAccount)
            self.signInFailed = false
            self.statusMessage = "Using Sign in with Google."
        } catch {
            self.signInFailed = true
            self.statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func verifyCredentialState(for account: HiveAppleAccount) {
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: account.appleUserID) { state, error in
            DispatchQueue.main.async {
                guard self.account?.provider == .apple,
                      self.account?.providerUserID == account.appleUserID else { return }
                let validationResult: HiveAppleCredentialValidationResult
                if let error {
                    validationResult = .failed(error.localizedDescription)
                } else {
                    validationResult = Self.validationResult(for: state)
                }
                switch HiveAppleCredentialStateResolver.resolve(
                    storedAccount: account,
                    validationResult: validationResult
                ) {
                case .authenticated:
                    self.signInFailed = false
                    self.statusMessage = "Using Sign in with Apple."
                case .locked(let reason, let shouldClearStoredAccount):
                    if shouldClearStoredAccount {
                        HiveAppleAccountStore.clear()
                    }
                    self.account = nil
                    self.onAccountChanged(nil)
                    self.signInFailed = true
                    self.statusMessage = reason
                }
            }
        }
    }

    private static func validationResult(for state: ASAuthorizationAppleIDProvider.CredentialState) -> HiveAppleCredentialValidationResult {
        switch state {
        case .authorized:
            return .authorized
        case .revoked:
            return .revoked
        case .notFound:
            return .notFound
        case .transferred:
            return .transferred
        @unknown default:
            return .failed("Unknown Apple credential state.")
        }
    }

    private static func formattedName(_ components: PersonNameComponents) -> String? {
        let name = PersonNameComponentsFormatter().string(from: components)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func userFacingError(_ error: Error) -> String {
        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            return "Sign in was canceled."
        }
        if let authorizationError = error as? ASAuthorizationError {
            switch authorizationError.code {
            case .failed:
                return "Apple rejected this sign-in request. Rebuild Hive with the Sign in with Apple capability and try again."
            case .invalidResponse:
                return "Apple returned an invalid sign-in response. Check this build's Apple Account capability and try again."
            case .notHandled:
                return "Apple could not handle sign-in for this Hive build. Check the app identifier and Sign in with Apple capability."
            case .unknown:
                return "Sign in with Apple failed before Hive received an account. Check Apple Account signing for this build."
            case .canceled:
                return "Sign in was canceled."
            default:
                return "Sign in with Apple failed for this Hive build."
            }
        }
        return "Sign in with Apple failed before Hive received an account."
    }

    private static func currentBuildSignInReadinessFailure() -> String? {
        #if os(macOS) && canImport(Security)
        guard currentBuildHasAppleSignInEntitlement() else {
            return "This Hive build cannot complete Sign in with Apple because it is missing the runtime entitlement. Install an Apple-signed Hive build with Apple Account signing enabled."
        }
        guard currentBuildHasAppleTeamIdentifier() else {
            return "This Hive build cannot complete Sign in with Apple because it is ad-hoc signed. Install an Apple-signed Hive build with a TeamIdentifier."
        }
        return nil
        #else
        return nil
        #endif
    }

    private static func currentBuildHasAppleSignInEntitlement() -> Bool {
        #if os(macOS) && canImport(Security)
        guard let task = SecTaskCreateFromSelf(nil),
              let entitlement = SecTaskCopyValueForEntitlement(
                task,
                "com.apple.developer.applesignin" as CFString,
                nil
              ) else {
            return false
        }
        if let values = entitlement as? [String] {
            return values.contains("Default")
        }
        if let value = entitlement as? String {
            return value == "Default"
        }
        return false
        #else
        return true
        #endif
    }

    private static func currentBuildHasAppleTeamIdentifier() -> Bool {
        #if os(macOS) && canImport(Security)
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(
            Bundle.main.bundleURL as CFURL,
            SecCSFlags(rawValue: 0),
            &staticCode
        ) == errSecSuccess,
              let staticCode else {
            return false
        }
        var signingInfo: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &signingInfo
        ) == errSecSuccess,
              let info = signingInfo as? [String: Any],
              let teamIdentifier = info[kSecCodeInfoTeamIdentifier as String] as? String else {
            return false
        }
        return !teamIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        #else
        return true
        #endif
    }
    #else
    private func refreshSignInReadiness() {}
    #endif
}

public struct HiveAppleLoginGate: View {
    private let onAuthenticated: () -> Void
    private let onContinueAsGuest: () -> Void

    public init(
        onAuthenticated: @escaping () -> Void,
        onContinueAsGuest: @escaping () -> Void = {}
    ) {
        self.onAuthenticated = onAuthenticated
        self.onContinueAsGuest = onContinueAsGuest
    }

    public var body: some View {
        GeometryReader { proxy in
            if proxy.size.width >= 900 {
                HStack(spacing: HiveSpacing.xl) {
                    loginPanel
                        .frame(width: 430)
                    HiveAuthenticationPreview()
                        .frame(width: min(520, proxy.size.width * 0.44), height: 430)
                }
                .padding(HiveSpacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: HiveSpacing.lg) {
                    loginPanel
                        .frame(maxWidth: 430)
                    HiveAuthenticationPreview()
                        .frame(maxWidth: 520, minHeight: 300, maxHeight: 360)
                }
                .padding(HiveSpacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(HiveColorToken.backgroundDeep.color.ignoresSafeArea())
    }

    private var loginPanel: some View {
        VStack(spacing: HiveSpacing.lg) {
            VStack(spacing: HiveSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: HiveLayoutMetrics.prominentSurfaceCornerRadius, style: .continuous)
                        .fill(HiveColorToken.waxAmber.color.opacity(0.16))
                        .frame(width: 74, height: 74)
                    HiveSymbol(.hiveGraph, size: 44, active: true, rendering: .palette(primary: HiveColorToken.waxAmber.color, secondary: HiveColorToken.waxAmberDeep.color))
                        .accessibilityLabel("Hive")
                }
                Text("HIVE")
                    .font(HiveTypography.hiveHero)
                    .foregroundStyle(HiveColorToken.nectarText.color)
                    .tracking(2.4)
                    .accessibilityAddTraits(.isHeader)
                HiveText("Private intelligence for your Field, Colony, Hive, and Swarm.", role: .nectarBody)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 390)
            }
            VStack(spacing: HiveSpacing.xs) {
                HiveText("Sign in to continue", role: .nectarQuestion)
                HiveText("Hive uses Apple or Google sign-in to tie access to your identity on every device.", role: .nectarBody)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .multilineTextAlignment(.center)
            }
            HiveAppleAccountSection(centered: true) { account in
                if account != nil { onAuthenticated() }
            }
            if HiveAppleAccountPolicy.temporaryGuestAccessIsEnabled {
                Button {
                    onContinueAsGuest()
                } label: {
                    HStack(spacing: HiveSpacing.sm) {
                        HiveSymbol(.hiveGraph, size: 16, active: true)
                            .accessibilityHidden(true)
                        Text("Continue as Guest")
                            .font(HiveTypography.chromeAction)
                    }
                    .frame(maxWidth: 360, minHeight: 44)
                    .foregroundStyle(HiveColorToken.nectarText.color)
                    .background(HiveColorToken.cellSurface.color, in: RoundedRectangle(cornerRadius: HiveLayoutMetrics.controlCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: HiveLayoutMetrics.controlCornerRadius, style: .continuous)
                            .stroke(HiveColorToken.waxAmber.color.opacity(0.26), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Continue as Guest")
                .help("Temporary guest access. This will be removed before production.")
            }
            DisclosureGroup {
                VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                    HiveText("A usable Hive build must be signed with an Apple Developer App ID that has Sign in with Apple enabled.", role: .scaffoldLabel)
                    HiveText("Google sign-in also requires HIVE_GOOGLE_CLIENT_ID and HIVE_GOOGLE_REVERSED_CLIENT_ID in the packaged app.", role: .scaffoldLabel)
                    HiveText("Unsigned diagnostic builds cannot use provider login; temporary guest access is for local testing only.", role: .scaffoldLabel)
                }
                .foregroundStyle(HiveColorToken.scaffoldFaint.color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, HiveSpacing.xs)
            } label: {
                HiveText("Diagnostics", role: .scaffoldAction)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
            }
            .tint(HiveColorToken.waxAmber.color)
        }
        .padding(HiveSpacing.xl)
    }
}

private struct HiveAuthenticationPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedSurface: PreviewSurface = .hive
    @State private var hoveredSurface: PreviewSurface?
    @State private var selectedNodeIndex = 2
    @State private var hoveredNodeIndex: Int?
    @State private var selectedRowIndex = 0
    @State private var hoveredRowIndex: Int?
    @State private var landingPhase = false

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            HStack {
                Text("After sign-in")
                    .font(HiveTypography.chromeAction)
                    .foregroundStyle(HiveColorToken.nectarText.color)
                Spacer()
                HiveSymbol(.confirmed, size: 14, rendering: .monochrome(HiveColorToken.scaffoldFaint.color))
                    .help("This is an interactive preview with sample content. Hive data stays locked until sign-in succeeds.")
            }
            HStack(spacing: HiveSpacing.md) {
                VStack(alignment: .leading, spacing: HiveSpacing.sm) {
                    ForEach(PreviewSurface.allCases) { surface in
                        previewNavButton(surface)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: HiveSpacing.sm) {
                        HiveSymbol(.settings, size: 14)
                        Text("Settings")
                            .font(HiveTypography.chromeAction)
                            .foregroundStyle(HiveColorToken.nectarMuted.color)
                    }
                    .padding(.horizontal, HiveSpacing.sm)
                }
                .frame(width: 132)

                VStack(alignment: .leading, spacing: HiveSpacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HiveText(selectedSurface.title, role: .nectarCardTitle)
                            Text(selectedSurface.subtitle)
                                .font(HiveTypography.chromeCaption)
                                .foregroundStyle(HiveColorToken.nectarMuted.color)
                                .lineLimit(1)
                        }
                        Spacer()
                        HiveSymbol(selectedSurface.symbol, size: 18, active: true)
                    }
                    .hivePreviewLanding(active: landingPhase, index: 0, reduceMotion: reduceMotion, distance: 5)
                    ZStack(alignment: .topLeading) {
                        if selectedSurface == .hive {
                            previewEdges
                                .transition(.opacity)
                            previewHexes
                                .transition(.opacity)
                        } else {
                            previewRows
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 210)
                    .background(previewStageBackground)
                    .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.surfaceCornerRadius, style: .continuous))
                    .hivePreviewLanding(active: landingPhase, index: 1, reduceMotion: reduceMotion, distance: 6)
                    HStack(spacing: HiveSpacing.sm) {
                        ForEach(Array(selectedSurface.cards.enumerated()), id: \.element.id) { index, card in
                            previewCard(card)
                                .hivePreviewLanding(active: landingPhase, index: index + 7, reduceMotion: reduceMotion, distance: 7)
                        }
                    }
                }
                .layoutPriority(1)
            }
        }
        .padding(HiveSpacing.lg)
        .background(HiveColorToken.cellSurface.color.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.prominentSurfaceCornerRadius, style: .continuous))
        .shadow(color: HiveColorToken.backgroundDeep.color.opacity(0.22), radius: 24, x: 0, y: 14)
        .overlay(
            RoundedRectangle(cornerRadius: HiveLayoutMetrics.prominentSurfaceCornerRadius, style: .continuous)
                .stroke(HiveColorToken.waxAmber.color.opacity(0.12), lineWidth: 1)
        )
        .animation(HiveMotion.panel, value: selectedSurface)
        .animation(HiveMotion.focus, value: hoveredSurface)
        .animation(HiveMotion.focus, value: hoveredNodeIndex)
        .animation(HiveMotion.focus, value: hoveredRowIndex)
        .accessibilityLabel("Interactive Hive preview after sign-in")
        .onAppear(perform: restartLanding)
        .onChange(of: selectedSurface) { _, _ in
            restartLanding()
        }
    }

    private func previewNavButton(_ surface: PreviewSurface) -> some View {
        let isSelected = surface == selectedSurface
        let isHovered = surface == hoveredSurface
        return Button {
            withAnimation(HiveMotion.panel) {
                selectedSurface = surface
                selectedRowIndex = 0
                if surface == .hive {
                    selectedNodeIndex = 2
                }
            }
        } label: {
            HStack(spacing: HiveSpacing.sm) {
                HiveSymbol(surface.symbol, size: 15, active: isSelected || isHovered)
                Text(surface.title)
                    .font(HiveTypography.chromeAction)
                    .foregroundStyle(isSelected ? HiveColorToken.nectarText.color : HiveColorToken.nectarMuted.color)
            }
            .padding(.horizontal, HiveSpacing.sm)
            .frame(height: 34)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(previewNavBackground(selected: isSelected, hovered: isHovered))
            .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
            .scaleEffect(reduceMotion ? 1 : (isHovered ? 1.025 : 1), anchor: .center)
            .offset(y: reduceMotion ? 0 : (isHovered ? -1 : 0))
            .shadow(
                color: HiveColorToken.waxAmber.color.opacity(isSelected || isHovered ? 0.16 : 0),
                radius: isHovered ? 12 : 7,
                x: 0,
                y: isHovered ? 6 : 3
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Preview \(surface.title)")
        .help("Preview \(surface.title)")
        .onHover { hovering in
            guard !reduceMotion else { return }
            withAnimation(HiveMotion.focus) {
                hoveredSurface = hovering ? surface : nil
            }
        }
    }

    private func previewNavBackground(selected: Bool, hovered: Bool) -> Color {
        if selected {
            return HiveColorToken.waxAmber.color.opacity(0.16)
        }
        if hovered {
            return HiveColorToken.raisedSurface.color.opacity(0.9)
        }
        return .clear
    }

    private var previewStageBackground: some View {
        LinearGradient(
            colors: [
                HiveColorToken.backgroundDeep.color.opacity(0.58),
                HiveColorToken.cellSurface.color.opacity(0.46),
                selectedSurface.glowColor.opacity(0.09)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var previewEdges: some View {
        GeometryReader { geometry in
            Path { path in
                let points = previewPoints(in: geometry.size)
                for edge in [(0, 1), (1, 2), (2, 3), (2, 4), (4, 5), (1, 5), (3, 6)] {
                    path.move(to: points[edge.0])
                    path.addLine(to: points[edge.1])
                }
            }
            .stroke(HiveColorToken.nectarMuted.color.opacity(0.18), lineWidth: 1)
        }
    }

    private var previewHexes: some View {
        GeometryReader { geometry in
            let points = previewPoints(in: geometry.size)
            ForEach(points.indices, id: \.self) { index in
                previewNode(index: index, at: points[index])
            }
        }
    }

    private func previewNode(index: Int, at point: CGPoint) -> some View {
        let isSelected = index == selectedNodeIndex
        let isHovered = index == hoveredNodeIndex
        return Button {
            withAnimation(HiveMotion.focus) {
                selectedNodeIndex = index
            }
        } label: {
            HiveSymbol(
                .hiveGraph,
                size: isSelected ? 32 : (isHovered ? 24 : 20),
                active: isSelected || isHovered
            )
            .shadow(
                color: HiveColorToken.waxAmber.color.opacity(isSelected || isHovered ? 0.25 : 0),
                radius: isHovered ? 16 : 10,
                x: 0,
                y: isHovered ? 7 : 3
            )
            .scaleEffect(reduceMotion ? 1 : (isHovered ? 1.12 : 1))
        }
        .buttonStyle(.plain)
        .position(point)
        .hivePreviewLanding(active: landingPhase, index: index + 2, reduceMotion: reduceMotion, distance: 6)
        .accessibilityLabel("Preview Hive node \(index + 1)")
        .help(previewNodeHelp(index))
        .onHover { hovering in
            guard !reduceMotion else { return }
            withAnimation(HiveMotion.focus) {
                hoveredNodeIndex = hovering ? index : nil
            }
        }
    }

    private func previewNodeHelp(_ index: Int) -> String {
        let labels = [
            "Recent source",
            "Related skill",
            "Selected memory",
            "Colony article",
            "Open action",
            "Connected project",
            "Question for Swarm"
        ]
        return labels.indices.contains(index) ? labels[index] : "Preview memory"
    }

    private var previewRows: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.sm) {
            ForEach(Array(selectedSurface.rows.enumerated()), id: \.offset) { index, row in
                previewSampleRow(row: row, index: index)
            }
            Spacer(minLength: 0)
        }
        .padding(HiveSpacing.sm)
    }

    private func previewSampleRow(row: PreviewRow, index: Int) -> some View {
        let isSelected = index == selectedRowIndex
        let isHovered = index == hoveredRowIndex
        return Button {
            withAnimation(HiveMotion.focus) {
                selectedRowIndex = index
            }
        } label: {
            HStack(spacing: HiveSpacing.sm) {
                HiveSymbol(row.symbol, size: 16, active: isSelected || isHovered)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.title)
                        .font(HiveTypography.chromeAction)
                        .foregroundStyle(HiveColorToken.nectarText.color)
                        .lineLimit(1)
                    Text(row.detail)
                        .font(HiveTypography.chromeCaption)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                        .lineLimit(1)
                }
                Spacer(minLength: HiveSpacing.sm)
                HiveSymbol(isSelected ? .confirmed : .status, size: 12, active: isSelected)
                    .opacity(isSelected ? 1 : 0.36)
            }
            .padding(.horizontal, HiveSpacing.sm)
            .frame(height: 48)
            .background(previewRowBackground(selected: isSelected, hovered: isHovered))
            .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
            .scaleEffect(reduceMotion ? 1 : (isHovered ? 1.015 : 1))
            .offset(y: reduceMotion ? 0 : (isHovered ? -1 : 0))
            .shadow(
                color: HiveColorToken.waxAmber.color.opacity(isHovered ? 0.12 : 0),
                radius: isHovered ? 10 : 0,
                x: 0,
                y: isHovered ? 5 : 0
            )
        }
        .buttonStyle(.plain)
        .hivePreviewLanding(active: landingPhase, index: index + 2, reduceMotion: reduceMotion, distance: 7)
        .accessibilityLabel("Preview \(row.title)")
        .help(row.detail)
        .onHover { hovering in
            guard !reduceMotion else { return }
            withAnimation(HiveMotion.focus) {
                hoveredRowIndex = hovering ? index : nil
            }
        }
    }

    private func previewRowBackground(selected: Bool, hovered: Bool) -> Color {
        if selected {
            return HiveColorToken.waxAmber.color.opacity(0.13)
        }
        if hovered {
            return HiveColorToken.raisedSurface.color.opacity(0.68)
        }
        return HiveColorToken.cellSurface.color.opacity(0.34)
    }

    private func previewPoints(in size: CGSize) -> [CGPoint] {
        [
            CGPoint(x: size.width * 0.18, y: size.height * 0.34),
            CGPoint(x: size.width * 0.34, y: size.height * 0.52),
            CGPoint(x: size.width * 0.52, y: size.height * 0.42),
            CGPoint(x: size.width * 0.72, y: size.height * 0.28),
            CGPoint(x: size.width * 0.70, y: size.height * 0.66),
            CGPoint(x: size.width * 0.42, y: size.height * 0.76),
            CGPoint(x: size.width * 0.84, y: size.height * 0.52)
        ]
    }

    private func previewCard(_ card: PreviewCard) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HiveSymbol(card.symbol, size: 14, active: true)
            Text(card.title)
                .font(HiveTypography.chromeFootnote)
                .foregroundStyle(HiveColorToken.nectarMuted.color)
            Text(card.value)
                .font(HiveTypography.chromeAction)
                .foregroundStyle(HiveColorToken.nectarText.color)
                .lineLimit(1)
        }
        .padding(HiveSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HiveColorToken.raisedSurface.color.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
    }

    private func restartLanding() {
        guard !reduceMotion else {
            landingPhase = true
            return
        }
        var resetTransaction = Transaction()
        resetTransaction.disablesAnimations = true
        withTransaction(resetTransaction) {
            landingPhase = false
        }
        DispatchQueue.main.async {
            landingPhase = true
        }
    }

    private enum PreviewSurface: String, CaseIterable, Identifiable {
        case field
        case colony
        case hive
        case swarm

        var id: String { rawValue }

        var title: String {
            switch self {
            case .field:
                return "Field"
            case .colony:
                return "The Colony"
            case .hive:
                return "The Hive"
            case .swarm:
                return "Swarm"
            }
        }

        var subtitle: String {
            switch self {
            case .field:
                return "Capture sources before they become memory"
            case .colony:
                return "Organized articles with source-backed claims"
            case .hive:
                return "A living map of connected memories"
            case .swarm:
                return "A private partner for questions and work"
            }
        }

        var symbol: HiveSymbolName {
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

        var glowColor: Color {
            switch self {
            case .field:
                return HiveColorToken.waxAmberBright.color
            case .colony:
                return HiveColorToken.waxAmber.color
            case .hive:
                return HiveColorToken.waxAmberDeep.color
            case .swarm:
                return HiveColorToken.nectarText.color
            }
        }

        var rows: [PreviewRow] {
            switch self {
            case .field:
                return [
                    PreviewRow(symbol: .staged, title: "Resume draft", detail: "Waiting briefly before processing"),
                    PreviewRow(symbol: .webLink, title: "Research link", detail: "Captured as an approved source"),
                    PreviewRow(symbol: .rawSourcesSheet, title: "Raw Sources", detail: "Review, remove, or re-process")
                ]
            case .colony:
                return [
                    PreviewRow(symbol: .wiki, title: "Software Engineering", detail: "Claims, sources, and recent edits"),
                    PreviewRow(symbol: .merge, title: "Related pages", detail: "Similar articles are proposed for merge"),
                    PreviewRow(symbol: .conflict, title: "Needs review", detail: "Contradictions wait for your approval")
                ]
            case .hive:
                return []
            case .swarm:
                return [
                    PreviewRow(symbol: .chat, title: "Ask from memory", detail: "Answers cite Field and Colony context"),
                    PreviewRow(symbol: .liveAssistant, title: "Live mode", detail: "Voice, screen context, and attachments"),
                    PreviewRow(symbol: .runMaintenance, title: "Automations", detail: "Briefings and recurring review passes")
                ]
            }
        }

        var cards: [PreviewCard] {
            switch self {
            case .field:
                return [
                    PreviewCard(symbol: .attach, title: "Drop", value: "Stage"),
                    PreviewCard(symbol: .processNow, title: "Ready", value: "Process"),
                    PreviewCard(symbol: .forget, title: "Control", value: "Remove")
                ]
            case .colony:
                return [
                    PreviewCard(symbol: .search, title: "Find", value: "Articles"),
                    PreviewCard(symbol: .indexedOnly, title: "Trace", value: "Sources"),
                    PreviewCard(symbol: .edit, title: "Fix", value: "Claims")
                ]
            case .hive:
                return [
                    PreviewCard(symbol: .rawInputs, title: "Field", value: "Capture"),
                    PreviewCard(symbol: .wiki, title: "Colony", value: "Organize"),
                    PreviewCard(symbol: .chat, title: "Swarm", value: "Ask")
                ]
            case .swarm:
                return [
                    PreviewCard(symbol: .chat, title: "Ask", value: "Context"),
                    PreviewCard(symbol: .feedHive, title: "Remember", value: "Learn"),
                    PreviewCard(symbol: .runMaintenance, title: "Do", value: "Act")
                ]
            }
        }
    }

    private struct PreviewRow: Identifiable {
        var symbol: HiveSymbolName
        var title: String
        var detail: String

        var id: String { title }
    }

    private struct PreviewCard: Identifiable {
        var symbol: HiveSymbolName
        var title: String
        var value: String

        var id: String { title }
    }
}

private struct HivePreviewLandingModifier: ViewModifier {
    var active: Bool
    var index: Int
    var reduceMotion: Bool
    var distance: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion || active ? 1 : 0)
            .scaleEffect(reduceMotion || active ? 1 : 0.985, anchor: .center)
            .offset(y: reduceMotion || active ? 0 : -distance)
            .animation(reduceMotion ? nil : landingAnimation, value: active)
    }

    private var landingAnimation: Animation {
        Animation
            .interpolatingSpring(mass: 1.0, stiffness: 360, damping: 44, initialVelocity: 0)
            .delay(Double(index) * 0.045)
    }
}

private extension View {
    func hivePreviewLanding(active: Bool, index: Int, reduceMotion: Bool, distance: CGFloat) -> some View {
        modifier(HivePreviewLandingModifier(
            active: active,
            index: index,
            reduceMotion: reduceMotion,
            distance: distance
        ))
    }
}

public struct HiveFirstLoginDataChoiceSheet: View {
    public var prompt: HiveFirstLoginDataChoicePrompt
    public var onChoose: (HiveFirstLoginDataChoice) -> Void

    public init(
        prompt: HiveFirstLoginDataChoicePrompt,
        onChoose: @escaping (HiveFirstLoginDataChoice) -> Void
    ) {
        self.prompt = prompt
        self.onChoose = onChoose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.lg) {
            HStack(spacing: HiveSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: HiveLayoutMetrics.surfaceCornerRadius, style: .continuous)
                        .fill(HiveColorToken.waxAmber.color.opacity(0.14))
                        .frame(width: 52, height: 52)
                    HiveSymbol(.cloudSource, size: 24, active: true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose Hive Data")
                        .font(HiveTypography.chromeTitle)
                        .foregroundStyle(HiveColorToken.nectarText.color)
                    Text("First sign-in on this device as \(prompt.account.displayLabel).")
                        .font(HiveTypography.chromeBody)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                        .lineLimit(2)
                }
            }

            Text("Pick the safest starting point. Swarm will not overwrite local data without a reviewed proposal.")
                .font(HiveTypography.chromeBody)
                .foregroundStyle(HiveColorToken.nectarMuted.color)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: HiveSpacing.sm) {
                ForEach(HiveFirstLoginDataChoice.allCases) { choice in
                    Button {
                        onChoose(choice)
                    } label: {
                        HStack(spacing: HiveSpacing.md) {
                            HiveSymbol(symbol(for: choice), size: 18, active: true)
                                .frame(width: 24)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(choice.title)
                                    .font(HiveTypography.chromeAction)
                                    .foregroundStyle(HiveColorToken.nectarText.color)
                                Text(choice.detail)
                                    .font(HiveTypography.chromeFootnote)
                                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: HiveSpacing.sm)
                            HiveSymbol(.confirmed, size: 14, active: true)
                                .opacity(0.55)
                        }
                        .padding(HiveSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(HiveColorToken.cellSurface.color.opacity(0.78))
                        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(choice.title)
                }
            }
        }
        .padding(HiveSpacing.xl)
        .frame(minWidth: 420, idealWidth: 480, maxWidth: 560)
        .background(HiveColorToken.backgroundMid.color)
    }

    private func symbol(for choice: HiveFirstLoginDataChoice) -> HiveSymbolName {
        switch choice {
        case .cloud:
            return .cloudSource
        case .local:
            return .localOnly
        case .swarmMerge:
            return .chat
        }
    }
}

public typealias HiveAppleAuthenticationGate = HiveAppleLoginGate
