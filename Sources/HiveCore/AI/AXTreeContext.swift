import Foundation

// MARK: - AXTreeContext
//
// Converts a CDP Accessibility.getFullAXTree response into an LLM-readable
// simplified YAML-like representation. Used by agentic browsing tools
// (Phase 2 — P2.2) to give models a structured view of the page for
// element targeting (click, type, read).
//
// Architecture: Inspired by Comet's AXTree → YAML approach and Astro's
// CDP agent tools. The output is a flat list of interactable elements
// with ref IDs that models can reference in tool calls.
//
// Wire format note: Accessibility.getFullAXTree returns a FLAT `nodes`
// array where every node carries `nodeId`, `parentId`, and `childIds`
// (integer IDs), plus AXValue objects for role/name/value/description and
// a `properties` array (focusable lives there, not as a top-level field).
// The parser below consumes exactly that shape.

// MARK: - AXTree Node

/// A simplified accessibility node suitable for LLM consumption.
public struct AXNode: Sendable, Codable {
    /// Reference ID for element targeting (e.g., "ref_42")
    public let ref: String
    /// ARIA role or inferred role (button, link, textbox, heading, etc.)
    public let role: String
    /// Accessible name (button label, link text, heading content)
    public let name: String?
    /// Accessible value (text field content, slider value)
    public let value: String?
    /// Accessible description (tooltip, aria-description)
    let desc: String?
    /// Bounding box in viewport coordinates: [x, y, width, height]
    let bounds: [Double]?
    /// Whether this element is focusable
    let focusable: Bool
    /// Child refs — only for container roles
    var children: [String]?
}

// MARK: - AXTree

/// A flattened accessibility tree ready for LLM consumption.
public struct AXTree: Sendable, Codable {
    /// Page URL this tree was captured from
    let url: String?
    /// Page title
    let title: String?
    /// All nodes, keyed by ref ID
    let nodes: [String: AXNode]
    /// Top-level node refs (roots)
    let rootRefs: [String]
    /// All node refs in capture order (stable ordering for consumers;
    /// `snapshot()` must not rely on dictionary ordering).
    let nodeOrder: [String]
    /// Total interactable element count
    let interactableCount: Int
    /// Timestamp of capture
    let capturedAt: Date

    // MARK: Formatting

