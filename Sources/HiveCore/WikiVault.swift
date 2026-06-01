import Foundation

public struct WikiExternalEditRecord: Identifiable, Hashable, Sendable {
    public var id: String
    public var pageID: String
    public var filePath: String
    public var detectedAt: Date

    public init(pageID: String, filePath: String, detectedAt: Date = Date()) {
        self.id = "\(pageID)|\(Int(detectedAt.timeIntervalSince1970))"
        self.pageID = pageID
        self.filePath = filePath
        self.detectedAt = detectedAt
    }
}

public struct WikiVaultManager: @unchecked Sendable {
    public var paths: HivePaths
    public var fileManager: FileManager

    public init(paths: HivePaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    public func ensureVault() throws {
        try fileManager.createDirectory(at: paths.vault, withIntermediateDirectories: true)
        try migrateLegacyVaultLayoutIfNeeded()
        try fileManager.createDirectory(at: paths.vaultRawSources, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: paths.vaultRawAssets, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: paths.vaultWiki, withIntermediateDirectories: true)
        for directory in managedWikiDirectories {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        _ = WikiVaultGitManager(vaultURL: paths.vault, fileManager: fileManager).ensureRepository()
        if shouldWriteAgentsSchema() {
            try Self.agentsSchema.write(to: paths.agentsFile, atomically: true, encoding: .utf8)
        }
        for special in [
            paths.vaultWiki.appendingPathComponent("index.md"),
            paths.vaultWiki.appendingPathComponent("log.md")
        ] where !fileManager.fileExists(atPath: special.path) {
            try "# \(special.deletingPathExtension().lastPathComponent.capitalized)\n\nHive will maintain this file.\n"
                .write(to: special, atomically: true, encoding: .utf8)
        }
    }

    @discardableResult
    public func mirrorRawSource(_ source: SourceRecord, rawURL: URL) throws -> URL {
        try ensureVault()
        let target = rawMirrorURL(for: source)
        if !fileManager.fileExists(atPath: target.path) {
            try fileManager.copyItem(at: rawURL, to: target)
        }
        return target
    }

    public func removeRawMirror(for source: SourceRecord) throws {
        let prefix = String(source.sha256.prefix(12))
        guard fileManager.fileExists(atPath: paths.vaultRawSources.path),
              let entries = try? fileManager.contentsOfDirectory(at: paths.vaultRawSources, includingPropertiesForKeys: nil) else {
            return
        }
        for entry in entries where entry.lastPathComponent.hasPrefix("\(prefix)-") {
            try fileManager.removeItem(at: entry)
        }
    }

    public func detectExternalEdits(pages: [WikiPageRecord]) throws -> [WikiExternalEditRecord] {
        try ensureVault()
        var edits: [WikiExternalEditRecord] = []
        for page in pages {
            let url = fileURL(for: page)
            guard fileManager.fileExists(atPath: url.path) else { continue }
            let disk = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            if normalized(disk) != normalized(page.markdown) {
                edits.append(WikiExternalEditRecord(pageID: page.id, filePath: url.path))
            }
        }
        return edits
    }

    public func pagesWithFilePaths(_ pages: [WikiPageRecord]) -> [WikiPageRecord] {
        pages.map { page in
            var updated = page
            updated.filePath = fileURL(for: page).path
            return updated
        }
    }

    public func writeVault(pages: [WikiPageRecord]) throws {
        try ensureVault()
        let withPaths = pagesWithFilePaths(pages)
        let managedPaths = Set(withPaths.map { fileURL(for: $0).standardizedFileURL.path })
        for page in withPaths {
            let url = fileURL(for: page)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try page.markdown.write(to: url, atomically: true, encoding: .utf8)
        }
        try removeStaleWikiFiles(keeping: managedPaths)
        _ = WikiVaultGitManager(vaultURL: paths.vault, fileManager: fileManager).commitIfNeeded()
    }

    public func removePageFile(_ page: WikiPageRecord) throws {
        let url = fileURL(for: page)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    public func rawMirrorURL(for source: SourceRecord) -> URL {
        let prefix = String(source.sha256.prefix(12))
        let extensionFromTitle = URL(fileURLWithPath: source.title).pathExtension
        let ext = extensionFromTitle.isEmpty ? extensionForMimeType(source.mimeType) : extensionFromTitle
        let baseName = URL(fileURLWithPath: source.title).deletingPathExtension().lastPathComponent
        return paths.vaultRawSources.appendingPathComponent("\(prefix)-\(Self.safeFileName(baseName)).\(ext)")
    }

    public func fileURL(for page: WikiPageRecord) -> URL {
        switch page.kind {
        case .index:
            return paths.vaultWiki.appendingPathComponent("index.md")
        case .log:
            return paths.vaultWiki.appendingPathComponent("log.md")
        case .overview:
            return paths.vaultWiki.appendingPathComponent("overview.md")
        case .lintReport:
            return paths.vaultWiki.appendingPathComponent("lint-report.md")
        case .source:
            return paths.vaultWiki.appendingPathComponent("sources", isDirectory: true).appendingPathComponent("\(page.slug).md")
        case .topic, .person:
            return paths.vaultWiki.appendingPathComponent("topics", isDirectory: true).appendingPathComponent("\(page.slug).md")
        case .project:
            return paths.vaultWiki.appendingPathComponent("projects", isDirectory: true).appendingPathComponent("\(page.slug).md")
        case .action:
            return paths.vaultWiki.appendingPathComponent("actions", isDirectory: true).appendingPathComponent("\(page.slug).md")
        case .question:
            return paths.vaultWiki.appendingPathComponent("questions", isDirectory: true).appendingPathComponent("\(page.slug).md")
        case .contradiction:
            return paths.vaultWiki.appendingPathComponent("contradictions", isDirectory: true).appendingPathComponent("\(page.slug).md")
        case .synthesis:
            return paths.vaultWiki.appendingPathComponent("synthesis", isDirectory: true).appendingPathComponent("\(page.slug).md")
        case .answer:
            return paths.vaultWiki.appendingPathComponent("answers", isDirectory: true).appendingPathComponent("\(page.slug).md")
        }
    }

    private var managedWikiDirectories: [URL] {
        [
            "topics",
            "projects",
            "actions",
            "questions",
            "contradictions",
            "synthesis",
            "answers"
        ].map { paths.vaultWiki.appendingPathComponent($0, isDirectory: true) }
    }

    private func removeStaleWikiFiles(keeping managedPaths: Set<String>) throws {
        guard let enumerator = fileManager.enumerator(
            at: paths.vaultWiki,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true, url.pathExtension == "md" else { continue }
            if !managedPaths.contains(url.standardizedFileURL.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    private func normalized(_ value: String) -> String {
        value.replacingOccurrences(of: "\r\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shouldWriteAgentsSchema() -> Bool {
        guard fileManager.fileExists(atPath: paths.agentsFile.path),
              let existing = try? String(contentsOf: paths.agentsFile, encoding: .utf8) else {
            return true
        }
        return !existing.contains("This is not a RAG cache")
            || !existing.contains("Hive is an LLM Wiki")
            || !existing.contains("## Local AI Contract")
            || !existing.contains("hive-query")
            || !existing.contains("flower-field/assets")
            || !existing.contains("Colony/index.md")
            || !existing.contains("## Operations")
            || existing.contains("canonical local " + "truth")
    }

    private func migrateLegacyVaultLayoutIfNeeded() throws {
        let legacyRawSources = paths.vault.appendingPathComponent("raw-sources", isDirectory: true)
        let legacyRawAssets = paths.vault.appendingPathComponent("raw/assets", isDirectory: true)
        let legacyWiki = paths.vault.appendingPathComponent("wiki", isDirectory: true)

        try migrateDirectory(from: legacyRawSources, to: paths.vaultRawSources)
        try migrateDirectory(from: legacyRawAssets, to: paths.vaultRawAssets)
        try migrateDirectory(from: legacyWiki, to: paths.vaultWiki)
        removeIfEmpty(paths.vault.appendingPathComponent("raw", isDirectory: true))
    }

    private func migrateDirectory(from legacyURL: URL, to targetURL: URL) throws {
        var isLegacyDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: legacyURL.path, isDirectory: &isLegacyDirectory),
              isLegacyDirectory.boolValue else { return }

        if !fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: legacyURL, to: targetURL)
            return
        }

        try mergeDirectoryContents(from: legacyURL, to: targetURL)
    }

    private func mergeDirectoryContents(from legacyURL: URL, to targetURL: URL) throws {
        try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
        let entries = try fileManager.contentsOfDirectory(at: legacyURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        for entry in entries {
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey])
            let destination = targetURL.appendingPathComponent(entry.lastPathComponent, isDirectory: values?.isDirectory == true)
            if !fileManager.fileExists(atPath: destination.path) {
                try fileManager.moveItem(at: entry, to: destination)
            } else if values?.isDirectory == true {
                try mergeDirectoryContents(from: entry, to: destination)
            }
        }
        if (try? fileManager.contentsOfDirectory(atPath: legacyURL.path).isEmpty) == true {
            try? fileManager.removeItem(at: legacyURL)
        }
    }

    private func removeIfEmpty(_ directory: URL) {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              (try? fileManager.contentsOfDirectory(atPath: directory.path).isEmpty) == true else {
            return
        }
        try? fileManager.removeItem(at: directory)
    }

    private func extensionForMimeType(_ mimeType: String) -> String {
        switch mimeType {
        case "text/markdown":
            return "md"
        case "text/plain":
            return "txt"
        case "application/pdf":
            return "pdf"
        case "image/png":
            return "png"
        case "image/jpeg":
            return "jpg"
        default:
            return "raw"
        }
    }

    public static func safeFileName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let cleaned = String(value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Untitled" : String(cleaned.prefix(96))
    }

    public static let agentsSchema = """
    # Hive Agents Schema

    Hive is an LLM Wiki for local memory. This is not a RAG cache: do not rediscover raw chunks from scratch when a durable Colony article can be updated once and reused. The job is to incrementally compile the user's real sources into a persistent, interlinked, current wiki and then use The Hive graph to show the shape of that compiled knowledge.

    The user owns sourcing, exploration, and questions. Hive owns reading, summarizing, cross-referencing, filing, consolidation, contradiction tracking, staleness review, and Colony maintenance. Behave like a disciplined local wiki maintainer, not a generic chatbot.

    ## Four Layers

    1. Field (`flower-field/`) is the immutable source-of-truth junk drawer. Articles, notes, screenshots, transcripts, bookmarks, research, book notes, podcast takeaways, uploads, and loose thoughts go here without cleanup. Read from it, mirror into it, retain it, delete it, or forget it only through explicit lifecycle controls. Never reorganize, rewrite, or summarize source files in place.
    2. The Colony (`Colony/`) is the persistent compiled wiki. Maintain AI-authored markdown articles, entity pages, concept pages, comparisons, overviews, syntheses, contradictions, and open questions. Users read and correct Colony through Hive; do not expect them to hand-edit the folder.
    3. The schema (`AGENTS.md`) is this maintainer contract. It tells the local AI how the wiki is structured, which conventions to follow, and which workflows to run for ingest, query, consolidation, maintenance, attachment capture, and graph refresh.
    4. The Hive is the visual graph of Colony. It should show meaningful honeycombs from compiled memory, not raw sources, browser traces, low-information entities, or debug artifacts. Coordinates represent the selected semantic axes, by default analytical to creative and professional to personal.

    `Vault/` is also a local git repository for markdown, schema, and local asset history when git is available. SQLite remains canonical, but the vault is the readable, inspectable wiki mirror.

    ## Folders

    - `flower-field/`: immutable raw-source mirror. Hive may add files here from uploads, captures, notes, links, and connected sources. Hive may remove files here only through retention expiry, raw delete, or full forget.
    - `flower-field/assets/`: fixed local attachment directory. Download article images and page screenshots here so models and users can inspect images after reading the markdown text.
    - `Colony/index.md`: content-oriented catalog of every maintained article, grouped by category with links, one-line summaries, and compact metadata.
    - `Colony/log.md`: chronological append-only record of ingests, questions, corrections, consolidations, and maintenance.
    - `Colony/topics/`, `Colony/projects/`, `Colony/actions/`, `Colony/questions/`, `Colony/contradictions/`, `Colony/synthesis/`, `Colony/answers/`: compiled article and control pages.
    - No visible `Colony/sources/` pages. Raw source names, domains, URLs, and filenames stay in evidence trails and inspectors, not normal Colony articles.

    ## Local AI Contract

    - Work locally and deterministically first. Use rule-based relevance, temporal classification, local indexes, and existing Colony pages before any model-backed synthesis.
    - Model output is proposal-only. Apply generated edits only after schema validation, conflict checks, authority checks, and undoable patch creation.
    - Foundation Models, Core ML helpers, MLX synthesis, qmd, and cloud keys are optional upgrades. The app must still work from local deterministic memory when none are available.
    - Never auto-install models, qmd, or external tools. Never send personal sources to cloud compute unless the user explicitly enables a cloud key and the UI discloses it.
    - Keep implementation vocabulary out of normal user-facing prose. Do not surface model names, schema filenames, raw filenames, domains, queue terms, confidence percentages, or internal IDs unless the user opens Advanced or explicitly asks for evidence.
    - Ask for review only when ambiguity affects meaning, privacy, contradiction handling, deletion, or a hard-to-undo merge. Otherwise make the smallest valid maintenance proposal and keep moving.
    - Do not add random commentary, filler, personality guesses, or generic life-coach prose. Every article sentence should preserve a useful claim, distinction, open question, contradiction, or connection.

    ## Promotion And Relevance

    - Prefer editing and improving an existing article over creating a new page.
    - Consolidate duplicate articles before adding more pages.
    - Promote memories only when they say something durable and user-centered: identity, preference, constraint, project, goal, workflow, deadline, class, relationship, health context, hardware plan, or recurring source pattern.
    - Suppress bare nouns, auth pages, login pages, navigation titles, source-only fragments, generic tool names, domain names, raw filenames, one-off shopping/search/browser traces, and claims with no clear predicate about the user.
    - Low-value material stays in Field evidence, review, or hidden refs. It does not become a normal Colony page, graph honeycomb, or chat answer unless the user explicitly asks for raw evidence.
    - Treat dates as meaning: current identity, historical fact, deadline, recurring context, course/event timing, stale trail, or one-off research. Stale one-off searches should not remain active memories.
    - Keep every durable claim linked to hidden source IDs, claim IDs, or explicit uncertainty.
    - Update the index, log, graph links, and contradictions whenever compiled knowledge changes.
    - Prefer concise, cross-linked article prose over raw chunks, source dumps, or search-result lists.
    - Markdown image URLs should be downloaded into `flower-field/assets/` and rewritten to local paths when the user runs attachment capture.
    - `hive-query` and Dataview-style fenced blocks may generate tables/lists from article frontmatter, tags, kind, source counts, claim counts, and update dates.
    - Query blocks operate on Colony metadata, never raw chunks or source filenames.
    - Use `qmd` for larger vault search when it is installed: add `Colony/` as the `hive-wiki` collection, add `qmd://hive-wiki` context, run `qmd update`, search with `qmd search`, `qmd vsearch`, or `qmd query --json`, retrieve selected documents with `qmd get` or `qmd multi-get`, and use `qmd mcp` for agent-tool integration. If `qmd` is unavailable, read `Colony/index.md` first and use Hive's deterministic index fallback. Never install qmd or trigger qmd model downloads without the user's explicit choice.
    - Every ingest/query/lint pass should run bookkeeping: update summaries, add missing cross-references, append `Colony/log.md`, refresh `Colony/index.md`, and surface contradictions or research gaps.
    - Flag contradictions and stale or weak claims instead of hiding them.
    - User corrections made through Hive are authoritative guidance. If they contradict lower-authority memory, update or retract the lower-authority memory; ask only when the conflict cannot be resolved deterministically.
    - This product replaces the Obsidian plus terminal-agent workflow with a single local Hive app: Obsidian-grade ownership, an AI-maintained Colony, and a graph view on steroids.

    ## Colony Article Conventions

    - Each visible article should have a clear title, a short summary, factual sections, related concepts, open questions when needed, and hidden source/claim references.
    - Articles are not per-source summaries by default. A single source can touch many pages, and many sources should strengthen one existing article.
    - Expand the best existing article before creating a new one. Create a new article only when the concept is durable, user-centered, and not better represented as a section of an existing page.
    - Keep starter pages friendly but temporary. As real memory forms, replace "not learned enough yet" copy with actual compiled knowledge.
    - Similar facts update existing pages first. Stale or supporting details become hidden refs or short context only when they clarify the article.
    - Contradictions should be explicit and reviewable. Do not silently overwrite high-authority user corrections.
    - Good answers can be filed back into `Colony/answers/` when they create useful synthesis, comparisons, plans, tables, or decisions that should compound.

    ## Operations

    ### Ingest

    1. Preserve the original item in Field and provenance. Do not clean up the source file.
    2. Read `Colony/index.md` and recent `Colony/log.md` entries before deciding where new information belongs.
    3. Extract candidate claims, entities, dates, relationships, questions, and images. Classify relevance and temporal state before promotion.
    4. Suppress low-information fragments and raw browser/source traces. Promote only user-centered durable knowledge.
    5. Find existing Colony targets first. Update entity, project, topic, contradiction, question, synthesis, and answer pages touched by the source.
    6. Write concise article prose with hidden refs. Do not paste raw source titles, URLs, model labels, or file names into visible article bodies.
    7. Refresh summaries, frontmatter, backlinks, `Colony/index.md`, `Colony/log.md`, graph relationships, graph coordinates, and review items.
    8. If confidence is low, the source is sensitive, or the meaning is ambiguous, surface the proposed takeaway for review instead of promoting silently.
    9. In supervised mode, process one source at a time. Batch ingestion is allowed only when the user chooses speed over review.

    ### Query

    - Answer from the compiled Colony first, then hidden evidence refs if needed. Do not rediscover raw chunks when a maintained article already contains the synthesis.
    - Read `Colony/index.md` first. Search Colony metadata, summaries, tags, backlinks, and recency before reading full page bodies. At larger scale, use the Colony tool layer (`qmd` when available, deterministic index fallback otherwise), then inspect the top matching pages.
    - Answers may become durable Colony articles when they create a comparison, analysis, table, chart plan, Marp slide deck, slide outline, or useful connection.
    - Filed answers must be `answer` pages with hidden source refs, related wiki links, and a clear question/answer structure. Do not paste raw source titles or URLs into visible prose.
    - If the answer depends on weak, stale, incidental, or raw-source-only evidence, say what is missing and offer the next action: add a source, inspect evidence, correct Colony, mark incidental, or run maintenance.

    ### Daily Lint And Maintenance

    - Run a local health check daily by default, plus after ingests and user corrections.
    - Look for contradictions, stale claims, orphan pages, missing cross-references, missing concept pages, weak claims, unanswered questions, duplicate articles, and data gaps.
    - Prefer concrete repair suggestions: merge pages, add links, ask the user, import a targeted source, retract stale claims, or promote a missing article.
    - Expand or merge existing pages before creating new ones. Destructive or hard-to-undo changes, including duplicate page deletion, require review.
    - Lint output is maintenance guidance. It should improve Colony without becoming normal user-facing article prose.

    ### Hive Graph

    - The graph should contain only relevant compiled memory: canonical, active, and useful supporting items.
    - Do not build honeycombs for review, incidental, stale, source-only, or bare-entity records.
    - Place nodes on the active semantic axes. Default: x = analytical to creative, y = professional to personal. Recompute coordinates during daily maintenance and after meaningful memory changes.
    - Use relationship strength to decide visible lines. Weak relationships below the visible threshold should not create visual clutter.
    - Hover and inspectors should show the main name and the two or three strongest related Colony entries or overarching topics, not generic "connected to X memories" prose.

    ## Indexing And Logging

    - `Colony/index.md` is content-oriented. Update it on every ingest, correction, consolidation, answer filing, and maintenance pass. Each entry should include link, one-line summary, category, updated date, source count, claim count, and useful tags.
    - `Colony/log.md` is chronological and append-only. Use parseable headings like `## [yyyy-MM-dd HH:mm] ingest | Title`, `query | Question`, `lint | Scope`, or `correction | Article`.
    - The log helps Hive understand what changed recently. Do not use it as a normal article body or user-facing narrative.
    """
}
