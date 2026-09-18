import Foundation

/// Deterministic paragraph span splitter. One owner file; unit-tested on fixtures.
///
/// Rules (design v1.1):
/// - Split source text into paragraphs on blank lines / structural breaks.
/// - Paragraph >120 words: split at sentence boundaries (hard cut only if no boundary).
/// - Chunks <20 words merge with nearest neighbor.
/// - Offsets index the stored normalized extraction string, never live DOM.
public enum SpanSplitter {

    public static let maxWords = 120
    public static let minWords = 20

    public static func spans(in text: String, captureId: Int64, version: Int) -> [Span] {
        var out: [Span] = []
        let ns = text as NSString
        var raw: [(start: Int, end: Int)] = []

        // Paragraph boundaries: blank-line separated blocks.
        var blockStart = text.startIndex
        var cursor = text.startIndex
        while cursor < text.endIndex {
            if cursor > text.startIndex {
                // Count a "blank line" as two consecutive newlines (with optional spaces).
                let prev = text[text.index(before: cursor)]
                if prev == "\n" && cursor < text.endIndex {
                    var lookahead = cursor
                    while lookahead < text.endIndex, text[lookahead] == " " || text[lookahead] == "\t" {
                        lookahead = text.index(after: lookahead)
                    }
                    if lookahead < text.endIndex, text[lookahead] == "\n" {
                        let startOff = ns.offset(of: blockStart) ?? 0
                        let endOff = ns.offset(of: cursor) ?? 0
                        if endOff > startOff { raw.append((startOff, endOff)) }
                        blockStart = text.index(after: lookahead)
                        cursor = blockStart
                        continue
                    }
                }
            }
            cursor = text.index(after: cursor)
        }
        let tailStart = ns.offset(of: blockStart) ?? 0
        if ns.length > tailStart { raw.append((tailStart, ns.length)) }

        // Word-count clamp per paragraph → chunk ranges.
        var chunks: [(Int, Int)] = []
        for para in raw {
            let paraText = ns.substring(with: NSRange(para.start..<para.end))
            let words = wordOffsets(paraText)
            guard !words.isEmpty else { continue }
            if words.count <= maxWords {
                chunks.append((para.start + words.first!.start, para.start + words.last!.end))
            } else {
                // Sentence-boundary split.
                var sentenceRanges: [(Int, Int)] = []
                var sStart = words[0].start
                for (i, w) in words.enumerated() {
                    let ch = charAt(paraText, w.end - 1)
                    let nextIsBoundary = i + 1 >= words.count || isSentenceEnd(ch, andNext: charAt(paraText, min(w.end, paraText.count - 1)))
                    if isTerminal(ch) && nextIsBoundary {
                        sentenceRanges.append((sStart, w.end))
                        sStart = w.end + 1
                    }
                }
                if sentenceRanges.isEmpty { sentenceRanges = [(words.first!.start, words.last!.end)] }
                // Group sentences into ≤maxWord chunks.
                var groupStart = sentenceRanges[0].0
                var count = 0
                for (i, r) in sentenceRanges.enumerated() {
                    let wc = wordCount(ns.substring(with: NSRange(para.start + r.0..<para.start + r.1)))
                    count += wc
                    let isLast = i + 1 == sentenceRanges.count
                    let nextWc = isLast ? 0 : wordCount(ns.substring(with: NSRange(para.start + sentenceRanges[i+1].0..<para.start + sentenceRanges[i+1].1)))
                    if count >= maxWords || (count >= maxWords / 2 && count + nextWc > maxWords) || isLast {
                        chunks.append((para.start + groupStart, para.start + r.1))
                        groupStart = isLast ? r.1 : sentenceRanges[i+1].0
                        count = 0
                    }
                }
            }
        }

        // Merge <20-word chunks with nearest neighbor.
        var merged: [(Int, Int)] = []
        for c in chunks {
            if let last = merged.last,
               wordCount(ns.substring(with: NSRange(c.0..<c.1))) < minWords {
                merged[merged.count - 1] = (last.0, c.1)
            } else if let last = merged.last,
                      wordCount(ns.substring(with: NSRange(last.0..<last.1))) < minWords {
                merged[merged.count - 1] = (last.0, c.1)
            } else {
                merged.append(c)
            }
        }

        for (i, r) in merged.enumerated() where r.1 > r.0 {
            let t = ns.substring(with: NSRange(r.0..<r.1)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            out.append(Span(id: "\(captureId):v\(version):\(i)", captureId: captureId,
                            captureVersion: version, idx: i, text: t,
                            charStart: r.0, charEnd: r.1))
        }
        return out
    }

    struct WordOffset { var start: Int; var end: Int }

    private static func wordOffsets(_ s: String) -> [WordOffset] {
        var out: [WordOffset] = []
        var i = s.startIndex
        let ns = s as NSString
        while i < s.endIndex {
            while i < s.endIndex, s[i].isWhitespace { i = s.index(after: i) }
            guard i < s.endIndex else { break }
            let start = i
            while i < s.endIndex, !s[i].isWhitespace { i = s.index(after: i) }
            out.append(WordOffset(start: ns.offset(of: start) ?? 0, end: ns.offset(of: i) ?? 0))
        }
        return out
    }

    private static func wordCount(_ s: String) -> Int {
        s.split(whereSeparator: \.isWhitespace).count
    }

    private static func charAt(_ s: String, _ offset: Int) -> Character {
        let ns = s as NSString
        guard offset >= 0 && offset < ns.length else { return " " }
        return Character(ns.substring(with: NSRange(offset..<offset + 1)))
    }

    private static func isTerminal(_ c: Character) -> Bool {
        c == "." || c == "!" || c == "?" || c == "。" || c == "！" || c == "？"
    }

    private static func isSentenceEnd(_ prev: Character, andNext: Character) -> Bool {
        isTerminal(prev) || andNext.isWhitespace || andNext == "\n"
    }
}

extension NSString {
    /// UTF-16 offset of an index (matches NSRange math used throughout).
    fileprivate func offset(of i: String.Index) -> Int? {
        i.utf16Offset(in: self as String)
    }
}
