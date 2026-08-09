import Testing
import Foundation
@testable import HiveCore

// MARK: - AXTreeParserTests
//
// Locks the LEGACY recursive wire format (nested `children` arrays, top-level
// `focusable` AXValue, no nodeId) — the format the flat CDP parser must still
// accept. The real flat CDP shape is covered by AXTreeContextTests.

struct AXTreeParserTests {

    @Test func parsesEmptyAXTree() {
        let tree = AXTreeParser.parse([:])
        #expect(tree.nodes.isEmpty)
        #expect(tree.interactableCount == 0)
    }

    @Test func parsesSimpleButton() {
        let input: [String: Any] = [
            "nodes": [[
                "role": ["value": "button"],
                "name": ["value": "Submit"],
                "focusable": ["value": true],
                "boundingBox": ["x": 10.0, "y": 20.0, "width": 100.0, "height": 40.0],
                "children": []
            ]]
        ]

        let tree = AXTreeParser.parse(input, pageURL: "https://example.com", pageTitle: "Test")

        #expect(tree.nodes.count == 1)
        #expect(tree.interactableCount == 1)
        #expect(tree.url == "https://example.com")
        #expect(tree.title == "Test")

        let node = tree.nodes.values.first!
        #expect(node.role == "button")
        #expect(node.name == "Submit")
        #expect(node.focusable)
        #expect(node.bounds != nil && node.bounds!.count == 4)
    }

    @Test func rendersPromptContext() {
        let input: [String: Any] = [
            "nodes": [[
                "role": ["value": "link"],
                "name": ["value": "Homepage"],
                "focusable": ["value": true],
                "children": []
            ]]
        ]

        let tree = AXTreeParser.parse(input, pageURL: nil, pageTitle: "My Page")
        let context = tree.toPromptContext()

        #expect(context.contains("[Page: My Page]"))
        #expect(context.contains("link"))
        #expect(context.contains("Homepage"))
    }

    @Test func truncatesLargeTree() {
        var nodes: [[String: Any]] = []
        for i in 0..<200 {
            nodes.append([
                "role": ["value": "statictext"],
                "name": ["value": "text \(i)"],
                "focusable": ["value": false],
                "children": []
            ])
        }
        let input: [String: Any] = ["nodes": nodes]
        let tree = AXTreeParser.parse(input)

        let context = tree.toPromptContext(maxNodes: 50)
        #expect(context.contains("more elements"))
    }

    @Test func handlesNodesWithMissingFields() {
        let input: [String: Any] = [
            "nodes": [[
                "role": ["value": "button"]
                // missing name, focusable, children
            ]]
        ]
        let tree = AXTreeParser.parse(input)
        #expect(tree.nodes.count == 1)
        #expect(tree.interactableCount == 1)
    }

    @Test func parsesNestedChildren() {
        let input: [String: Any] = [
            "nodes": [[
                "role": ["value": "region"],
                "name": ["value": "outer"],
                "focusable": ["value": false],
                "children": [[
                    "role": ["value": "group"],
                    "name": ["value": "inner"],
                    "focusable": ["value": false],
                    "children": [[
                        "role": ["value": "statictext"],
                        "name": ["value": "deep"],
                        "focusable": ["value": false],
                        "children": []
                    ]]
                ]]
            ]]
        ]
        let tree = AXTreeParser.parse(input)
        // region -> group -> statictext, all wired depth-first.
        #expect(tree.nodes.count == 3)
        #expect(tree.rootRefs.count == 1)
        let rootRef = tree.rootRefs[0]
        #expect(tree.nodes[rootRef]?.role == "region")
        #expect(tree.nodes[rootRef]?.children?.count == 1)
        let groupRef = tree.nodes[rootRef]?.children?[0]
        #expect(tree.nodes[groupRef ?? ""]?.role == "group")
        #expect(tree.nodes[groupRef ?? ""]?.children?.count == 1)
        let deepRef = tree.nodes[groupRef ?? ""]?.children?[0]
        #expect(tree.nodes[deepRef ?? ""]?.name == "deep")
        #expect(tree.nodeOrder.count == 3)
    }

    @Test func toPromptContextIncludesPageURL() {
        let input: [String: Any] = [
            "nodes": [[
                "role": ["value": "link"],
                "name": ["value": "Docs"],
                "focusable": ["value": true],
                "children": []
            ]]
        ]
        let tree = AXTreeParser.parse(input, pageURL: "https://docs.example.com", pageTitle: "Documentation")
        let context = tree.toPromptContext()
        #expect(context.contains("Documentation"))
    }

    @Test func identifiesInteractableRoles() {
        let roles = ["button", "link", "textbox", "checkbox", "menuitem", "paragraph", "heading", "statictext"]
        var axNodes: [[String: Any]] = []
        for role in roles {
            axNodes.append([
                "role": ["value": role],
                "name": ["value": role],
                "focusable": ["value": false],
                "children": []
            ])
        }

        let input: [String: Any] = ["nodes": axNodes]
        let tree = AXTreeParser.parse(input)

        // 5 interactable (button, link, textbox, checkbox, menuitem) + 3 non-interactable
        #expect(tree.interactableCount == 5)
    }
}
