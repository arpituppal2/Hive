import Foundation

/// Performs entity-mention auto-linking across Colony articles
/// (Prompt 3 Part 3 Step 1). Given an article body and the set of known
/// articles, it wraps the first whole-word mention of another article's title
/// or alias in a `[[slug]]` wiki link, while taking care not to touch text that
/// already sits inside an existing link.
public struct CrossReferenceLinker: Sendable {
    public init() {}

    /// A lightweight view of an article that may be referenced from a body: just
    /// the slug, its display title, and any aliases it answers to.
    public struct KnownArticle: Hashable, Sendable {
        public var slug: String
        public var title: String
        public var aliases: [String]

        public init(slug: String, title: String, aliases: [String] = []) {
            self.slug = slug
            self.title = title
            self.aliases = aliases
        }
    }

    /// For every article other than the current one, links the first whole-word
    /// mention of its title or one of its aliases. Articles whose longest term is
    /// longer are processed first so that, e.g., "Swift Concurrency" is linked
    /// before the bare "Swift" can clobber the phrase. At most one mention per
    /// article is linked, and matches already enclosed in `[[ ]]` are skipped.
    public func autoLink(body: String, knownArticles: [KnownArticle], currentSlug: String) -> String {
        var result = body
        let candidates = knownArticles
            .filter { $0.slug != currentSlug }
            .sorted { maxTermLength($0) > maxTermLength($1) }

        for article in candidates {
            let terms = ([article.title] + article.aliases)
                .filter { !$0.isEmpty }
                .sorted { $0.count > $1.count }
            guard !terms.isEmpty else { continue }
            let linkSpans = existingLinkSpans(in: result)
            if let range = earliestLinkableRange(in: result, terms: terms, linkSpans: linkSpans) {
                result.replaceSubrange(range, with: "[[\(article.slug)]]")
            }
        }
        return result
    }

    /// Returns the slugs referenced by `[[slug]]` tokens in `body` that do not
    /// correspond to any known article. A display alias (`[[slug|Label]]`) is
    /// reduced to its slug portion. Results preserve first-appearance order and
    /// are de-duplicated.
    public func detectBrokenLinks(body: String, existingSlugs: Set<String>) -> [String] {
        var broken: [String] = []
        var seen = Set<String>()
        for token in linkTokens(in: body) {
            let slug = token
                .split(separator: "|", maxSplits: 1)
                .first
                .map { String($0).trimmingCharacters(in: .whitespaces) } ?? token
            guard !slug.isEmpty, !existingSlugs.contains(slug) else { continue }
            if seen.insert(slug).inserted {
                broken.append(slug)
            }
        }
        return broken
    }

    /// Standard Levenshtein edit distance between two strings, used by the lint
    /// auto-repair pass to match broken links against existing slugs within an
    /// edit distance of 2.
    public static func levenshtein(_ a: String, _ b: String) -> Int {
        let lhs = Array(a)
        let rhs = Array(b)
        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }

        var previous = Array(0...rhs.count)
        var current = [Int](repeating: 0, count: rhs.count + 1)

        for i in 1...lhs.count {
            current[0] = i
            for j in 1...rhs.count {
                let cost = lhs[i - 1] == rhs[j - 1] ? 0 : 1
                current[j] = Swift.min(
                    previous[j] + 1,      // deletion
                    current[j - 1] + 1,   // insertion
                    previous[j - 1] + cost // substitution
                )
            }
            swap(&previous, &current)
        }
        return previous[rhs.count]
    }

    // MARK: - Private helpers

    private func maxTermLength(_ article: KnownArticle) -> Int {
        ([article.title] + article.aliases).map(\.count).max() ?? 0
    }

    /// Finds the earliest linkable occurrence across all of an article's terms.
    /// When two terms match at the same position, the longer one wins.
    private func earliestLinkableRange(
        in text: String,
        terms: [String],
        linkSpans: [Range<String.Index>]
    ) -> Range<String.Index>? {
        var best: Range<String.Index>?
        for term in terms {
            guard let range = firstLinkableRange(of: term, in: text, linkSpans: linkSpans) else { continue }
            if let current = best {
                if range.lowerBound < current.lowerBound {
                    best = range
                } else if range.lowerBound == current.lowerBound,
                          text.distance(from: range.lowerBound, to: range.upperBound)
                            > text.distance(from: current.lowerBound, to: current.upperBound) {
                    best = range
                }
            } else {
                best = range
            }
        }
        return best
    }

    private func firstLinkableRange(
        of term: String,
        in text: String,
        linkSpans: [Range<String.Index>]
    ) -> Range<String.Index>? {
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let found = text.range(of: term, options: .caseInsensitive, range: searchStart..<text.endIndex) {
            if isWholeWord(found, in: text), !overlaps(found, linkSpans) {
                return found
            }
            searchStart = found.lowerBound < text.endIndex
                ? text.index(after: found.lowerBound)
                : text.endIndex
        }
        return nil
    }

    private func isWholeWord(_ range: Range<String.Index>, in text: String) -> Bool {
        if range.lowerBound > text.startIndex {
            let before = text[text.index(before: range.lowerBound)]
            if before.isLetter || before.isNumber || before == "_" {
                return false
            }
        }
        if range.upperBound < text.endIndex {
            let after = text[range.upperBound]
            if after.isLetter || after.isNumber || after == "_" {
                return false
            }
        }
        return true
    }

    private func overlaps(_ range: Range<String.Index>, _ spans: [Range<String.Index>]) -> Bool {
        spans.contains { $0.overlaps(range) || $0.contains(range.lowerBound) }
    }

    /// Computes the character ranges covered by existing `[[...]]` links so they
    /// can be treated as off-limits for new linking.
    private func existingLinkSpans(in text: String) -> [Range<String.Index>] {
        ranges(matching: #"\[\[[^\]]*\]\]"#, in: text)
    }

    /// Extracts the inner slug text of every `[[...]]` token, in order.
    private func linkTokens(in text: String) -> [String] {
        let spans = ranges(matching: #"\[\[[^\]]*\]\]"#, in: text)
        return spans.map { span in
            let inner = text[span].dropFirst(2).dropLast(2)
            return inner.trimmingCharacters(in: .whitespaces)
        }
    }

    private func ranges(matching pattern: String, in text: String) -> [Range<String.Index>] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        return matches.compactMap { Range($0.range, in: text) }
    }
}
