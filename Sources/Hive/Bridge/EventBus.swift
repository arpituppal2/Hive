import Foundation

/// Event bus: native → chrome push channel. Web polls `events.get {cursor}`.
/// 500-event ring per audience; events delivered once per cursor advance.
public final class EventBus: @unchecked Sendable {
    public struct Event: Codable, Sendable {
        public var id: Int
        public var type: String
        public var payload: [String: JSONValue]

        public init(id: Int, type: String, payload: [String: JSONValue]) {
            self.id = id; self.type = type; self.payload = payload
        }
    }

    private let lock = NSLock()
    private var ring: [Event] = []
    private var nextID = 1
    private let capacity = 500

    public init() {}

    /// Appends an event; returns its cursor id.
    @discardableResult
    public func emit(_ type: String, _ payload: [String: JSONValue] = [:]) -> Int {
        lock.lock(); defer { lock.unlock() }
        let e = Event(id: nextID, type: type, payload: payload)
        nextID += 1
        ring.append(e)
        if ring.count > capacity { ring.removeFirst(ring.count - capacity) }
        return e.id
    }

    public func since(_ cursor: Int) -> (cursor: Int, events: [Event]) {
        lock.lock(); defer { lock.unlock() }
        let pending = ring.filter { $0.id > cursor }
        return (cursor: nextID - 1, events: pending)
    }
}

/// Minimal JSON value type for heterogeneous event payloads.
public enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    public init(_ any: Any) {
        switch any {
        case let s as String: self = .string(s)
        case let b as Bool: self = .bool(b)
        case let i as Int: self = .int(i)
        case let d as Double: self = .double(d)
        case let a as [Any]: self = .array(a.map(JSONValue.init))
        case let o as [String: Any]: self = .object(o.mapValues(JSONValue.init))
        default: self = .null
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int.self) { self = .int(v) }
        else if let v = try? c.decode(Double.self) { self = .double(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else { self = .null }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }

    public var stringValue: String? { if case .string(let s) = self { return s }; return nil }
    public var boolValue: Bool? { if case .bool(let b) = self { return b }; return nil }
    public var intValue: Int? {
        switch self {
        case .int(let i): return i
        case .double(let d): return Int(d)
        default: return nil
        }
    }
}
