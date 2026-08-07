import Foundation
import HiveCore

// MARK: - CommandPaletteEngine

/// Pure, deterministic search engine for the command palette. It is intentionally stateless:
/// given a query and a snapshot of browser state it returns grouped, scored results.
struct CommandPaletteEngine {

    static let registry = CommandRegistry()

    // MARK: - Types

    struct ScoredResult: Identifiable {
        let result: PaletteResult
        let score: Double
        var id: String { result.id }
    }

    struct Section: Identifiable {
        let section: PaletteSection
        let results: [ScoredResult]
        var id: String { section.rawValue }
    }

    // MARK: - Public search

    @MainActor
    static func search(
        query rawQuery: String,
        state: ChromeState,
        usageCounts: [String: Int]
    ) -> [Section] {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return emptyStateSections(state: state, usageCounts: usageCounts)
        }

        let q = trimmed.lowercased()
        var all: [ScoredResult] = []

        // Commands
        for cmd in registry.allCommands {
            let s = score(cmd.title, query: q)
                + maxScore(for: cmd.keywords, query: q)
                + score(cmd.id.rawValue, query: q)
            let final = applyUsage(score: s, id: "cmd-\(cmd.id.rawValue)", usageCounts: usageCounts)
            guard final > 0 else { continue }
            all.append(.init(result: .command(cmd), score: final))
        }

        // Open tabs
        for tab in state.tabs {
            let s = max(score(tab.title, query: q),
                        score(tab.url?.host ?? "", query: q),
                        score(tab.url?.absoluteString ?? "", query: q))
            let final = applyUsage(score: s, id: "tab-\(tab.id)", usageCounts: usageCounts)
            guard final > 0 else { continue }
            all.append(.init(result: .tab(tab), score: final))
        }

        // Bookmarks
        for bookmark in state.prefs.bookmarks where !bookmark.isFolder {
            let s = max(score(bookmark.title, query: q),
                        score(bookmark.url?.host ?? "", query: q),
                        score(bookmark.url?.absoluteString ?? "", query: q))
            let final = applyUsage(score: s, id: "bmk-\(bookmark.id)", usageCounts: usageCounts)
            guard final > 0 else { continue }
            all.append(.init(result: .bookmark(bookmark), score: final))
        }

        // History
        for entry in state.prefs.historyEntries {
            let s = max(score(entry.title, query: q),
                        score(entry.host, query: q),
                        score(entry.url.absoluteString, query: q))
            let final = applyUsage(score: s, id: "hist-\(entry.id)", usageCounts: usageCounts)
            guard final > 0 else { continue }
            all.append(.init(result: .history(entry), score: final))
        }

        // Spaces
        for space in state.spaces {
            let s = max(score(space.name, query: q),
                        score(spaceIconLabel(space.iconName), query: q))
            let final = applyUsage(score: s, id: "space-\(space.id)", usageCounts: usageCounts)
            guard final > 0 else { continue }
            all.append(.init(result: .space(space), score: final))
        }

        // Fallbacks
        all.append(contentsOf: fallbackResults(query: trimmed))

        return buildSections(from: all)
    }

    // MARK: - Scoring

    /// Score a single text string against the query.
    /// - Exact match: 2000
    /// - Prefix match: 1000 + length bonus
    /// - Substring match: 500, penalized by position and text length
    /// - Fuzzy match: up to 300, penalized by gaps and text length
    static func score(_ text: String, query: String) -> Double {
        let t = text.lowercased()
        let q = query.lowercased()
        guard !q.isEmpty else { return 0 }

        if t == q { return 2000 }
        if t.hasPrefix(q) { return 1000 + Double(q.count) * 10 }

        if t.contains(q) {
            let position = t.distance(from: t.startIndex,
                                      to: t.range(of: q)?.lowerBound ?? t.startIndex)
            return 500 - Double(position) * 2 - Double(t.count) * 0.5
        }

        // Fuzzy: every query character must appear in order.
        var lastIndex = t.startIndex
        var gaps = 0
        var matched = 0
        for char in q {
            if let range = t.range(of: String(char), range: lastIndex..<t.endIndex) {
                matched += 1
                if range.lowerBound > lastIndex { gaps += 1 }
                lastIndex = t.index(after: range.lowerBound)
            } else {
                return 0
            }
        }
        guard matched == q.count else { return 0 }
        return 300 - Double(gaps) * 10 - Double(t.count) * 0.5
    }

    // MARK: - Empty state

    @MainActor
    private static func emptyStateSections(
        state: ChromeState,
        usageCounts: [String: Int]
    ) -> [Section] {
        let spaces = state.spaces.map { ScoredResult(result: .space($0), score: 100) }
        var commands = registry.allCommands.map { cmd in
            let id = "cmd-\(cmd.id.rawValue)"
            return ScoredResult(result: .command(cmd),
                                score: applyUsage(score: 100, id: id, usageCounts: usageCounts))
        }
        commands.sort { $0.score > $1.score }
        return [
            Section(section: .spaces, results: spaces),
            Section(section: .commands, results: commands)
        ]
    }

    // MARK: - Fallbacks

    private static func fallbackResults(query: String) -> [ScoredResult] {
        var results: [ScoredResult] = []

        if let url = URL(string: query), url.scheme != nil, url.host != nil {
            results.append(.init(result: .fallback(.openURL(url),
                                                 title: "Open URL",
                                                 subtitle: query,
                                                 iconName: "safari"), score: 900))
        } else if !query.isEmpty {
            results.append(.init(result: .fallback(.searchWeb(query),
                                                     title: "Search the Web",
                                                     subtitle: query,
                                                     iconName: "magnifyingglass"), score: 100))
            results.append(.init(result: .fallback(.askSwarm(query),
                                                     title: "Ask Swarm",
                                                     subtitle: query,
                                                     iconName: "bubble.left"), score: 80))
            results.append(.init(result: .fallback(.searchHistory(query),
                                                     title: "Search History",
                                                     subtitle: query,
                                                     iconName: "clock.arrow.circlepath"), score: 60))
        }

        return results
    }

    // MARK: - Helpers

    private static func maxScore(for strings: [String], query: String) -> Double {
        strings.map { score($0, query: query) }.max() ?? 0
    }

    private static func applyUsage(score: Double, id: String, usageCounts: [String: Int]) -> Double {
        guard score > 0 else { return 0 }
        let usage = usageCounts[id] ?? 0
        return score + Double(min(usage, 20)) * 10
    }

    private static func buildSections(from results: [ScoredResult]) -> [Section] {
        let topHitThreshold: Double = 1000
        var topHits: [ScoredResult] = []
        var others: [ScoredResult] = []

        for r in results {
            if r.score >= topHitThreshold {
                topHits.append(r)
            } else {
                others.append(r)
            }
        }

        var sections: [Section] = []
        if !topHits.isEmpty {
            topHits.sort { $0.score > $1.score }
            sections.append(Section(section: .topHits, results: topHits))
        }

        let grouped = Dictionary(grouping: others) { $0.result.section }
        let sortedKeys = grouped.keys.sorted { $0.sortOrder < $1.sortOrder }
        for key in sortedKeys {
            let results = grouped[key]!.sorted { $0.score > $1.score }
            sections.append(Section(section: key, results: results))
        }
        return sections
    }
}
