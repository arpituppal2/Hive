import Foundation

public struct MarkovTransition: Hashable, Sendable {
    public var fromID: String
    public var toID: String
    public var probability: Double
    public var rawWeight: Double
    public var evidenceCount: Int
    public var sourceRefs: [String]
    public var reason: String
}

public struct MarkovLoop: Identifiable, Hashable, Sendable {
    public var id: String
    public var nodeIDs: [String]
    public var probabilityScore: Double
    public var sourceRefs: [String]
    public var reason: String

    public init(nodeIDs: [String], probabilityScore: Double, sourceRefs: [String], reason: String) {
        self.id = MarkovLoop.canonicalID(nodeIDs)
        self.nodeIDs = nodeIDs
        self.probabilityScore = probabilityScore
        self.sourceRefs = sourceRefs
        self.reason = reason
    }

    private static func canonicalID(_ ids: [String]) -> String {
        guard !ids.isEmpty else { return "loop-empty" }
        let rotations = ids.indices.map { index in
            Array(ids[index...]) + Array(ids[..<index])
        }
        return "loop:" + (rotations.min { $0.joined(separator: "|") < $1.joined(separator: "|") } ?? ids).joined(separator: "->")
    }
}

public struct HamiltonianPathCandidate: Identifiable, Hashable, Sendable {
    public var id: String
    public var nodeIDs: [String]
    public var probabilityScore: Double
    public var exact: Bool
    public var sourceRefs: [String]
    public var reason: String

    public init(nodeIDs: [String], probabilityScore: Double, exact: Bool, sourceRefs: [String], reason: String) {
        self.id = "hamiltonian:" + nodeIDs.joined(separator: "->")
        self.nodeIDs = nodeIDs
        self.probabilityScore = probabilityScore
        self.exact = exact
        self.sourceRefs = sourceRefs
        self.reason = reason
    }
}

public struct MarkovStationaryScore: Hashable, Sendable {
    public var nodeID: String
    public var score: Double
}

public struct MarkovGraphAnalysis: Sendable {
    public var transitions: [MarkovTransition]
    public var loops: [MarkovLoop]
    public var hamiltonianPaths: [HamiltonianPathCandidate]
    public var stationaryScores: [MarkovStationaryScore]
}

public struct MarkovGraphAnalyzer: Sendable {
    fileprivate struct EvidenceNode: Hashable {
        var id: String
        var title: String
        var kind: GraphNodeKind
        var sourceRefs: [String]
        var tokens: Set<String>
        var confidence: Double
        var date: Date
    }

    public init() {}

    public func analyze(
        sources: [SourceRecord],
        claims: [ClaimRecord],
        entities: [EntityRecord],
        maxTransitionsPerNode: Int = 4
    ) -> MarkovGraphAnalysis {
        let nodes = evidenceNodes(sources: sources, claims: claims, entities: entities)
        let transitions = markovTransitions(nodes: nodes, maxTransitionsPerNode: maxTransitionsPerNode)
        let loops = localLoops(transitions: transitions, nodes: nodes)
        let paths = hamiltonianPaths(transitions: transitions, nodes: nodes)
        let stationary = stationaryScores(transitions: transitions, nodeIDs: nodes.map(\.id))
        return MarkovGraphAnalysis(transitions: transitions, loops: loops, hamiltonianPaths: paths, stationaryScores: stationary)
    }

