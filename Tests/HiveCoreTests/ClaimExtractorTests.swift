import Foundation
import Testing
@testable import HiveCore

// MARK: - ClaimExtractor tests (SWARM-002 §7.3 step 5: quote/span references)

@Suite("ClaimExtractor")
struct ClaimExtractorTests {

    private func extractor() -> ClaimExtractor {
        ClaimExtractor()
    }

    @Test func extractsClaimWithVerbatimSpanAndResolvableOffsets() {
        let answer = "The Hive Browser turns what you browse into organized memory. [1]"
        let sourceText = "The Hive Browser is a native macOS browser. "
            + "It turns what you browse into organized, actionable memory with full provenance. "
            + "Everything runs on device."
        let sources = [ClaimExtractor.SourceInput(sourceID: "src-1", extractedText: sourceText)]

        let extraction = extractor().extractClaims(answer: answer, sources: sources)

        #expect(extraction.claims.count == 1)
        guard let claim = extraction.claims.first,
              let span = claim.evidenceSpans.first else {
            Issue.record("expected one grounded claim with one evidence span")
            return
        }
        #expect(claim.text.contains("turns what you browse into organized"))
        #expect(span.sourceID == "src-1")
        #expect(span.quote == claim.text)
        // The UTF-16 offsets must resolve to the exact claim text in the
        // stored source text — the span is real, not cosmetic.
        let start = sourceText.utf16.index(sourceText.utf16.startIndex, offsetBy: span.startOffset)
        let end = sourceText.utf16.index(sourceText.utf16.startIndex, offsetBy: span.endOffset)
        let resolved = String(decoding: sourceText.utf16[start..<end], as: UTF16.self)
        #expect(resolved == claim.text)
        #expect(extraction.unmatchedCitationIndices.isEmpty)
    }

    @Test func usesCitationNumberNotMarkerPosition() {
        // [2] appears FIRST but refers to the second source.
        let answer = "The second claim is cited first. [2] The first claim follows. [1]"
        let sources = [
            ClaimExtractor.SourceInput(sourceID: "src-a", extractedText: "The first claim is supported by this source."),
            ClaimExtractor.SourceInput(sourceID: "src-b", extractedText: "The second claim is documented in this source."),
        ]

        let extraction = extractor().extractClaims(answer: answer, sources: sources)

        // [2]'s answer sentence ("second claim is cited first") matches
        // src-b's sentence via "second" overlap; [1] matches src-a.
        #expect(extraction.claims.count == 2)
        #expect(Set(extraction.claims.flatMap { $0.evidenceSpans.map(\.sourceID) }) == Set(["src-a", "src-b"]))
        #expect(extraction.unmatchedCitationIndices.isEmpty)
    }

    @Test func unmatchedWhenSourceTextMissing() {
        let answer = "A claim with no fetched text behind it. [1]"
        let sources = [ClaimExtractor.SourceInput(sourceID: "src-1", extractedText: nil)]

        let extraction = extractor().extractClaims(answer: answer, sources: sources)

        #expect(extraction.claims.isEmpty)
        #expect(extraction.unmatchedCitationIndices == [0])
    }

    @Test func unmatchedWhenNoOverlap() {
        let answer = "Quantum entanglement experiments at CERN. [1]"
        let sources = [
            ClaimExtractor.SourceInput(sourceID: "src-1",
                                       extractedText: "Recipes for sourdough bread and weekend gardening tips.")
        ]

        let extraction = extractor().extractClaims(answer: answer, sources: sources)

        #expect(extraction.claims.isEmpty, "no fabricated claim from unrelated text")
        #expect(extraction.unmatchedCitationIndices == [0])
    }

    @Test func extractsMultipleClaimsForMultipleCitations() {
        let answer = "Hive stores everything locally. [1] It also runs on device. [2]"
        let sources = [
            ClaimExtractor.SourceInput(sourceID: "s1", extractedText: "Hive stores everything locally on your machine."),
            ClaimExtractor.SourceInput(sourceID: "s2", extractedText: "The browser runs on device with no cloud dependency."),
        ]

        let extraction = extractor().extractClaims(answer: answer, sources: sources)

        #expect(extraction.claims.count == 2)
        #expect(extraction.unmatchedCitationIndices.isEmpty)
        let claimForS1 = extraction.claims.first { $0.evidenceSpans.first?.sourceID == "s1" }
        let claimForS2 = extraction.claims.first { $0.evidenceSpans.first?.sourceID == "s2" }
        #expect(claimForS1?.text.contains("stores everything locally") == true)
        #expect(claimForS2?.text.contains("runs on device") == true)
    }

    @Test func outOfRangeCitationIsUnmatched() {
        let answer = "Citation pointing past the source list. [5]"
        let sources = [ClaimExtractor.SourceInput(sourceID: "s1", extractedText: "Some text here.")]

        let extraction = extractor().extractClaims(answer: answer, sources: sources)

        #expect(extraction.claims.isEmpty)
        #expect(extraction.unmatchedCitationIndices == [4])
    }

    @Test func malformedZeroCitationIsUnmatched() {
        let answer = "A malformed [0] marker must not crash or fabricate. [0]"
        let sources = [ClaimExtractor.SourceInput(sourceID: "s1", extractedText: "Some text here.")]

        let extraction = extractor().extractClaims(answer: answer, sources: sources)

        #expect(extraction.claims.isEmpty)
        #expect(extraction.unmatchedCitationIndices == [-1, -1],
                "each malformed marker is reported; -1 documents that neither citation grounded")
    }

    @Test func adjacentCitationsShareThePrecedingSentence() {
        let answer = "The local graph is searchable. [1][2]"
        let sources = [
            ClaimExtractor.SourceInput(sourceID: "s1", extractedText: "The local graph is searchable and indexed."),
            ClaimExtractor.SourceInput(sourceID: "s2", extractedText: "The local graph is searchable across all projects."),
        ]

        let extraction = extractor().extractClaims(answer: answer, sources: sources)

        #expect(extraction.claims.count == 2)
        #expect(Set(extraction.claims.flatMap { $0.evidenceSpans.map(\.sourceID) }) == Set(["s1", "s2"]))
        #expect(extraction.unmatchedCitationIndices.isEmpty)
    }

    @Test func unicodeBeforeCitationKeepsSpanOffsetsSafe() {
        let answer = "Hive keeps your résumé and notes local. [1]"
        let sourceText = "Hive keeps your résumé and notes local on this device."
        let extraction = extractor().extractClaims(
            answer: answer,
            sources: [ClaimExtractor.SourceInput(sourceID: "unicode", extractedText: sourceText)]
        )

        #expect(extraction.claims.count == 1)
        guard let span = extraction.claims.first?.evidenceSpans.first else {
            Issue.record("expected a Unicode-safe evidence span")
            return
        }
        let start = sourceText.utf16.index(sourceText.utf16.startIndex, offsetBy: span.startOffset)
        let end = sourceText.utf16.index(sourceText.utf16.startIndex, offsetBy: span.endOffset)
        #expect(String(decoding: sourceText.utf16[start..<end], as: UTF16.self) == span.quote)
    }

    @Test func noMarkersProducesNoClaims() {
        let answer = "A plain answer with no citation markers at all."
        let sources = [ClaimExtractor.SourceInput(sourceID: "s1", extractedText: "Any text here.")]

        let extraction = extractor().extractClaims(answer: answer, sources: sources)

        #expect(extraction.claims.isEmpty)
        #expect(extraction.unmatchedCitationIndices.isEmpty)
    }
}
