import Foundation
import Testing
@testable import HiveCore

@Suite("PasswordCapturePolicy")
struct PasswordCapturePolicyTests {

    private func cred(
        _ site: String,
        username: String,
        password: String,
        id: UUID = UUID()
    ) -> PasswordCapturePolicy.StoredCredential {
        PasswordCapturePolicy.StoredCredential(
            id: id,
            site: site,
            username: username,
            password: password
        )
    }

    @Test func newUsernameOffersSave() {
        let stored = [cred("example.com", username: "alice", password: "old-password")]
        let kind = PasswordCapturePolicy.decide(
            stored: stored,
            submittedUsername: "bob",
            submittedPassword: "brand-new",
            host: "example.com"
        )
        #expect(kind == .save)
    }

    @Test func sameUsernameDifferentPasswordOffersUpdate() {
        let id = UUID()
        let stored = [cred("example.com", username: "alice", password: "old-password", id: id)]
        let kind = PasswordCapturePolicy.decide(
            stored: stored,
            submittedUsername: "alice",
            submittedPassword: "new-password",
            host: "example.com"
        )
        #expect(kind == .update(existingID: id))
    }

    @Test func identicalCredentialOffersNothing() {
        let stored = [cred("example.com", username: "alice", password: "same-password")]
        let kind = PasswordCapturePolicy.decide(
            stored: stored,
            submittedUsername: "alice",
            submittedPassword: "same-password",
            host: "example.com"
        )
        #expect(kind == .none)
    }

    @Test func emptyUsernameOffersNothing() {
        let stored = [cred("example.com", username: "alice", password: "pw")]
        let kind = PasswordCapturePolicy.decide(
            stored: stored,
            submittedUsername: "   ",
            submittedPassword: "pw",
            host: "example.com"
        )
        #expect(kind == .none)
    }

    @Test func emptyPasswordOffersNothing() {
        let stored = [cred("example.com", username: "alice", password: "pw")]
        let kind = PasswordCapturePolicy.decide(
            stored: stored,
            submittedUsername: "alice",
            submittedPassword: "",
            host: "example.com"
        )
        #expect(kind == .none)
    }

    @Test func whitespaceAroundSubmittedUsernameIsTrimmed() {
        let stored = [cred("example.com", username: "alice", password: "old")]
        let kind = PasswordCapturePolicy.decide(
            stored: stored,
            submittedUsername: "  alice  ",
            submittedPassword: "new",
            host: "example.com"
        )
        #expect(kind == .update(existingID: stored[0].id))
    }

    @Test func subdomainLoginMatchesParentSiteCredential() {
        let id = UUID()
        let stored = [cred("example.com", username: "alice", password: "old", id: id)]
        let kind = PasswordCapturePolicy.decide(
            stored: stored,
            submittedUsername: "alice",
            submittedPassword: "changed",
            host: "login.example.com"
        )
        #expect(kind == .update(existingID: id))
    }

    @Test func parentHostLoginMatchesSubdomainSiteCredential() {
        let id = UUID()
        let stored = [cred("mail.example.com", username: "alice", password: "old", id: id)]
        let kind = PasswordCapturePolicy.decide(
            stored: stored,
            submittedUsername: "alice",
            submittedPassword: "changed",
            host: "example.com"
        )
        #expect(kind == .update(existingID: id))
    }

    @Test func siblingSubdomainsDoNotMatch() {
        let stored = [cred("a.example.com", username: "alice", password: "old")]
        let kind = PasswordCapturePolicy.decide(
            stored: stored,
            submittedUsername: "bob",
            submittedPassword: "fresh",
            host: "b.example.com"
        )
        // Sibling subdomains are not a registrable-domain family match, so
        // "bob" is new for this host — a save offer.
        #expect(kind == .save)
    }

    @Test func updatePicksFirstStoredRowWhenUsernameIsDuplicatedAcrossFamily() {
        let firstID = UUID()
        let secondID = UUID()
        let stored = [
            cred("example.com", username: "alice", password: "first", id: firstID),
            cred("login.example.com", username: "alice", password: "second", id: secondID)
        ]
        let kind = PasswordCapturePolicy.decide(
            stored: stored,
            submittedUsername: "alice",
            submittedPassword: "changed",
            host: "example.com"
        )
        #expect(kind == .update(existingID: firstID))
    }

    @Test func unrelatedUsernameOnMatchingHostStillOffersSave() {
        let stored = [cred("example.com", username: "alice", password: "old")]
        let kind = PasswordCapturePolicy.decide(
            stored: stored,
            submittedUsername: "carol",
            submittedPassword: "fresh",
            host: "example.com"
        )
        #expect(kind == .save)
    }

    @Test func emptyHostOffersNothing() {
        let stored = [cred("example.com", username: "alice", password: "old")]
        let kind = PasswordCapturePolicy.decide(
            stored: stored,
            submittedUsername: "alice",
            submittedPassword: "new",
            host: ""
        )
        #expect(kind == .none)
    }

    @Test func mixedCaseHostMatchesCredential() {
        let id = UUID()
        let stored = [cred("example.com", username: "alice", password: "old", id: id)]
        let kind = PasswordCapturePolicy.decide(
            stored: stored,
            submittedUsername: "alice",
            submittedPassword: "new",
            host: "LOGIN.EXAMPLE.COM"
        )
        #expect(kind == .update(existingID: id))
    }

    @Test func identicalCredentialOnSubdomainHostOffersNothing() {
        let stored = [cred("example.com", username: "alice", password: "same")]
        let kind = PasswordCapturePolicy.decide(
            stored: stored,
            submittedUsername: "alice",
            submittedPassword: "same",
            host: "login.example.com"
        )
        #expect(kind == .none)
    }

    @Test func updateMatchesSecondStoredRowWhenFirstUsernameDiffers() {
        let secondID = UUID()
        let stored = [
            cred("example.com", username: "bob", password: "bob-old"),
            cred("example.com", username: "alice", password: "alice-old", id: secondID)
        ]
        let kind = PasswordCapturePolicy.decide(
            stored: stored,
            submittedUsername: "alice",
            submittedPassword: "alice-new",
            host: "example.com"
        )
        #expect(kind == .update(existingID: secondID))
    }
}