    public func deriveInsightClaims(
        sources: [SourceRecord],
        claims: [ClaimRecord],
        entities: [EntityRecord],
        relationships: [RelationshipRecord],
        maxInsights: Int = 6
    ) -> [ClaimRecord] {
        let analysis = analyze(sources: sources, claims: claims, entities: entities)
        let evidence = evidenceNodes(sources: sources, claims: claims, entities: entities)
        let nodesByID = Dictionary(uniqueKeysWithValues: evidence.map { ($0.id, $0) })
        let reviewOnlySourceIDs = Set(sources.filter { source in
            source.kind == .browserHistory
                || source.privacyLabel == .cloudBlocked
                || source.status == .needsReview
                || source.connector == "ai-memory-import"
                || source.title.localizedCaseInsensitiveContains("AI Memory Seed")
                || source.title.localizedCaseInsensitiveContains("# HIVE MEMORY SEED")
        }.map(\.id))
        let promotableNodeIDs = Set(evidence.filter { node in
            !node.sourceRefs.contains { reviewOnlySourceIDs.contains($0) }
        }.map(\.id))
        let existingStatements = Set(claims.map { normalizeStatement($0.statement) })
        var insights: [ClaimRecord] = []

        for loop in analysis.loops.prefix(3) {
            guard loop.nodeIDs.allSatisfy({ promotableNodeIDs.contains($0) }) else { continue }
            let titles = loop.nodeIDs.compactMap { nodesByID[$0]?.titleForInsight }.prefix(5)
            guard titles.count >= 3 else { continue }
            let statement = "\(titles.joined(separator: " -> ")) forms a recurrent local loop; changes or corrections to one item should be reviewed against the others."
            appendInsight(
                statement: statement,
                confidence: min(0.86, max(0.58, loop.probabilityScore)),
                sourceRefs: loop.sourceRefs,
                reason: loop.reason,
                existingStatements: existingStatements,
                insights: &insights
            )
        }

        for path in analysis.hamiltonianPaths.prefix(2) {
            guard path.nodeIDs.allSatisfy({ promotableNodeIDs.contains($0) }) else { continue }
            let titles = path.nodeIDs.compactMap { nodesByID[$0]?.titleForInsight }
            guard titles.count >= 4 else { continue }
            let bridge = titles.dropFirst().dropLast().first ?? titles[titles.index(after: titles.startIndex)]
            let statement = "\(bridge) appears to bridge \(titles.first ?? "one cluster") and \(titles.last ?? "another cluster") across a \(titles.count)-item \(path.exact ? "Hamiltonian" : "near-Hamiltonian") path."
            appendInsight(
                statement: statement,
                confidence: min(0.82, max(0.56, path.probabilityScore)),
                sourceRefs: path.sourceRefs,
                reason: path.reason,
                existingStatements: existingStatements,
                insights: &insights
            )
        }

        let incoming = incomingTransitionCounts(analysis.transitions)
        for score in analysis.stationaryScores.prefix(3) {
            guard let node = nodesByID[score.nodeID], incoming[score.nodeID, default: 0] >= 2 else { continue }
            guard promotableNodeIDs.contains(score.nodeID) else { continue }
            let statement = "\(node.titleForInsight) is a high-centrality memory node; multiple local paths converge there, so it is likely useful as a review anchor."
            appendInsight(
                statement: statement,
                confidence: min(0.8, max(0.54, score.score * 4)),
                sourceRefs: node.sourceRefs,
                reason: "Stationary Markov centrality \(String(format: "%.3f", score.score)) with \(incoming[score.nodeID, default: 0]) incoming transitions.",
                existingStatements: existingStatements,
                insights: &insights
            )
        }

        return Array(insights.prefix(maxInsights))
    }

    public func markovTransitions(
        sources: [SourceRecord],
        claims: [ClaimRecord],
        entities: [EntityRecord],
        maxTransitionsPerNode: Int = 4
    ) -> [MarkovTransition] {
        markovTransitions(
            nodes: evidenceNodes(sources: sources, claims: claims, entities: entities),
            maxTransitionsPerNode: maxTransitionsPerNode
        )
    }

