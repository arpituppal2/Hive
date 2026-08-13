import Foundation
import Testing
@testable import HiveCore

@Suite("TabRenamePolicy")
struct TabRenamePolicyTests {

    @Test("Trims surrounding whitespace")
    func trimsWhitespace() {
        #expect(TabRenamePolicy.normalized("   My Tab  ") == "My Tab")
        #expect(TabRenamePolicy.normalized("\tPinned\t") == "Pinned")
    }

    @Test("Whitespace-only input normalizes to empty")
    func whitespaceOnlyIsEmpty() {
        #expect(TabRenamePolicy.normalized("   ") == "")
        #expect(TabRenamePolicy.normalized("") == "")
        #expect(TabRenamePolicy.normalized("\n\t\n") == "")
    }

    @Test("Interior newlines collapse to a single space")
    func newlinesCollapse() {
        #expect(TabRenamePolicy.normalized("Line One\nLine Two") == "Line One Line Two")
        #expect(TabRenamePolicy.normalized("A\n\n\nB") == "A B")
        // A pasted multi-line title keeps its single-space shape after trim.
        #expect(TabRenamePolicy.normalized("  Docs\nOverview  ") == "Docs Overview")
    }

    @Test("Length is capped at the policy maximum")
    func lengthCapped() {
        let long = String(repeating: "x", count: 200)
        let result = TabRenamePolicy.normalized(long)
        #expect(result.count == TabRenamePolicy.maxLength)
        // A name at exactly the cap is untouched.
        let exact = String(repeating: "y", count: TabRenamePolicy.maxLength)
        #expect(TabRenamePolicy.normalized(exact) == exact)
    }

    @Test("Internal single spaces are preserved")
    func internalSpacesPreserved() {
        #expect(TabRenamePolicy.normalized("GitHub Issues") == "GitHub Issues")
    }

    @Test("Emoji and non-ASCII names survive intact")
    func unicodeSurvives() {
        #expect(TabRenamePolicy.normalized("  Búsqueda 🔍  ") == "Búsqueda 🔍")
    }
}
