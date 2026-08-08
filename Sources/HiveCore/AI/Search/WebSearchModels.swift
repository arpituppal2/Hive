import Foundation

// MARK: - Web search source

/// A single source returned by a web search provider.
///
/// Modeled after the search result shape used by Vane/Perplexica and the
/// Perplexity API. Hive stores these as `Source` nodes in Honeycomb so every
/// citation has durable provenance.
public struct WebSearchSource: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let url: String
    public let date: String?
    public let lastUpdated: String?
    public let snippet: String?

    public static func == (lhs: WebSearchSource, rhs: WebSearchSource) -> Bool {
        lhs.id == rhs.id
    }

    public init(id: String = UUID().uuidString,
                  title: String,
                  url: String,
                  date: String? = nil,
                  lastUpdated: String? = nil,
                  snippet: String? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.date = date
        self.lastUpdated = lastUpdated
        self.snippet = snippet
    }

    /// Returns one canonical HTTP(S) URL for deduplication and durable source
    /// identity. Scheme and host are case-insensitive; paths and queries are
    /// preserved because servers may treat their case as significant.
    public static func canonicalHTTPURLString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        components.scheme = scheme
        components.host = components.host?.lowercased()
        return components.string
    }
}

// MARK: - Web search result

/// The output of a web research query: an synthesized answer plus the sources that
/// ground it. This is the intermediate form before Honeycomb/Source/Brief persistence.
public struct WebSearchResult: Sendable, Equatable {
    public var answer: String
    public var sources: [WebSearchSource]
    public var relatedQuestions: [String]

    public init(answer: String = "",
                sources: [WebSearchSource] = [],
                relatedQuestions: [String] = []) {
        self.answer = answer
        self.sources = sources
        self.relatedQuestions = relatedQuestions
    }
}

// MARK: - Focus modes

/// Search focus modes supported by Vane/Perplexica. The raw values are chosen to
/// match the wire format used by Vane's `/api/search` endpoint.
public enum WebSearchFocusMode: String, Sendable, Codable, CaseIterable {
    case webSearch = "webSearch"
    case academicSearch = "academicSearch"
    case writingAssistant = "writingAssistant"
    case wolframAlpha = "wolframAlpha"
    case youtubeSearch = "youtubeSearch"
    case redditSearch = "redditSearch"

    public var displayName: String {
        switch self {
        case .webSearch:        return "Web"
        case .academicSearch:   return "Academic"
        case .writingAssistant: return "Writing"
        case .wolframAlpha:     return "Wolfram"
        case .youtubeSearch:    return "YouTube"
        case .redditSearch:     return "Reddit"
        }
    }
}
