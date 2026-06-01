import Foundation

public enum OnlineAskContextSharingMode: String, Hashable, Sendable {
    case localContextAllowed
    case questionOnly
}

public struct CloudChatAnswerEngine: Sendable {
    public init() {}

    public func answer(
        query: String,
        localAnswer: CitedAnswer,
        sources: [SourceRecord] = [],
        chunks: [ChunkRecord] = [],
        claims: [ClaimRecord],
        wikiPages: [WikiPageRecord],
        visibility: DerivedMemoryVisibility = .allowAll,
        settings: CloudInferenceSettings = CloudInferenceSettingsStore.load(),
        apiKey: String? = CloudInferenceKeyStore.load(),
        session: URLSession = .shared,
        sharingMode: OnlineAskContextSharingMode = .localContextAllowed,
        allowWebSearch: Bool = true
    ) async -> CitedAnswer {
        guard settings.isConfigured,
              let apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !apiKey.isEmpty,
              let endpoint = URL(string: settings.endpointURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return localAnswer
        }

        do {
            let prompt = promptForOnlineAsk(
                query: query,
                localAnswer: localAnswer,
                sources: sources,
                chunks: chunks,
                claims: claims,
                wikiPages: wikiPages,
                visibility: visibility,
                sharingMode: sharingMode
            )
            let responseText = try await requestAnswer(
                endpoint: endpoint,
                apiKey: apiKey,
                modelName: settings.modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "gpt-4.1-mini" : settings.modelName,
                prompt: prompt,
                session: session,
                allowWebSearch: allowWebSearch
            )
            let cleaned = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleaned.count > 12 else { return localAnswer }
            return CitedAnswer(
                answer: cleaned,
                citations: sharingMode == .localContextAllowed ? localAnswer.citations : [],
                uncertainty: sharingMode == .localContextAllowed ? settings.normalizedProviderName : "\(settings.normalizedProviderName) without Colony context",
                suggestedActions: stableUnique(["File answer to The Colony"] + localAnswer.suggestedActions)
            )
        } catch {
            var fallback = localAnswer
            fallback.uncertainty = "Online helper unavailable; answered from local memory."
            return fallback
        }
    }

    private func requestAnswer(
        endpoint: URL,
        apiKey: String,
        modelName: String,
        prompt: String,
        session: URLSession,
        allowWebSearch: Bool
    ) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 24

