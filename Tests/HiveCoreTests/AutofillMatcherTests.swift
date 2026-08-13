import Foundation
import Testing
@testable import HiveCore

@Suite("AutofillMatcher")
struct AutofillMatcherTests {

    private let candidates = [
        AutofillCandidate(site: "example.com", username: "alice"),
        AutofillCandidate(site: "Example.com.", username: "bob"),
        AutofillCandidate(site: "gist.example.com", username: "carol"),
        AutofillCandidate(site: "github.com", username: "dave"),
        AutofillCandidate(site: "", username: "empty"),
    ]

    @Test func exactHostMatchIsCaseAndDotInsensitive() {
        let matches = AutofillMatcher.matches(forHost: "EXAMPLE.COM.", candidates: candidates)
        // alice/bob are exact (normalized) matches; carol joins via the
        // registrable-domain family rule (gist.example.com under example.com).
        #expect(matches.map(\.username) == ["alice", "bob", "carol"])
    }

    @Test func subdomainHostMatchesApexCredential() {
        let matches = AutofillMatcher.matches(forHost: "login.example.com", candidates: candidates)
        #expect(matches.map(\.username) == ["alice", "bob"])
    }

    @Test func apexHostMatchesSubdomainCredential() {
        // Chrome offers a credential saved on accounts.example.com when the
        // user is on example.com (same registrable-domain family).
        let matches = AutofillMatcher.matches(forHost: "example.com", candidates: candidates)
        #expect(matches.map(\.username) == ["alice", "bob", "carol"])
    }

    @Test func siblingSubdomainsDoNotMatch() {
        // login.example.com and gist.example.com share a registrable domain
        // but neither is a suffix of the other; without a public-suffix list
        // the family approximation must not bridge them.
        let matches = AutofillMatcher.matches(forHost: "login.example.com", candidates: candidates)
        #expect(!matches.contains { $0.username == "carol" })
    }

    @Test func unrelatedHostReturnsNoMatches() {
        #expect(AutofillMatcher.matches(forHost: "other.org", candidates: candidates).isEmpty)
    }

    @Test func emptySiteCandidatesAreNeverReturned() {
        #expect(!AutofillMatcher.matches(forHost: "example.com", candidates: candidates)
            .contains { $0.username == "empty" })
    }

    @Test func emptyHostReturnsNoMatches() {
        #expect(AutofillMatcher.matches(forHost: "   ", candidates: candidates).isEmpty)
    }

    @Test func preservesInputOrder() {
        let single = [AutofillCandidate(site: "example.com", username: "zed"),
                      AutofillCandidate(site: "example.com", username: "aaron")]
        let matches = AutofillMatcher.matches(forHost: "example.com", candidates: single)
        #expect(matches.map(\.username) == ["zed", "aaron"])
    }
}
