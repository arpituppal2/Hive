import Foundation

/// A point in the [-1, 1] semantic plane used by the overlap resolver.
public struct SemanticPoint: Hashable, Sendable {
    public var id: String
    public var x: Double
    public var y: Double

    public init(id: String, x: Double, y: Double) {
        self.id = id
        self.x = x
        self.y = y
    }
}

/// Prompt 1b "Overlap Resolution".
///
/// A pure, deterministic force-directed repulsion pass over 2D points in the
/// `[-1, 1]` semantic plane. Points closer than `minimumDistance` are pushed
/// apart iteratively. If overlaps remain after `maxIterations`, the remaining
/// overlapping nodes are deterministically offset and an overflow warning is
/// raised. Every coordinate is clamped to `[-1, 1]` at the end.
public struct GraphOverlapResolver: Sendable {
    public init() {}

    /// Resolves overlapping points using iterative force-directed repulsion.
    ///
    /// - Parameters:
    ///   - points: The points to separate.
    ///   - minimumDistance: The minimum permitted Euclidean distance between any two points.
    ///   - maxIterations: The maximum number of repulsion passes.
    /// - Returns: The resolved points plus a flag indicating whether overlaps
    ///   could not be fully resolved within `maxIterations`.
    public func resolve(
        _ points: [SemanticPoint],
        minimumDistance: Double = 0.005,
        maxIterations: Int = 500
    ) -> (points: [SemanticPoint], overflowWarning: Bool) {
        guard points.count > 1, minimumDistance > 0 else {
            return (points.map(clamped(_:)), false)
        }

        var working = points
        let count = working.count
        var overflowWarning = false

        for _ in 0..<maxIterations {
            var displacementX = [Double](repeating: 0, count: count)
            var displacementY = [Double](repeating: 0, count: count)
            var violations = 0

            for a in 0..<(count - 1) {
                for b in (a + 1)..<count {
                    let dx = working[a].x - working[b].x
                    let dy = working[a].y - working[b].y
                    let distance = (dx * dx + dy * dy).squareRoot()
                    guard distance < minimumDistance else { continue }
                    violations += 1

                    let unit: (x: Double, y: Double)
                    if distance == 0 {
                        unit = jitterDirection(idA: working[a].id, idB: working[b].id)
                    } else {
                        unit = (dx / distance, dy / distance)
                    }

                    let repulsion = (minimumDistance - distance) * 0.5
                    displacementX[a] += unit.x * repulsion
                    displacementY[a] += unit.y * repulsion
                    displacementX[b] -= unit.x * repulsion
                    displacementY[b] -= unit.y * repulsion
                }
            }

            if violations == 0 {
                break
            }

            for index in 0..<count {
                working[index].x += displacementX[index]
                working[index].y += displacementY[index]
            }
        }

        // Determine whether overlaps remain after the iteration budget is spent.
        var overlapCounts = [Int](repeating: 0, count: count)
        for a in 0..<(count - 1) {
            for b in (a + 1)..<count {
                let dx = working[a].x - working[b].x
                let dy = working[a].y - working[b].y
                let distance = (dx * dx + dy * dy).squareRoot()
                if distance < minimumDistance {
                    overlapCounts[a] += 1
                    overlapCounts[b] += 1
                }
            }
        }

        if overlapCounts.contains(where: { $0 > 0 }) {
            overflowWarning = true
            // Clamp remaining overlapping nodes by offsetting along the angle
            // atan2(B.y-A.y, B.x-A.x) + .pi / N, where N is the node's overlap count.
            for a in 0..<(count - 1) {
                for b in (a + 1)..<count {
                    let dx = working[a].x - working[b].x
                    let dy = working[a].y - working[b].y
                    let distance = (dx * dx + dy * dy).squareRoot()
                    guard distance < minimumDistance else { continue }

                    let baseAngle = atan2(working[b].y - working[a].y, working[b].x - working[a].x)
                    let countA = max(1, overlapCounts[a])
                    let countB = max(1, overlapCounts[b])
                    let angleA = baseAngle + .pi / Double(countA)
                    let angleB = baseAngle + .pi / Double(countB)
                    let offset = minimumDistance

                    working[a].x += cos(angleA) * offset
                    working[a].y += sin(angleA) * offset
                    working[b].x -= cos(angleB) * offset
                    working[b].y -= sin(angleB) * offset
                }
            }
        }

        working = working.map(clamped(_:))
        return (working, overflowWarning)
    }

    /// Maps `GraphNodeRecord` coordinates into `SemanticPoint`s, resolves
    /// overlaps, and writes the resolved coordinates back into copies of the
    /// nodes (matched by `id`).
    public func resolved(
        nodes: [GraphNodeRecord],
        minimumDistance: Double = 0.005
    ) -> [GraphNodeRecord] {
        let points = nodes.map { SemanticPoint(id: $0.id, x: $0.x, y: $0.y) }
        let result = resolve(points, minimumDistance: minimumDistance)

        var resolvedByID: [String: SemanticPoint] = [:]
        resolvedByID.reserveCapacity(result.points.count)
        for point in result.points {
            resolvedByID[point.id] = point
        }

        return nodes.map { node in
            guard let point = resolvedByID[node.id] else { return node }
            var copy = node
            copy.x = point.x
            copy.y = point.y
            return copy
        }
    }

    // MARK: - Helpers

    private func clamped(_ point: SemanticPoint) -> SemanticPoint {
        SemanticPoint(
            id: point.id,
            x: min(1.0, max(-1.0, point.x)),
            y: min(1.0, max(-1.0, point.y))
        )
    }

    /// Deterministic small jitter direction derived from the two ids' hash
    /// values so that coincident points separate reproducibly.
    private func jitterDirection(idA: String, idB: String) -> (x: Double, y: Double) {
        let seed = idA.hashValue ^ (idB.hashValue &* 31)
        let angle = Double(seed & 0xFFFF) / Double(0xFFFF) * 2.0 * .pi
        return (cos(angle), sin(angle))
    }
}