        if endpoint.path.localizedCaseInsensitiveContains("/responses") {
            var body: [String: Any] = [
                "model": modelName,
                "input": prompt,
                "temperature": 0.2
            ]
            if allowWebSearch {
                body["tools"] = [["type": "web_search"]]
                body["tool_choice"] = "auto"
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } else {
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "model": modelName,
                "messages": [
                    ["role": "system", "content": "Answer as Hive. Prefer supplied Hive context for personal facts; use general outside knowledge when the local context is insufficient. Be concise and separate local memory from outside information."],
                    ["role": "user", "content": prompt]
                ],
                "temperature": 0.2
            ])
        }

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if endpoint.path.localizedCaseInsensitiveContains("/responses"), allowWebSearch {
                var retryRequest = request
                retryRequest.httpBody = try JSONSerialization.data(withJSONObject: [
                    "model": modelName,
                    "input": prompt,
                    "temperature": 0.2,
                    "tools": [["type": "web_search_preview"]],
                    "tool_choice": "auto"
                ])
                let (retryData, retryResponse) = try await session.data(for: retryRequest)
                if let retryHTTP = retryResponse as? HTTPURLResponse, (200..<300).contains(retryHTTP.statusCode) {
                    return try parseResponse(retryData)
                }
            }
            throw URLError(.badServerResponse)
        }
        return try parseResponse(data)
    }

    private func parseResponse(_ data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else { return "" }
        if let outputText = dictionary["output_text"] as? String {
            return outputText
        }
        if let choices = dictionary["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        if let output = dictionary["output"] as? [[String: Any]] {
            for item in output {
                if let content = item["content"] as? [[String: Any]] {
                    for block in content {
                        if let text = block["text"] as? String {
                            return text
                        }
                    }
                }
            }
        }
        return ""
    }

    private func promptForOnlineAsk(
        query: String,
        localAnswer: CitedAnswer,
        sources: [SourceRecord],
        chunks: [ChunkRecord],
        claims: [ClaimRecord],
        wikiPages: [WikiPageRecord],
        visibility: DerivedMemoryVisibility,
        sharingMode: OnlineAskContextSharingMode
    ) -> String {
        let terms = queryTerms(query)
        let canShareLocalContext = sharingMode == .localContextAllowed
        let visibleClaims = claims
            .filter { $0.status != .retracted && visibility.shouldAnswerFromClaim($0) }
            .map { claim in
                (claim: claim, score: matchScore(claim.statement, terms: terms))
            }
            .sorted { left, right in
                if left.score != right.score { return left.score > right.score }
                if left.claim.relevanceTier == right.claim.relevanceTier { return left.claim.confidence > right.claim.confidence }
                return (left.claim.relevanceTier?.rank ?? 0) > (right.claim.relevanceTier?.rank ?? 0)
            }
            .prefix(10)
            .map { "- \($0.claim.statement)" }
            .joined(separator: "\n")

        let rankedSources = sources
            .filter { source in
                source.deletionState == .active
                    && source.kind != .browserHistory
                    && source.kind != .browserBookmark
            }
            .map { source in
                (source: source, score: matchScore("\(source.title) \(source.kind.rawValue) \(source.connector)", terms: terms))
            }
            .filter { $0.score > 0 }
            .sorted { left, right in
                if left.score != right.score { return left.score > right.score }
                return left.source.importedAt > right.source.importedAt
            }
            .prefix(6)
            .map { "- \(SourcePresentationModel.cleanTitle($0.source.title)) (\($0.source.kind.rawValue))" }
            .joined(separator: "\n")

        let sourceTitlesByID = Dictionary(uniqueKeysWithValues: sources.map {
            ($0.id, SourcePresentationModel.cleanTitle($0.title))
        })
        let citedSourceIDs = Set(localAnswer.citations.map(\.id))
        let rankedChunks = chunks
            .filter { chunk in
                sourceTitlesByID[chunk.sourceID] != nil
                    && (citedSourceIDs.contains(chunk.sourceID) || matchScore(chunk.text, terms: terms) > 0)
            }
            .map { chunk in
                (
                    chunk: chunk,
                    score: matchScore("\(sourceTitlesByID[chunk.sourceID] ?? "") \(chunk.text)", terms: terms)
                        + (citedSourceIDs.contains(chunk.sourceID) ? 3 : 0)
                )
            }
            .sorted { left, right in
                if left.score != right.score { return left.score > right.score }
                return left.chunk.extractionConfidence > right.chunk.extractionConfidence
            }
            .prefix(8)
            .map { item in
                let title = sourceTitlesByID[item.chunk.sourceID] ?? "Field source"
                let label = item.chunk.locationLabel.isEmpty ? "excerpt" : item.chunk.locationLabel
                return "- \(title), \(label): \(abbreviated(item.chunk.text, maxCharacters: 900))"
            }
            .joined(separator: "\n")

        let rankedPages = wikiPages
            .filter(\.isUserVisibleArticle)
            .map { page in
                (page: page, score: matchScore("\(page.title) \(page.summary) \(page.markdown)", terms: terms))
            }
            .sorted { left, right in
                if left.score != right.score { return left.score > right.score }
                return left.page.updatedAt > right.page.updatedAt
            }
        let matchedPages = rankedPages.filter { $0.score > 0 }
        let selectedPages = matchedPages.isEmpty ? Array(rankedPages.prefix(3)) : Array(matchedPages.prefix(6))
        let pages = selectedPages
            .map { "- \($0.page.title): \($0.page.summary)" }
            .joined(separator: "\n")

        return """
        Question:
        \(query)

        Local answer draft:
        \(canShareLocalContext ? localAnswer.answer : "Not shared for this request.")

        Field source hints:
        \(canShareLocalContext ? (rankedSources.isEmpty ? "- No related source metadata matched." : rankedSources) : "- Not shared for this request.")

        Field excerpts:
        \(canShareLocalContext ? (rankedChunks.isEmpty ? "- No extracted source excerpts matched." : rankedChunks) : "- Not shared for this request.")

        Maintained claims:
        \(canShareLocalContext ? (visibleClaims.isEmpty ? "- No strong claims matched." : visibleClaims) : "- Not shared for this request.")

        Colony articles:
        \(canShareLocalContext ? (pages.isEmpty ? "- No visible articles matched." : pages) : "- Not shared for this request.")

        Rules:
        - Use Hive context for personal facts when it is supplied.
        - Use outside knowledge and web search when Hive context is missing, stale, or too thin.
        - Clearly distinguish local Hive memory from outside information.
        - Do not invent personal facts or claim that Hive saw a private file unless it appears in the supplied Hive context.
        - If current outside information matters, use web search and include concise source names.
        - Do not mention model names, raw filenames, percentages, or backend implementation details.
        - Keep the answer short and useful.
        """
    }

    private func queryTerms(_ query: String) -> [String] {
        let separators = CharacterSet.alphanumerics.inverted
        return query
            .lowercased()
            .components(separatedBy: separators)
            .filter { term in
                term.count > 2 && !["the", "and", "for", "with", "what", "why", "how", "this", "that", "about"].contains(term)
            }
    }

    private func matchScore(_ text: String, terms: [String]) -> Int {
        guard !terms.isEmpty else { return 0 }
        let lower = text.lowercased()
        return terms.reduce(into: 0) { score, term in
            if lower.contains(term) {
                score += 1
            }
        }
    }

    private func abbreviated(_ text: String, maxCharacters: Int) -> String {
        let compact = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
        guard compact.count > maxCharacters else { return compact }
        return String(compact.prefix(maxCharacters)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func stableUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}

private extension MemoryImportanceTier {
    var rank: Int {
        switch self {
        case .canonical:
            return 7
        case .active:
            return 6
        case .supporting:
            return 5
        case .review:
            return 4
        case .incidental:
            return 3
        case .stale:
            return 2
        case .retracted:
            return 1
        }
    }
}
