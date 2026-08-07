import SwiftUI
import HiveCore

// MARK: - JsonTreeView
//
// A collapsible tree view for displaying parsed JSON data. The view accepts
// `Any` (the output of `JSONSerialization.jsonObject`) and recursively renders
// keys, types, and values with syntax-highlighted colors. Arrays and objects
// are collapsible with disclosure arrows.
//
// Design: Warm syntax colors (amber strings, graphite keys, accent numbers/bools),
// monospaced font for values, micro-spring animations for collapse/expand.
// Uses a recursive `JsonNode` model to flatten the tree into a single list so
// SwiftUI's List can diff and animate efficiently.

/// A flattened node in the JSON tree. Each node represents one key-value pair
/// or a primitive value at the top level of an array.
struct JsonNode: Identifiable {
    let id: String
    let key: String?
    let value: JsonValue
    let depth: Int
    let isLast: Bool

    var childNodes: [JsonNode] = []

    enum JsonValue {
        case string(String)
        case number(String)
        case bool(Bool)
        case null
        case object([JsonNode])
        case array([JsonNode])

        var displayString: String {
            switch self {
            case .string(let s): return "\"\(s)\""
            case .number(let n): return n
            case .bool(let b):   return b ? "true" : "false"
            case .null:          return "null"
            case .object(let children): return "{ \(children.count) keys }"
            case .array(let children):  return "[ \(children.count) items ]"
            }
        }
    }
}

// MARK: - Builder

/// Recursively builds a flat list of `JsonNode`s from a parsed JSON object.
/// `key` is the parent key (nil for top-level arrays), `depth` tracks nesting.
func buildJsonNodes(from value: Any, key: String? = nil, depth: Int = 0, isLast: Bool = true) -> [JsonNode] {
    let id = UUID().uuidString

    switch value {
    case let dict as [String: Any]:
        let children = dict.map { (k, v) in
            buildJsonNodes(from: v, key: k, depth: depth + 1, isLast: false)
        }.flatMap { $0 }
        // Mark last child
            if let lastChild = children.last {
            let idx = children.count - 1
            var mutable = children
            mutable[idx] = JsonNode(
                id: lastChild.id,
                key: lastChild.key,
                value: lastChild.value,
                depth: lastChild.depth,
                isLast: true
            )
            return [JsonNode(id: id, key: key, value: .object(mutable), depth: depth, isLast: isLast, childNodes: mutable)]
        }
        return [JsonNode(id: id, key: key, value: .object([]), depth: depth, isLast: isLast)]

    case let array as [Any]:
        let children = array.enumerated().map { (i, v) in
            buildJsonNodes(from: v, key: "[\(i)]", depth: depth + 1, isLast: i == array.count - 1)
        }.flatMap { $0 }
        return [JsonNode(id: id, key: key, value: .array(children), depth: depth, isLast: isLast, childNodes: children)]

    case let str as String:
        return [JsonNode(id: id, key: key, value: .string(str), depth: depth, isLast: isLast)]        case let num as NSNumber:
        // Detect boolean: compare the objCType pointee to the 'c' (char) or 'B' (C99 bool) encoding.
        let type = num.objCType.pointee
        if type == 99 || type == 66 { // 'c' or 'B'
            return [JsonNode(id: id, key: key, value: .bool(num.boolValue), depth: depth, isLast: isLast)]
        }
        return [JsonNode(id: id, key: key, value: .number(num.stringValue), depth: depth, isLast: isLast)]

    case let num as Int:
        return [JsonNode(id: id, key: key, value: .number(String(num)), depth: depth, isLast: isLast)]

    case let num as Double:
        return [JsonNode(id: id, key: key, value: .number(String(num)), depth: depth, isLast: isLast)]

    case is NSNull:
        return [JsonNode(id: id, key: key, value: .null, depth: depth, isLast: isLast)]

    default:
        return [JsonNode(id: id, key: key, value: .string("\(value)"), depth: depth, isLast: isLast)]
    }
}

// MARK: - JsonTreeView