    private func markovTransitions(nodes: [EvidenceNode], maxTransitionsPerNode: Int) -> [MarkovTransition] {
        guard nodes.count > 1 else { return [] }
        var outgoing: [String: [(EvidenceNode, Double, Int, [String], String)]] = [:]
        let nodesByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let candidateIDs = candidateIDsByNode(nodes: nodes)

        for from in nodes {
            for toID in candidateIDs[from.id] ?? [] {
                guard let to = nodesByID[toID], from.id != to.id else { continue }
                let weighted = transitionWeight(from: from, to: to)
                guard weighted.weight >= 0.18 else { continue }
                outgoing[from.id, default: []].append((to, weighted.weight, weighted.evidenceCount, weighted.sourceRefs, weighted.reason))
            }
        }

        var transitions: [MarkovTransition] = []
        for from in nodes {
            let ranked = (outgoing[from.id] ?? [])
                .sorted {
                    if $0.1 == $1.1 { return $0.0.title < $1.0.title }
                    return $0.1 > $1.1
                }
                .prefix(maxTransitionsPerNode)
            let totalWeight = ranked.map(\.1).reduce(0, +)
            guard totalWeight > 0 else { continue }
            transitions.append(contentsOf: ranked.map { to, weight, evidenceCount, sourceRefs, reason in
                MarkovTransition(
                    fromID: from.id,
                    toID: to.id,
                    probability: weight / totalWeight,
                    rawWeight: weight,
                    evidenceCount: evidenceCount,
                    sourceRefs: sourceRefs,
                    reason: reason
                )
            })
        }
        return transitions
    }

    private func candidateIDsByNode(nodes: [EvidenceNode]) -> [String: [String]] {
        let nodesByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let sortedByDate = nodes.sorted {
            if $0.date == $1.date { return $0.id < $1.id }
            return $0.date < $1.date
        }
        let dateIndex = Dictionary(uniqueKeysWithValues: sortedByDate.enumerated().map { ($0.element.id, $0.offset) })
        var sourceIndex: [String: [String]] = [:]
        var tokenIndex: [String: [String]] = [:]
        for node in nodes {
            for sourceRef in node.sourceRefs {
                sourceIndex[sourceRef, default: []].append(node.id)
            }
            for token in node.tokens {
                tokenIndex[token, default: []].append(node.id)
            }
        }

        return Dictionary(uniqueKeysWithValues: nodes.map { node in
            var ids: Set<String> = []
            for sourceRef in node.sourceRefs {
                ids.formUnion(sourceIndex[sourceRef] ?? [])
            }
            for token in node.tokens {
                ids.formUnion((tokenIndex[token] ?? []).prefix(160))
            }
            if ids.count < 12 {
                ids.formUnion(temporalNeighborIDs(for: node, sortedNodes: sortedByDate, indexByID: dateIndex, limit: 24))
            }
            ids.remove(node.id)
            let ranked = ids.compactMap { nodesByID[$0] }
                .sorted { left, right in
                    candidatePrecedes(left, right, from: node)
                }
                .prefix(256)
                .map(\.id)
            return (node.id, Array(ranked))
        })
    }

    private func temporalNeighborIDs(
        for node: EvidenceNode,
        sortedNodes: [EvidenceNode],
        indexByID: [String: Int],
        limit: Int
    ) -> [String] {
        guard let index = indexByID[node.id] else { return [] }
        var ids: [String] = []
        var left = index - 1
        var right = index + 1
        while ids.count < limit && (left >= 0 || right < sortedNodes.count) {
            let chooseLeft: Bool
            if left < 0 {
                chooseLeft = false
            } else if right >= sortedNodes.count {
                chooseLeft = true
            } else {
                let leftDistance = abs(sortedNodes[left].date.timeIntervalSince(node.date))
                let rightDistance = abs(sortedNodes[right].date.timeIntervalSince(node.date))
                chooseLeft = leftDistance <= rightDistance
            }
            if chooseLeft {
                ids.append(sortedNodes[left].id)
                left -= 1
            } else {
                ids.append(sortedNodes[right].id)
                right += 1
            }
        }
        return ids
    }

    private func candidatePrecedes(_ lhs: EvidenceNode, _ rhs: EvidenceNode, from node: EvidenceNode) -> Bool {
        let leftSourceOverlap = Set(lhs.sourceRefs).intersection(node.sourceRefs).count
        let rightSourceOverlap = Set(rhs.sourceRefs).intersection(node.sourceRefs).count
        if leftSourceOverlap != rightSourceOverlap {
            return leftSourceOverlap > rightSourceOverlap
        }
        let leftTokenOverlap = lhs.tokens.intersection(node.tokens).count
        let rightTokenOverlap = rhs.tokens.intersection(node.tokens).count
        if leftTokenOverlap != rightTokenOverlap {
            return leftTokenOverlap > rightTokenOverlap
        }
        let leftTime = abs(lhs.date.timeIntervalSince(node.date))
        let rightTime = abs(rhs.date.timeIntervalSince(node.date))
        if leftTime != rightTime {
            return leftTime < rightTime
        }
        return lhs.id < rhs.id
    }

