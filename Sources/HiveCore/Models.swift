import Foundation

// MARK: - Core models (wedge scope)

public struct TabInfo: Codable, Sendable, Equatable {
    public var id: String
    public var url: String
    public var title: String
    public var pinned: Bool
    public var active: Bool

    public init(id: String, url: String, title: String, pinned: Bool = false, active: Bool = false) {
        self.id = id; self.url = url; self.title = title; self.pinned = pinned; self.active = active
    }
}

public struct Capture: Codable, Sendable, Equatable {
    public var id: Int64
    public var url: String
    public var title: String
    public var text: String          // normalized extraction string; span offsets index THIS
    public var wordCount: Int
    public var confidence: Double
    public var version: Int
    public var capturedAt: Date

    public init(id: Int64, url: String, title: String, text: String, wordCount: Int,
                confidence: Double, version: Int, capturedAt: Date) {
        self.id = id; self.url = url; self.title = title; self.text = text
        self.wordCount = wordCount; self.confidence = confidence
        self.version = version; self.capturedAt = capturedAt
    }
}

public struct Span: Codable, Sendable, Equatable {
    public var id: String            // "{captureID}:v{n}:{spanIdx}"
    public var captureId: Int64
    public var captureVersion: Int
    public var idx: Int
    public var text: String
    public var charStart: Int
    public var charEnd: Int

    public init(id: String, captureId: Int64, captureVersion: Int, idx: Int,
                text: String, charStart: Int, charEnd: Int) {
        self.id = id; self.captureId = captureId; self.captureVersion = captureVersion
        self.idx = idx; self.text = text; self.charStart = charStart; self.charEnd = charEnd
    }
}

public struct Bookmark: Codable, Sendable, Equatable {
    public var url: String
    public var title: String
    public var createdAt: Date
    public init(url: String, title: String, createdAt: Date) {
        self.url = url; self.title = title; self.createdAt = createdAt
    }
}

public struct Citation: Codable, Sendable, Equatable {
    public var spanId: String
    public var captureId: Int64
    public var quote: String
    public init(spanId: String, captureId: Int64, quote: String) {
        self.spanId = spanId; self.captureId = captureId; self.quote = quote
    }
}

public enum AskTerminal: Codable, Sendable, Equatable {
    case done(answer: String, citations: [Citation], droppedClaims: [String])
    case refused(flavor: String, message: String)
}
