import Foundation
import Testing
@testable import HiveCore

@Suite("SimilarTabGroupPolicy")
struct SimilarTabGroupPolicyTests {

    private func url(_ s: String) -> URL? { URL(string: s) }
    private func candidate(_ id: String, _ s: String?) -> TabGroupCandidate {
        TabGroupCandidate(id: id, hostKey: s.flatMap { SiteMutePolicy.hostKey(for: URL(string: $0)) })
    }

    @Test("Two tabs on one domain suggest one group")
    func basicGrouping() {
        let groups = SimilarTabGroupPolicy.suggestedGroups(candidates: [
            candidate("a", "https://github.com/one"),
            candidate("b", "https://github.com/two"),
        ])
        #expect(groups.count == 1)
        #expect(groups[0].tabIDs == ["a", "b"])
        #expect(groups[0].hostKey == "github.com")
    }

    @Test("www and non-www hosts merge into one group")
    func wwwMerges() {
        let groups = SimilarTabGroupPolicy.suggestedGroups(candidates: [
            candidate("a", "https://www.github.com/x"),
            candidate("b", "https://github.com/y"),
        ])
        #expect(groups.count == 1)
        #expect(groups[0].tabIDs.count == 2)
        #expect(groups[0].hostKey == "github.com")
    }

    @Test("Singletons and keyless candidates are never grouped")
    func singletonsAndKeylessSkipped() {
        let groups = SimilarTabGroupPolicy.suggestedGroups(candidates: [
            candidate("a", "https://example.com"),
            candidate("b", "https://other.com"),
            candidate("c", "hive://start"),
            candidate("d", nil),
        ])
        #expect(groups.isEmpty)
    }

    @Test("Groups order largest first, then alphabetically")
    func ordering() {
        let groups = SimilarTabGroupPolicy.suggestedGroups(candidates: [
            candidate("a1", "https://a.com"),
            candidate("a2", "https://a.com"),
            candidate("a3", "https://a.com"),
            candidate("b1", "https://b.com"),
            candidate("b2", "https://b.com"),
            candidate("c1", "https://c.com"),
            candidate("c2", "https://c.com"),
        ])
        #expect(groups.map(\.hostKey) == ["a.com", "b.com", "c.com"])
    }

    @Test("Three-tab domains beat two-tab domains regardless of name")
    func sizeDominates() {
        let groups = SimilarTabGroupPolicy.suggestedGroups(candidates: [
            candidate("z1", "https://zzz.com"),
            candidate("z2", "https://zzz.com"),
            candidate("a1", "https://aaa.com"),
            candidate("a2", "https://aaa.com"),
            candidate("a3", "https://aaa.com"),
        ])
        #expect(groups.first?.hostKey == "aaa.com")
    }

    @Test("Display names drop www and capitalize the first letter")
    func displayNames() {
        #expect(SimilarTabGroupPolicy.displayName(for: "github.com") == "Github.com")
        #expect(SimilarTabGroupPolicy.displayName(for: "mail.google.com") == "Mail.google.com")
    }

    @Test("hostKey reuses the http(s) site keying")
    func hostKeyReuse() {
        #expect(SimilarTabGroupPolicy.hostKey(for: url("https://www.Example.com")) == "example.com")
        #expect(SimilarTabGroupPolicy.hostKey(for: url("hive://start")) == nil)
        #expect(SimilarTabGroupPolicy.hostKey(for: nil) == nil)
    }
}
