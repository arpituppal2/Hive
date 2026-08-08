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

// MARK: - AXTree Node

/// A simplified accessibility node suitable for LLM consumption.
public struct AXNode: Sendable, Codable, @unchecked Sendable {
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
    let children: [String]?
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
    /// Total interactable element count
    let interactableCount: Int
    /// Timestamp of capture
    let capturedAt: Date

    // MARK: Formatting

    /// Render the tree as a simple text format for LLM prompts.
    /// Each line: `ref role "name" = "value" [bounds]`
    func toPromptContext(maxNodes: Int = 100) -> String {
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

/// Parses a CDP Accessibility.getFullAXTree response into an AXTree.
enum AXTreeParser {

    /// Parse a CDP AXTree response into our simplified format.
    /// - Parameter axTreeJSON: The raw CDP response dictionary
    /// - Parameter pageURL: The page URL for context
    /// - Parameter pageTitle: The page title for context
    /// - Returns: A parsed AXTree ready for LLM consumption
    static func parse(
        _ axTreeJSON: [String: Sendable],
        pageURL: String? = nil,
        pageTitle: String? = nil
    ) -> AXTree {
        var nodes: [String: AXNode] = [:]
        var rootRefs: [String] = []
        var counter = 0
        var interactable = 0

        func nextRef() -> String { counter += 1; return "ref_\(counter)" }

        // Recursively flatten the CDP AXTree
        func flatten(_ node: [String: Sendable], parentRef: String?, parentChildren: inout [String]) {
            let ref = nextRef()

            let role = (node["role"] as? [String: Sendable])?["value"] as? String ?? "unknown"
            let name = (node["name"] as? [String: Sendable])?["value"] as? String
            let value = (node["value"] as? [String: Sendable])?["value"] as? String
            let desc = (node["description"] as? [String: Sendable])?["value"] as? String

            var bounds: [Double]? = nil
            if let bbox = node["boundingBox"] as? [String: Sendable] {
                let x = bbox["x"] as? Double ?? 0
                let y = bbox["y"] as? Double ?? 0
                let w = bbox["width"] as? Double ?? 0
                let h = bbox["height"] as? Double ?? 0
                bounds = [x, y, w, h]
            }

            let isFocusable = (node["focusable"] as? [String: Sendable])?["value"] as? Bool ?? false
            let childNodes = node["children"] as? [[String: Sendable]] ?? []

            var children: [String] = []
            for child in childNodes {
                flatten(child, parentRef: ref, parentChildren: &children)
            }

            let isInteractable = ["button", "link", "textbox", "searchbox", "combobox",
                                  "checkbox", "radio", "switch", "slider", "menuitem",
                                  "option", "tab", "treeitem", "listbox"].contains(role)

            if isInteractable || isFocusable { interactable += 1 }

            nodes[ref] = AXNode(
                ref: ref, role: role, name: name, value: value, desc: desc,
                bounds: bounds, focusable: isFocusable,
                children: children.isEmpty ? nil : children
            )

            parentChildren.append(ref)
        }

        // Parse top-level nodes from CDP response
        let axNodes = axTreeJSON["nodes"] as? [[String: Sendable]] ?? []

        for axNode in axNodes {
            var children: [String] = []
            flatten(axNode, parentRef: nil, parentChildren: &children)
            rootRefs.append(contentsOf: children)
        }

        return AXTree(
            url: pageURL,
            title: pageTitle,
            nodes: nodes,
            rootRefs: rootRefs,
            interactableCount: interactable,
            capturedAt: Date()
        )
    }
}

// MARK: - Helpers

extension String {
    func truncated(to maxLen: Int) -> String {
        count <= maxLen ? self : String(prefix(maxLen - 3)) + "..."
    }
}
