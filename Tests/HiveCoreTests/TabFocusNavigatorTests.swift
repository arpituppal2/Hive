import Testing
@testable import HiveCore

@Suite("TabFocusNavigator")
struct TabFocusNavigatorTests {
    @Test("moves in both directions and wraps by default")
    func movesAndWraps() {
        let ids = ["a", "b", "c"]
        #expect(TabFocusNavigator.destination(in: ids, focusedID: "b", direction: .next) == "c")
        #expect(TabFocusNavigator.destination(in: ids, focusedID: "b", direction: .previous) == "a")
        #expect(TabFocusNavigator.destination(in: ids, focusedID: "c", direction: .next) == "a")
        #expect(TabFocusNavigator.destination(in: ids, focusedID: "a", direction: .previous) == "c")
    }

    @Test("starts at the direction boundary without a current focus")
    func startsWithoutFocus() {
        let ids = ["a", "b", "c"]
        #expect(TabFocusNavigator.destination(in: ids, focusedID: nil, direction: .next) == "a")
        #expect(TabFocusNavigator.destination(in: ids, focusedID: nil, direction: .previous) == "c")
    }

    @Test("does not leave the supplied projection for an unknown focus ID")
    func unknownFocusIsBounded() {
        let ids = ["visible-a", "visible-b"]
        #expect(TabFocusNavigator.destination(in: ids, focusedID: "hidden", direction: .next) == "visible-a")
        #expect(TabFocusNavigator.destination(in: ids, focusedID: "hidden", direction: .previous) == "visible-b")
    }

    @Test("supports non-wrapping boundaries")
    func nonWrappingBoundaries() {
        let ids = ["a", "b"]
        #expect(TabFocusNavigator.destination(in: ids, focusedID: "a", direction: .previous, wraps: false) == nil)
        #expect(TabFocusNavigator.destination(in: ids, focusedID: "b", direction: .next, wraps: false) == nil)
        #expect(TabFocusNavigator.destination(in: ids, focusedID: "a", direction: .next, wraps: false) == "b")
    }

    @Test("normalizes empty and duplicate IDs while preserving first order")
    func normalizesProjection() {
        let ids = ["", "a", "a", "b", "", "c"]
        #expect(TabFocusNavigator.normalizedIDs(ids) == ["a", "b", "c"])
        #expect(TabFocusNavigator.destination(in: ids, focusedID: "a", direction: .next) == "b")
    }

    @Test("returns nil for an empty projection")
    func emptyProjection() {
        #expect(TabFocusNavigator.destination(in: [], focusedID: nil, direction: .next) == nil)
        #expect(TabFocusNavigator.destination(in: ["", ""], focusedID: "", direction: .previous) == nil)
    }

@Test("wrappingAtBoundariesIsDefault")
    func wrappingDefault() {
        let ids = ["x", "y", "z"]
        #expect(TabFocusNavigator.destination(in: ids, focusedID: "z", direction: .next) == "x")
        #expect(TabFocusNavigator.destination(in: ids, focusedID: "x", direction: .previous) == "z")
    }

    @Test("singleElementListIsStable")
    func singleElement() {
        let ids = ["only"]
        #expect(TabFocusNavigator.destination(in: ids, focusedID: "only", direction: .next) == "only")
        #expect(TabFocusNavigator.destination(in: ids, focusedID: nil, direction: .previous) == "only")
    }

@Test func normalizedIDsRemovesDuplicates() {
        let result = TabFocusNavigator.normalizedIDs(["a", "b", "a", "c"])
        #expect(result == ["a", "b", "c"])
    }

@Test func directionNextAdvances() {
        let result = TabFocusNavigator.destination(in: ["a", "b", "c"], focusedID: "a", direction: .next, wraps: false)
        #expect(result == "b")
    }
}