    /// Render the tree as a simple text format for LLM prompts.
    /// Each line: `ref role "name" = "value" [bounds]`
    public func toPromptContext(maxNodes: Int = 100) -> String {
        var lines: [String] = ["[Page: \(title ?? url ?? "unknown")]"]
        lines.append("[Interactable elements: \(interactableCount)]")
        lines.append("")

        var seen = 0
        var queue = rootRefs

        while !queue.isEmpty, seen < maxNodes {
            let ref = queue.removeFirst()
            guard let node = nodes[ref] else { continue }

            var line = "\(node.ref) \(node.role)"
            if let name = node.name, !name.isEmpty {
                line += " \"\(name.truncated(to: 60))\""
            }
            if let value = node.value, !value.isEmpty {
                line += " = \"\(value.truncated(to: 40))\""
            }
            if let bounds = node.bounds, bounds.count == 4 {
                line += " [\(Int(bounds[0])),\(Int(bounds[1])) \(Int(bounds[2]))x\(Int(bounds[3]))]"
            }
            if node.focusable {
                line += " ⌨"
            }

            lines.append(line)
            seen += 1

            if let children = node.children {
                queue.insert(contentsOf: children, at: 0)
            }
        }

        if seen >= maxNodes {
            lines.append("... (\(interactableCount - maxNodes) more elements)")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - AXTreeParser

/// Parses the flat CDP `Accessibility.getFullAXTree` response shape into an
/// `AXTree` with stable ref IDs and wired parent/child structure.
enum AXTreeParser {

    /// Roles the agent can meaningfully target.
    private static let interactableRoles: Set<String> = [
        "button", "link", "textbox", "searchbox", "combobox", "checkbox",
        "radio", "switch", "slider", "menuitem", "option", "tab", "treeitem",
        "listbox", "spinbutton", "meter", "scrollbar", "colorwell", "date",
        "datetime", "gridcell",
    ]

    /// Parse a CDP `Accessibility.getFullAXTree` payload.
    /// - Parameter axTreeJSON: the `result` object — `{ "nodes": [...] }`.
    /// - Parameter pageURL: page URL for the prompt header (best effort).
    /// - Parameter pageTitle: page title for the prompt header (best effort).
    /// - Returns: an AXTree keyed by `ref_<index>` in capture order, with
    ///   children/roots derived from CDP's `childIds`/`parentId`.
    ///
    /// Two wire formats are supported: the real flat CDP shape (every node
    /// carries `nodeId`; structure comes from `childIds`/`parentId`) and the
    /// legacy recursive shape (nested `children` arrays, no `nodeId`).
    static func parse(
        _ axTreeJSON: [String: Any],
        pageURL: String? = nil,
        pageTitle: String? = nil
    ) -> AXTree {
        let rawNodes = axTreeJSON["nodes"] as? [[String: Any]] ?? []
        if rawNodes.contains(where: { asInt($0["nodeId"]) != nil }) {
            return parseFlat(rawNodes, pageURL: pageURL, pageTitle: pageTitle)
        }
        return parseRecursive(axTreeJSON, pageURL: pageURL, pageTitle: pageTitle)
    }

    /// Parses the flat CDP shape (nodeId/parentId/childIds).
    private static func parseFlat(
        _ rawNodes: [[String: Any]],
        pageURL: String?,
        pageTitle: String?
    ) -> AXTree {
        _ = pageURL
        _ = pageTitle
        var nodes: [String: AXNode] = [:]
        var nodeOrder: [String] = []
        var nodeIDToRef: [Int: String] = [:]
        var parentOf: [String: String] = [:]  // childRef -> parentRef
        var interactable = 0

        // Pass 1 — assign stable refs by array index (ref_0, ref_1, …),
        // skipping CDP `ignored` nodes.
        for (index, raw) in rawNodes.enumerated() {
            if (raw["ignored"] as? Bool) == true { continue }
            let ref = "ref_\(index)"
            nodeOrder.append(ref)
            if let nodeID = asInt(raw["nodeId"]) {
                nodeIDToRef[nodeID] = ref
            }
            let role = axValueString(raw["role"]) ?? "unknown"
            let focusable = isFocusable(raw)
            if interactableRoles.contains(role) || focusable {
                interactable += 1
            }
            nodes[ref] = AXNode(
                ref: ref,
                role: role,
                name: axValueString(raw["name"]),
                value: axValueString(raw["value"]),
                desc: axValueString(raw["description"]),
                bounds: parseBounds(raw["boundingBox"]),
                focusable: focusable,
                children: nil  // wired in pass 2
            )
        }

        // Pass 2a — resolve parent links in BOTH directions first, so the
        // children build (2b) can see every parent link regardless of array
        // order.
        for (index, raw) in rawNodes.enumerated() {
            if (raw["ignored"] as? Bool) == true { continue }
            let ref = "ref_\(index)"
            guard nodes[ref] != nil else { continue }
            if let parentID = asInt(raw["parentId"]),
               let parentRef = nodeIDToRef[parentID] {
                parentOf[ref] = parentRef
            }
            if let childIDs = raw["childIds"] as? [Any] {
                for childID in childIDs {
                    if let childRef = nodeIDToRef[asInt(childID) ?? -1] {
                        parentOf[childRef] = ref
                    }
                }
            }
        }

        // Pass 2b — build children lists: childIds first, then supplement any
        // child whose parentId resolved to this ref but was missing from
        // childIds (real-world CDP inconsistency tolerance).
        for (index, raw) in rawNodes.enumerated() {
            if (raw["ignored"] as? Bool) == true { continue }
            let ref = "ref_\(index)"
            guard nodes[ref] != nil else { continue }
            var childRefs: [String] = []
            if let childIDs = raw["childIds"] as? [Any] {
                for childID in childIDs {
                    if let childRef = nodeIDToRef[asInt(childID) ?? -1] {
                        childRefs.append(childRef)
                    }
                }
            }
            // Supplement in deterministic capture order (nodeOrder), never
            // parentOf's dictionary iteration order — Swift dicts randomize
            // iteration per process, which made this flaky across runs.
            for childRef in nodeOrder {
                guard let parentRef = parentOf[childRef], parentRef == ref else { continue }
                if !childRefs.contains(childRef) { childRefs.append(childRef) }
            }
            if !childRefs.isEmpty {
                if var node = nodes[ref] {
                    node.children = childRefs
                    nodes[ref] = node
                }
            }
        }

        // Roots — nodes whose CDP parent is absent or unresolved.
        let rootRefs = nodeOrder.filter { parentOf[$0] == nil }

        return AXTree(
            url: pageURL,
            title: pageTitle,
            nodes: nodes,
            rootRefs: rootRefs,
            nodeOrder: nodeOrder,
            interactableCount: interactable,
            capturedAt: Date()
        )
    }

    /// Parses the legacy recursive shape (nested `children` arrays). refs are
    /// assigned in depth-first capture order. Preserves the pre-existing
    /// AXTreeParserTests contract.
    private static func parseRecursive(
        _ axTreeJSON: [String: Any],
        pageURL: String?,
        pageTitle: String?
    ) -> AXTree {
        var nodes: [String: AXNode] = [:]
        var nodeOrder: [String] = []
        var rootRefs: [String] = []
        var counter = 0
        var interactable = 0

        func nextRef() -> String { counter += 1; return "ref_\(counter)" }

        func flatten(_ node: [String: Any], parentChildren: inout [String]) {
            let ref = nextRef()
            let role = axValueString(node["role"]) ?? "unknown"
            let focusable = isFocusable(node)
            if interactableRoles.contains(role) || focusable { interactable += 1 }
            var children: [String] = []
            if let childNodes = node["children"] as? [[String: Any]] {
                for child in childNodes { flatten(child, parentChildren: &children) }
            }
            nodes[ref] = AXNode(
                ref: ref,
                role: role,
                name: axValueString(node["name"]),
                value: axValueString(node["value"]),
                desc: axValueString(node["description"]),
                bounds: parseBounds(node["boundingBox"]),
                focusable: focusable,
                children: children.isEmpty ? nil : children
            )
            nodeOrder.append(ref)
            parentChildren.append(ref)
        }

        for node in axTreeJSON["nodes"] as? [[String: Any]] ?? [] {
            var children: [String] = []
            flatten(node, parentChildren: &children)
            rootRefs.append(contentsOf: children)
        }

        return AXTree(
            url: pageURL,
            title: pageTitle,
            nodes: nodes,
            rootRefs: rootRefs,
            nodeOrder: nodeOrder,
            interactableCount: interactable,
            capturedAt: Date()
        )
    }

    // MARK: CDP value extraction helpers

    private static func asInt(_ value: Any?) -> Int? {
        if let v = value as? Int { return v }
        if let v = value as? NSNumber { return v.intValue }
        return nil
    }

    private static func axValueString(_ value: Any?) -> String? {
        (value as? [String: Any])?["value"] as? String
    }

    private static func parseBounds(_ value: Any?) -> [Double]? {
        guard let box = value as? [String: Any],
              let x = numberValue(box["x"]), let y = numberValue(box["y"]),
              let w = numberValue(box["width"]), let h = numberValue(box["height"])
        else { return nil }
        return [x, y, w, h]
    }

    /// Coerces a CDP JSON number (Int, Double, or NSNumber — JSON integers
    /// arrive as NSNumber through JSONSerialization, Swift literals as Int).
    private static func numberValue(_ value: Any?) -> Double? {
        if let v = value as? Double { return v }
        if let v = value as? Int { return Double(v) }
        if let v = value as? NSNumber { return v.doubleValue }
        return nil
    }

    /// CDP puts `focusable` inside the node's `properties` array as an
    /// `{name, value: AXValue}` entry; legacy fixtures used a top-level
    /// `focusable: {value: true}` AXValue. Accept both.
    private static func isFocusable(_ raw: [String: Any]) -> Bool {
        if let props = raw["properties"] as? [[String: Any]] {
            for prop in props where (prop["name"] as? String) == "focusable" {
                if let val = prop["value"] as? [String: Any],
                   (val["value"] as? Bool) == true {
                    return true
                }
            }
        }
        if let val = raw["focusable"] as? [String: Any],
           (val["value"] as? Bool) == true {
            return true
        }
        return false
    }
}

// MARK: - Helpers

extension String {
    func truncated(to maxLen: Int) -> String {
        count <= maxLen ? self : String(prefix(maxLen - 3)) + "..."
    }
}
