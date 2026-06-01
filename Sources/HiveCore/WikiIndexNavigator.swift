import Foundation

public struct WikiIndexHit: Hashable, Sendable {
    public var page: WikiPageRecord
    public var score: Int

    public init(page: WikiPageRecord, score: Int) {
        self.page = page
        self.score = score
    }
}

public struct WikiIndexNavigator: Sendable {
    public init() {}

    public func relevantPages(query: String, pages: [WikiPageRecord], limit: Int = 8) -> [WikiIndexHit] {
        let queryTokens = tokens(query)
        guard !queryTokens.isEmpty else { return [] }
        return pages
            .filter(\.isUserVisibleArticle)
            .map { page -> WikiIndexHit in
                let catalogText = [
                    page.title,
                    page.summary,
                    page.kind.rawValue,
                    page.frontmatter["tags"] ?? "",
                    page.frontmatter["status"] ?? "",
                    page.frontmatter["query"] ?? ""
                ].joined(separator: " ")
                let catalogTokens = tokens(catalogText)
                let bodyTokens = tokens(page.markdown)
                let catalogOverlap = catalogTokens.intersection(queryTokens).count
                let bodyOverlap = bodyTokens.intersection(queryTokens).count
                let score = catalogOverlap * 8 + min(bodyOverlap, 2)
                return WikiIndexHit(page: page, score: score)
            }
            .filter { $0.score > 0 }
            .sorted {
                if $0.score == $1.score {
                    return $0.page.updatedAt > $1.page.updatedAt
                }
                return $0.score > $1.score
            }
            .prefix(limit)
            .map { $0 }
    }

    private func tokens(_ text: String) -> Set<String> {
        let stopwords: Set<String> = [
            "about", "answer", "article", "because", "concept", "from", "have", "index",
            "into", "page", "that", "the", "this", "wiki", "with"
        ]
        return Set(text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopwords.contains($0) })
    }
}
