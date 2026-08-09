import Testing
@testable import HiveCore

@Suite("TabAttachmentSummary")
struct TabAttachmentSummaryTests {
    @Test("all selected tabs admitted")
    func allAdmitted() {
        let summary = TabAttachmentSummary(
            selectedIDs: ["one", "two"],
            classifications: [
                .init(id: "one", classification: .admitted),
                .init(id: "two", classification: .admitted)
            ],
            isPrivateBrowsing: false
        )

        #expect(summary.selectedCount == 2)
        #expect(summary.admittedCount == 2)
        #expect(summary.excludedCount == 0)
        #expect(summary.privateCount == 0)
        #expect(summary.missingCount == 0)
        #expect(summary.detail == "2 admitted")
        #expect(summary.warning == nil)
    }

    @Test("mixed classifications explain why attachments are not admitted")
    func mixedClassification() {
        let summary = TabAttachmentSummary(
            selectedIDs: ["admitted", "excluded", "private", "missing"],
            classifications: [
                .init(id: "admitted", classification: .admitted),
                .init(id: "excluded", classification: .excluded),
                .init(id: "private", classification: .privateContent),
                .init(id: "missing", classification: .missing)
            ],
            isPrivateBrowsing: false
        )

        #expect(summary.selectedCount == 4)
        #expect(summary.admittedCount == 1)
        #expect(summary.excludedCount == 1)
        #expect(summary.privateCount == 1)
        #expect(summary.missingCount == 1)
        #expect(summary.detail == "1 admitted · 3 not admitted")
        #expect(summary.warning == "1 outside this scope · 1 private · 1 no longer available")
    }

    @Test("unclassified selected IDs fail closed as missing")
    func unclassifiedIDsAreMissing() {
        let summary = TabAttachmentSummary(
            selectedIDs: ["present", "stale"],
            classifications: [
                .init(id: "present", classification: .admitted)
            ],
            isPrivateBrowsing: false
        )

        #expect(summary.admittedCount == 1)
        #expect(summary.missingCount == 1)
        #expect(summary.warning == "1 no longer available")
    }

    @Test("private browsing never reports admitted attachments")
    func privateBrowsing() {
        let summary = TabAttachmentSummary(
            selectedIDs: ["private-tab"],
            classifications: [
                .init(id: "private-tab", classification: .admitted)
            ],
            isPrivateBrowsing: true
        )

        #expect(summary.selectedCount == 1)
        #expect(summary.admittedCount == 0)
        #expect(summary.detail == "Attachments unavailable in Private Browsing")
        #expect(summary.warning == "Selected tabs stay out of Swarm context")
    }

    @Test("unavailable and duplicate classifications fail closed without inflating counts")
    func unavailableAndDuplicateClassifications() {
        let summary = TabAttachmentSummary(
            selectedIDs: ["unavailable", "duplicate"],
            classifications: [
                .init(id: "unavailable", classification: .unavailable),
                .init(id: "duplicate", classification: .admitted),
                .init(id: "duplicate", classification: .excluded)
            ],
            isPrivateBrowsing: false
        )

        #expect(summary.selectedCount == 2)
        #expect(summary.admittedCount == 1)
        #expect(summary.excludedCount == 0)
        #expect(summary.missingCount == 0)
        #expect(summary.warning == "1 unavailable")
    }

    @Test("classifier mirrors profile workspace private URL and active-page boundaries")
    func classifierBoundaries() {
        let candidates = [
            TabAttachmentSummary.Candidate(
                id: "active", profileID: "p", workspaceID: "w",
                isPrivate: false, isActive: true, hasUsableHTTPURL: true
            ),
            TabAttachmentSummary.Candidate(
                id: "foreign", profileID: "other", workspaceID: "w",
                isPrivate: false, isActive: false, hasUsableHTTPURL: true
            ),
            TabAttachmentSummary.Candidate(
                id: "private", profileID: "p", workspaceID: "w",
                isPrivate: true, isActive: false, hasUsableHTTPURL: true
            ),
            TabAttachmentSummary.Candidate(
                id: "internal", profileID: "p", workspaceID: "w",
                isPrivate: false, isActive: false, hasUsableHTTPURL: false
            )
        ]
        let classifications = TabAttachmentSummary.classify(
            selectedIDs: ["active", "foreign", "private", "internal", "stale"],
            candidates: candidates,
            currentProfileID: "p",
            currentWorkspaceID: "w",
            isPrivateBrowsing: false,
            includesCurrentPage: true
        )
        let byID = Dictionary(uniqueKeysWithValues: classifications.map { ($0.id, $0.classification) })

        #expect(byID["active"] == .admitted)
        #expect(byID["foreign"] == .excluded)
        #expect(byID["private"] == .privateContent)
        #expect(byID["internal"] == .unavailable)
        #expect(byID["stale"] == .missing)
    }

    @Test("site policy blocks an otherwise eligible active tab")
    func sitePolicyBlocksActiveTab() {
        let candidate = TabAttachmentSummary.Candidate(
            id: "active", profileID: "p", workspaceID: "w",
            isPrivate: false, isActive: true, hasUsableHTTPURL: true,
            pageVisibility: .blocked
        )
        let classifications = TabAttachmentSummary.classify(
            selectedIDs: ["active"],
            candidates: [candidate],
            currentProfileID: "p",
            currentWorkspaceID: "w",
            isPrivateBrowsing: false,
            includesCurrentPage: true
        )
        #expect(classifications.first?.classification == .excluded)
    }

    @Test("private page visibility remains private content")
    func privatePageVisibilityRemainsPrivate() {
        let candidate = TabAttachmentSummary.Candidate(
            id: "private", profileID: "p", workspaceID: "w",
            isPrivate: false, isActive: true, hasUsableHTTPURL: true,
            pageVisibility: .privateBrowsing
        )
        let classifications = TabAttachmentSummary.classify(
            selectedIDs: ["private"],
            candidates: [candidate],
            currentProfileID: "p",
            currentWorkspaceID: "w",
            isPrivateBrowsing: false,
            includesCurrentPage: true
        )
        #expect(classifications.first?.classification == .privateContent)
    }

    @Test("active page is unavailable when page context is disabled")
    func activePageRequiresPageContext() {
        let candidate = TabAttachmentSummary.Candidate(
            id: "active", profileID: "p", workspaceID: "w",
            isPrivate: false, isActive: true, hasUsableHTTPURL: true
        )
        let classifications = TabAttachmentSummary.classify(
            selectedIDs: ["active"],
            candidates: [candidate],
            currentProfileID: "p",
            currentWorkspaceID: "w",
            isPrivateBrowsing: false,
            includesCurrentPage: false
        )
        #expect(classifications.first?.classification == .unavailable)
    }

    @Test("empty selection has no warning")
    func emptySelection() {
        let summary = TabAttachmentSummary(
            selectedIDs: [],
            classifications: [],
            isPrivateBrowsing: false
        )

        #expect(summary.selectedCount == 0)
        #expect(summary.detail == "No selected tabs")
        #expect(summary.warning == nil)
    }

@Test func contextLayersAreNonEmpty() {
        #expect(!BrowserContextLayer.allCases.isEmpty)
    }
}