    private func transitionWeight(from: EvidenceNode, to: EvidenceNode) -> (weight: Double, evidenceCount: Int, sourceRefs: [String], reason: String) {
        var weight = 0.0
        var evidence = 0
        var reasons: [String] = []

        let sourceOverlap = Set(from.sourceRefs).intersection(Set(to.sourceRefs))
        if !sourceOverlap.isEmpty {
            weight += 1.4 + min(1.2, Double(sourceOverlap.count) * 0.25)
            evidence += sourceOverlap.count
            reasons.append("shared source")
        }

        let tokenOverlap = from.tokens.intersection(to.tokens)
        let tokenUnion = from.tokens.union(to.tokens)
        if !tokenOverlap.isEmpty && !tokenUnion.isEmpty {
            let jaccard = Double(tokenOverlap.count) / Double(tokenUnion.count)
            weight += min(1.1, jaccard * 2.4)
            evidence += tokenOverlap.count
            reasons.append("shared terms")
        }

        if from.kind == .source && to.kind != .source && !sourceOverlap.isEmpty {
            weight += 0.9
            reasons.append("source emits derived node")
        } else if from.kind == .entity && to.kind == .claim && !sourceOverlap.isEmpty {
            weight += 0.75
            reasons.append("topic supports claim")
        } else if from.kind == .claim && to.kind == .entity && !sourceOverlap.isEmpty {
            weight += 0.45
            reasons.append("claim points back to topic")
        }

        let temporalDistance = abs(from.date.timeIntervalSince(to.date))
        if temporalDistance <= 86_400 {
            weight += 0.16
            reasons.append("nearby in time")
        }

        let confidenceMultiplier = max(0.3, (from.confidence + to.confidence) / 2)
        weight *= confidenceMultiplier

        let sourceRefs = Array(sourceOverlap.isEmpty ? Set(from.sourceRefs + to.sourceRefs) : sourceOverlap).sorted()
        return (weight, max(1, evidence), sourceRefs, reasons.isEmpty ? "weak local transition" : reasons.joined(separator: ", "))
    }

