import Foundation

// MARK: - PasswordCapturePolicy
//
// Classifies a just-submitted login form into a Chrome-style offer: save a
// brand-new account, update an existing account's password, or offer nothing.
// The submitted username is matched against stored credentials across the
// same registrable-domain family as the page host (reusing AutofillMatcher's
// rules), so a login on `login.example.com` can update a credential stored
// for `example.com` and vice versa. A submission identical to what is already
// stored produces no offer — the user just logged in with the saved
// credential (possibly via our own autofill chip).

public enum PasswordCapturePolicy {

    /// The kind of offer a submitted credential warrants.
    public enum OfferKind: Sendable, Equatable {
        /// No stored credential matches the submitted username — offer to
        /// save a new account for this host family.
        case save
        /// A stored credential matches the submitted username but the
        /// submitted password differs — offer to update it.
        case update(existingID: UUID)
        /// Nothing to do (empty submission, or the credential is already
        /// stored exactly as submitted).
        case none
    }

    /// A stored credential in the shape the policy needs. The app maps its
    /// own rows into this; keeping the policy dependency-free lets the
    /// decision logic live in HiveCore with deterministic tests.
    public struct StoredCredential: Sendable, Equatable {
        public let id: UUID
        public let site: String
        public let username: String
        public let password: String

        public init(id: UUID, site: String, username: String, password: String) {
            self.id = id
            self.site = site
            self.username = username
            self.password = password
        }
    }

    /// Classifies a submitted (username, password) pair for `host` against
    /// the stored credentials.
    public static func decide(
        stored: [StoredCredential],
        submittedUsername: String,
        submittedPassword: String,
        host: String
    ) -> OfferKind {
        let username = submittedUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        // Chrome never offers to save an empty username or an empty password.
        guard !username.isEmpty, !submittedPassword.isEmpty else { return .none }
        guard !host.isEmpty else { return .none }

        let candidates = stored.map { AutofillCandidate(site: $0.site, username: $0.username) }
        let matchedUsernames = Set(
            AutofillMatcher.matches(forHost: host, candidates: candidates).map { $0.username }
        )

        // Update path: the submitted username already exists among the stored
        // credentials for this host family. First in save order wins when the
        // same username is stored under several family sites.
        guard matchedUsernames.contains(username),
              let existing = stored.first(where: { $0.username == username })
        else {
            // Save path: no existing account with this username on the family.
            return .save
        }
        return existing.password == submittedPassword
            ? .none
            : .update(existingID: existing.id)
    }
}