struct JsonTreeView: View {
    let data: Data
    @State private var expandedIDs: Set<String> = []
    @State private var nodes: [JsonNode] = []
    @State private var parseError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: HiveSpacing.s8) {
                Image(systemName: "curlybraces")
                    .font(HiveTypography.font(.panelTitle))
                    .foregroundStyle(state.activeAccentColor)
                Text("JSON Viewer")
                    .hiveType(.chromeTitle)
                    .foregroundStyle(.hiveInk)
                Spacer()
                Button("Collapse All") {
                    expandedIDs.removeAll()
                }
                .buttonStyle(.plain)
                .hiveType(.caption1)
                .foregroundStyle(.hiveGraphite)
                .help("Collapse all nodes")
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        String(data: data, encoding: .utf8) ?? "",
                        forType: .string
                    )
                }
                .buttonStyle(.plain)
                .hiveType(.caption1)
                .foregroundStyle(.hiveGraphite)
                .help("Copy raw JSON")
            }
            .padding(.horizontal, HiveSpacing.s16)
            .padding(.vertical, HiveSpacing.s8)
            .background(Color.hiveSurface.opacity(0.5))

            Divider().overlay(Color.hiveBorderSubtle)

            if let error = parseError {
                VStack(spacing: HiveSpacing.s8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(HiveTypography.font(.featureTitle))
                        .foregroundStyle(state.activeAccentColor)
                    Text("Invalid JSON")
                        .hiveType(.body)
                        .foregroundStyle(.hiveInk)
                    Text(error)
                        .hiveType(.caption1)
                        .foregroundStyle(.hiveGraphite)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, HiveSpacing.s32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(HiveSpacing.s24)
            } else if nodes.isEmpty {
                ProgressView("Parsing JSON…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(nodes) { node in
                            jsonNodeRow(node)
                        }
                    }
                    .padding(.vertical, HiveSpacing.s8)
                    .padding(.horizontal, HiveSpacing.s4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.system(size: 12, design: .monospaced))
                .background(Color.hiveBackground)
            }
        }
        .onAppear { parseJSON() }
    }

    @Environment(ChromeState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func parseJSON() {
        do {
            let obj = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed, .mutableContainers])
            nodes = buildJsonNodes(from: obj)
            // Auto-expand first 2 levels
            for node in nodes {
                expandedIDs.insert(node.id)
                for child in node.childNodes.prefix(20) {
                    expandedIDs.insert(child.id)
                }
            }
        } catch {
            parseError = error.localizedDescription
        }
    }

    // MARK: - Row builder

    /// Returns a view for a single JSON node row. Uses `AnyView` to break the
    /// recursive type inference that Swift 6 strict concurrency rejects.
    private func jsonNodeRow(_ node: JsonNode) -> AnyView {
        let hasChildren: Bool = {
            switch node.value {
            case .object(let c), .array(let c): return !c.isEmpty
            default: return false
            }
        }()
        let isExpanded = expandedIDs.contains(node.id)

        let row = HStack(spacing: 0) {
            // Indentation
            Color.clear
                .frame(width: CGFloat(node.depth) * 16, height: 24)

            // Disclosure arrow
            if hasChildren {
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.8)) {
                        if isExpanded { expandedIDs.remove(node.id) }
                        else { expandedIDs.insert(node.id) }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(HiveTypography.font(.microBold))
                        .foregroundStyle(.hiveGraphite)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 16)
            }

            // Key
            if let key = node.key {
                Text(key)
                    .foregroundStyle(.hiveInk.opacity(0.8))
                    .lineLimit(1)
            } else {
                Color.clear.frame(width: 0)
            }

            if node.key != nil {
                Text(": ")
                    .foregroundStyle(.hiveGraphite)
            }

            // Value
            valueView(for: node.value, isExpanded: isExpanded)
                .lineLimit(isExpanded && hasChildren ? 1 : 5)
        }
        .padding(.leading, HiveSpacing.s8)
        .padding(.trailing, HiveSpacing.s12)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            if hasChildren {
                withAnimation(reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.8)) {
                    if isExpanded { expandedIDs.remove(node.id) }
                    else { expandedIDs.insert(node.id) }
                }
            }
        }

        // Children — separate VStack so the recursive type doesn't create an infinite type
        let childrenView: AnyView?
        if isExpanded && hasChildren {
            let children: [JsonNode] = {
                switch node.value {
                case .object(let c), .array(let c): return c
                default: return []
                }
            }()
            childrenView = AnyView(
                ForEach(children) { child in
                    self.jsonNodeRow(child)
                }
            )
        } else {
            childrenView = nil
        }

        return AnyView(
            VStack(spacing: 0) {
                row
                if let cv = childrenView {
                    cv
                }
            }
        )
    }

    // MARK: - Value views

    @ViewBuilder
    private func valueView(for value: JsonNode.JsonValue, isExpanded: Bool) -> some View {
        switch value {
        case .string(let s):
            Text("\"\(s)\"")
                .foregroundStyle(state.activeAccentColor)
                .textSelection(.enabled)

        case .number(let n):
            Text(n)
                .foregroundStyle(state.activeAccentColor)
                .textSelection(.enabled)

        case .bool(let b):
            HStack(spacing: 4) {
                Circle()
                    .fill(b ? Color.green : Color.red.opacity(0.6))
                    .frame(width: 6, height: 6)
                Text(b ? "true" : "false")
                    .foregroundStyle(b ? Color.green : Color.red.opacity(0.8))
            }

        case .null:
            Text("null")
                .foregroundStyle(.hiveGraphite.opacity(0.6))
                .italic()

        case .object(let children):
            if isExpanded {
                Text("{")
                    .foregroundStyle(.hiveGraphite)
            } else {
                Text("{ \(children.count) \(children.count == 1 ? "key" : "keys") }")
                    .foregroundStyle(.hiveGraphite)
            }

        case .array(let children):
            if isExpanded {
                Text("[")
                    .foregroundStyle(.hiveGraphite)
            } else {
                Text("[ \(children.count) \(children.count == 1 ? "item" : "items") ]")
                    .foregroundStyle(.hiveGraphite)
            }
        }
    }
}
