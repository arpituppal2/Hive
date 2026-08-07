import Foundation
import Testing
@testable import HiveCore

@Suite("TabDropCoordinate")
struct TabDropCoordinateTests {
    @Test("uses the actual midpoint for before and after")
    func midpoint() {
        #expect(TabDropCoordinate.insertionEdge(x: 0, targetWidth: 100) == .before)
        #expect(TabDropCoordinate.insertionEdge(x: 49.9, targetWidth: 100) == .before)
        #expect(TabDropCoordinate.insertionEdge(x: 50, targetWidth: 100) == .after)
        #expect(TabDropCoordinate.insertionEdge(x: 100, targetWidth: 100) == .after)
    }

    @Test("supports variable rendered widths")
    func variableWidths() {
        #expect(TabDropCoordinate.insertionEdge(x: 39, targetWidth: 80) == .before)
        #expect(TabDropCoordinate.insertionEdge(x: 40, targetWidth: 80) == .after)
        #expect(TabDropCoordinate.insertionEdge(x: 119, targetWidth: 240) == .before)
        #expect(TabDropCoordinate.insertionEdge(x: 120, targetWidth: 240) == .after)
    }

    @Test("clamps finite coordinates at the target boundaries")
    func clampedCoordinates() {
        #expect(TabDropCoordinate.insertionEdge(x: -10, targetWidth: 100) == .before)
        #expect(TabDropCoordinate.insertionEdge(x: 110, targetWidth: 100) == .after)
    }

    @Test("rejects invalid dimensions and non-finite coordinates")
    func invalidGeometry() {
        #expect(TabDropCoordinate.insertionEdge(x: .nan, targetWidth: 100) == nil)
        #expect(TabDropCoordinate.insertionEdge(x: 20, targetWidth: .nan) == nil)
        #expect(TabDropCoordinate.insertionEdge(x: 20, targetWidth: 0) == nil)
        #expect(TabDropCoordinate.insertionEdge(x: 20, targetWidth: -1) == nil)
    }
}