    private func localLoops(transitions: [MarkovTransition], nodes: [EvidenceNode]) -> [MarkovLoop] {
        let nodeSourceRefs = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.sourceRefs) })
        let usableTransitions = transitions.filter { $0.probability >= 0.12 }
        let byFrom = Dictionary(grouping: usableTransitions) { $0.fromID }
            .mapValues { edges in
                edges.sorted {
                    if $0.probability == $1.probability { return $0.toID < $1.toID }
                    return $0.probability > $1.probability
                }
            }
        let incomingCounts = usableTransitions.reduce(into: [String: Int]()) { counts, transition in
            counts[transition.toID, default: 0] += 1
        }
        let startIDs = Array(Set(usableTransitions.flatMap { [$0.fromID, $0.toID] }))
            .sorted {
                let left = (byFrom[$0]?.count ?? 0) + incomingCounts[$0, default: 0]
                let right = (byFrom[$1]?.count ?? 0) + incomingCounts[$1, default: 0]
                if left == right { return $0 < $1 }
                return left > right
            }
            .prefix(500)
        var loopsByID: [String: MarkovLoop] = [:]
        let maxDepth = 6
        let maxStoredLoops = 160

        func storeLoop(path: [String], probabilities: [Double]) {
            guard Set(path).count == path.count else { return }
            let probability = geometricMean(probabilities)
            guard probability >= 0.14 else { return }
            let sourceRefs = Array(Set(path.flatMap { nodeSourceRefs[$0] ?? [] })).sorted()
            let loop = MarkovLoop(
                nodeIDs: path,
                probabilityScore: probability,
                sourceRefs: sourceRefs,
                reason: "\(path.count)-node Markov loop with transition probability score \(String(format: "%.3f", probability))."
            )
            if let existing = loopsByID[loop.id] {
                if loop.probabilityScore > existing.probabilityScore {
                    loopsByID[loop.id] = loop
                }
            } else if loopsByID.count < maxStoredLoops {
                loopsByID[loop.id] = loop
            }
        }

        func walk(start: String, current: String, path: [String], probabilities: [Double]) {
            guard loopsByID.count < maxStoredLoops else { return }
            for edge in byFrom[current] ?? [] {
                if edge.toID == start {
                    if path.count >= 3 {
                        storeLoop(path: path, probabilities: probabilities + [edge.probability])
                    }
                    continue
                }
                guard path.count < maxDepth, !path.contains(edge.toID) else { continue }
                walk(
                    start: start,
                    current: edge.toID,
                    path: path + [edge.toID],
                    probabilities: probabilities + [edge.probability]
                )
            }
        }

        for start in startIDs {
            guard loopsByID.count < maxStoredLoops else { break }
            for edge in byFrom[start] ?? [] where edge.toID != start {
                walk(start: start, current: edge.toID, path: [start, edge.toID], probabilities: [edge.probability])
            }
        }

        if loopsByID.isEmpty {
            for first in transitions where first.probability >= 0.2 {
                for second in byFrom[first.toID] ?? [] where second.toID != first.fromID {
                    for third in byFrom[second.toID] ?? [] where third.toID == first.fromID {
                        let ids = [first.fromID, first.toID, second.toID]
                        storeLoop(path: ids, probabilities: [first.probability, second.probability, third.probability])
                    }
                }
            }
        }

        return loopsByID.values.sorted {
            if $0.probabilityScore == $1.probabilityScore { return $0.id < $1.id }
            return $0.probabilityScore > $1.probabilityScore
        }
    }

    private func hamiltonianPaths(transitions: [MarkovTransition], nodes: [EvidenceNode]) -> [HamiltonianPathCandidate] {
        let nodeIDs = Set(nodes.map(\.id))
        guard nodeIDs.count >= 4 else { return [] }
        let components = connectedComponents(nodeIDs: nodeIDs, transitions: transitions.filter { $0.probability >= 0.12 })
        let transitionScores = Dictionary(uniqueKeysWithValues: transitions.map { ("\($0.fromID)|\($0.toID)", $0.probability) })
        let sourceRefsByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.sourceRefs) })
        var paths: [HamiltonianPathCandidate] = []

        for component in components where component.count >= 4 {
            let path: [String]
            let exact: Bool
            if component.count <= 10, let exactPath = exactHamiltonianPath(component: component, transitions: transitions) {
                path = exactPath
                exact = true
            } else {
                path = greedyCoveringPath(component: component, transitions: transitions)
                exact = false
            }
            guard path.count >= 4 else { continue }
            let scores = zip(path, path.dropFirst()).compactMap {
                transitionScores["\($0)|\($1)"] ?? transitionScores["\($1)|\($0)"]
            }
            guard scores.count == path.count - 1 else { continue }
            let score = geometricMean(scores)
            let refs = Array(Set(path.flatMap { sourceRefsByID[$0] ?? [] })).sorted()
            paths.append(HamiltonianPathCandidate(
                nodeIDs: path,
                probabilityScore: score,
                exact: exact,
                sourceRefs: refs,
                reason: exact
                    ? "Local component has a Hamiltonian path over \(path.count) nodes."
                    : "Large component has a high-probability covering path over \(path.count) nodes."
            ))
        }

        return paths.sorted {
            if $0.probabilityScore == $1.probabilityScore { return $0.nodeIDs.count > $1.nodeIDs.count }
            return $0.probabilityScore > $1.probabilityScore
        }
    }

    private func exactHamiltonianPath(component: Set<String>, transitions: [MarkovTransition]) -> [String]? {
        let adjacency = adjacencyMap(transitions: transitions.filter { component.contains($0.fromID) && component.contains($0.toID) })
        let starts = component.sorted {
            (adjacency[$0] ?? []).count > (adjacency[$1] ?? []).count
        }
        for start in starts {
            var visited: Set<String> = [start]
            var path = [start]
            if dfsHamiltonian(current: start, component: component, adjacency: adjacency, visited: &visited, path: &path) {
                return path
            }
        }
        return nil
    }

    private func dfsHamiltonian(
        current: String,
        component: Set<String>,
        adjacency: [String: [String]],
        visited: inout Set<String>,
        path: inout [String]
    ) -> Bool {
        if visited.count == component.count { return true }
        for next in adjacency[current] ?? [] where component.contains(next) && !visited.contains(next) {
            visited.insert(next)
            path.append(next)
            if dfsHamiltonian(current: next, component: component, adjacency: adjacency, visited: &visited, path: &path) {
                return true
            }
            path.removeLast()
            visited.remove(next)
        }
        return false
    }

    private func greedyCoveringPath(component: Set<String>, transitions: [MarkovTransition]) -> [String] {
        let adjacency = adjacencyMap(transitions: transitions.filter { component.contains($0.fromID) && component.contains($0.toID) })
        let starts = component.sorted {
            let leftDegree = adjacency[$0]?.count ?? 0
            let rightDegree = adjacency[$1]?.count ?? 0
            if leftDegree == rightDegree { return $0 < $1 }
            return leftDegree > rightDegree
        }
        var best: [String] = []
        for start in starts.prefix(24) {
            var current = start
            var path = [current]
            var visited: Set<String> = [current]
            while visited.count < component.count {
                guard let next = (adjacency[current] ?? []).first(where: { !visited.contains($0) }) else {
                    break
                }
                current = next
                visited.insert(current)
                path.append(current)
            }
            if path.count > best.count || (path.count == best.count && path.joined(separator: "|") < best.joined(separator: "|")) {
                best = path
            }
        }
        return best
    }

    private func connectedComponents(nodeIDs: Set<String>, transitions: [MarkovTransition]) -> [Set<String>] {
        var adjacency: [String: Set<String>] = [:]
        for transition in transitions {
            adjacency[transition.fromID, default: []].insert(transition.toID)
            adjacency[transition.toID, default: []].insert(transition.fromID)
        }
        var remaining = nodeIDs
        var components: [Set<String>] = []
        while let start = remaining.first {
            var stack = [start]
            var component: Set<String> = []
            remaining.remove(start)
            while let node = stack.popLast() {
                component.insert(node)
                for next in adjacency[node] ?? [] where remaining.contains(next) {
                    remaining.remove(next)
                    stack.append(next)
                }
            }
            components.append(component)
        }
        return components.sorted { $0.count > $1.count }
    }

    private func adjacencyMap(transitions: [MarkovTransition]) -> [String: [String]] {
        var weighted: [String: [(String, Double)]] = [:]
        for transition in transitions {
            weighted[transition.fromID, default: []].append((transition.toID, transition.probability))
            weighted[transition.toID, default: []].append((transition.fromID, transition.probability * 0.72))
        }
        return weighted.mapValues { values in
            values
                .sorted {
                    if $0.1 == $1.1 { return $0.0 < $1.0 }
                    return $0.1 > $1.1
                }
                .map(\.0)
        }
    }

    private func stationaryScores(transitions: [MarkovTransition], nodeIDs: [String]) -> [MarkovStationaryScore] {
        guard !nodeIDs.isEmpty else { return [] }
        let ids = Array(Set(nodeIDs)).sorted()
        let n = Double(ids.count)
        var scores = Dictionary(uniqueKeysWithValues: ids.map { ($0, 1.0 / n) })
        let outgoing = Dictionary(grouping: transitions) { $0.fromID }
        let damping = 0.86

        for _ in 0..<48 {
            var next = Dictionary(uniqueKeysWithValues: ids.map { ($0, (1 - damping) / n) })
            for id in ids {
                let current = scores[id, default: 0]
                let edges = outgoing[id] ?? []
                if edges.isEmpty {
                    for target in ids {
                        next[target, default: 0] += damping * current / n
                    }
                } else {
                    let probabilityMass = edges.map(\.probability).reduce(0, +)
                    for edge in edges {
                        next[edge.toID, default: 0] += damping * current * (edge.probability / max(probabilityMass, 0.0001))
                    }
                }
            }
            scores = next
        }

        return scores.map { MarkovStationaryScore(nodeID: $0.key, score: $0.value) }
            .sorted {
                if $0.score == $1.score { return $0.nodeID < $1.nodeID }
                return $0.score > $1.score
            }
    }

    private func evidenceNodes(sources: [SourceRecord], claims: [ClaimRecord], entities: [EntityRecord]) -> [EvidenceNode] {
        var nodes: [EvidenceNode] = []
        let rawEvidenceSourceIDs = Set(sources.filter { source in
            source.kind == .browserHistory
                || source.kind == .browserBookmark
                || source.status == .needsReview
                || source.deletionState == .fullForgotten
        }.map(\.id))
        for claim in claims where claim.status != .retracted {
            guard claim.claimType != "browser-observation",
                  claim.claimType != "browser-signal",
                  claim.claimType != "browser-session-intent",
                  !claim.sourceRefs.contains(where: { rawEvidenceSourceIDs.contains($0) }),
                  !MemoryCompiler.isRawLinkLike(claim.statement) else { continue }
            nodes.append(EvidenceNode(
                id: claim.id,
                title: claim.statement,
                kind: claim.claimType == "graph-insight" ? .insight : .claim,
                sourceRefs: claim.sourceRefs,
                tokens: tokens(in: claim.statement),
                confidence: claim.confidence,
                date: claim.createdAt
            ))
        }
        for entity in entities {
            guard EntitySignalPolicy.isMeaningfulName(entity.name),
                  !MemoryCompiler.isRawLinkLike(entity.name),
                  !entity.sourceRefs.contains(where: { rawEvidenceSourceIDs.contains($0) }) else { continue }
            nodes.append(EvidenceNode(
                id: entity.id,
                title: entity.name,
                kind: nodeKind(for: entity),
                sourceRefs: entity.sourceRefs,
                tokens: tokens(in: entity.name),
                confidence: entity.confidence,
                date: entity.createdAt
            ))
        }
        return nodes
    }

    private func nodeKind(for entity: EntityRecord) -> GraphNodeKind {
        switch entity.entityType.lowercased() {
        case "project":
            return .project
        case "event":
            return .event
        case "task":
            return .task
        case "habit":
            return .habit
        case "topic":
            return .topic
        default:
            return .entity
        }
    }

    private func appendInsight(
        statement: String,
        confidence: Double,
        sourceRefs: [String],
        reason: String,
        existingStatements: Set<String>,
        insights: inout [ClaimRecord]
    ) {
        guard !sourceRefs.isEmpty, !existingStatements.contains(normalizeStatement(statement)) else { return }
        guard !insights.contains(where: { normalizeStatement($0.statement) == normalizeStatement(statement) }) else { return }
        insights.append(ClaimRecord(
            statement: statement,
            claimType: "graph-insight",
            sourceRefs: sourceRefs,
            sourceSpanRefs: [],
            confidence: confidence,
            uncertaintyReason: "Derived from Markov graph analysis: \(reason)"
        ))
    }

    private func incomingTransitionCounts(_ transitions: [MarkovTransition]) -> [String: Int] {
        transitions.reduce(into: [String: Int]()) { counts, transition in
            counts[transition.toID, default: 0] += 1
        }
    }

    private func geometricMean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let product = values.reduce(1.0) { $0 * max($1, 0.0001) }
        return pow(product, 1.0 / Double(values.count))
    }

    private func tokens(in text: String) -> Set<String> {
        Set(
            text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 3 && !stopWords.contains($0) }
        )
    }

    private func normalizeStatement(_ statement: String) -> String {
        statement
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var stopWords: Set<String> {
        [
            "with", "that", "this", "from", "into", "there", "their", "about",
            "source", "claim", "item", "should", "could", "would", "memory",
            "review", "forms", "local", "graph"
        ]
    }
}

private extension MarkovGraphAnalyzer.EvidenceNode {
    var titleForInsight: String {
        let cleaned = title.replacingOccurrences(of: "\n", with: " ")
        if cleaned.count <= 64 { return cleaned }
        return String(cleaned.prefix(61)) + "..."
    }
}
