import Testing
import Foundation
@testable import HiveCore

// MARK: - AXTreeParserTests

struct AXTreeParserTests {

    @Test func parsesEmptyAXTree() {
        let tree = AXTreeParser.parse([:])
        #expect(tree.nodes.isEmpty)
        #expect(tree.interactableCount == 0)
    }

    @Test func parsesSimpleButton() {
        let children: [[String: Sendable]] = []
        let input: [String: Sendable] = [
            "nodes": [[
                "role": ["value": "button" as Sendable],
                "name": ["value": "Submit" as Sendable],
                "focusable": ["value": true as Sendable],
                "boundingBox": [
                    "x": 10.0 as Sendable, "y": 20.0 as Sendable, "width": 100.0 as Sendable, "height": 40.0 as Sendable
                ] as [String: Sendable],
                "children": children
            ] as [String: Sendable]]
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
        let children1: [[String: Sendable]] = []
        let input: [String: Sendable] = [
            "nodes": [[
                "role": ["value": "link" as Sendable],
                "name": ["value": "Homepage" as Sendable],
                "focusable": ["value": true as Sendable],
                "children": children1
            ] as [String: Sendable]]
        ]

        let tree = AXTreeParser.parse(input, pageURL: nil, pageTitle: "My Page")
        let context = tree.toPromptContext()

        #expect(context.contains("[Page: My Page]"))
        #expect(context.contains("link"))
        #expect(context.contains("Homepage"))
    }

    @Test func truncatesLargeTree() {
        var nodes: [[String: Sendable]] = []
        for i in 0..<200 {
            let ec: [[String: Sendable]] = []
            nodes.append([
                "role": ["value": "statictext" as Sendable],
                "name": ["value": "text \(i)" as Sendable],
                "focusable": ["value": false as Sendable],
                "children": ec
            ])
        }
        let input: [String: Sendable] = ["nodes": nodes]
        let tree = AXTreeParser.parse(input)

        let context = tree.toPromptContext(maxNodes: 50)
        #expect(context.contains("more elements"))
    }

    @Test func identifiesInteractableRoles() {
        let roles = ["button", "link", "textbox", "checkbox", "menuitem", "paragraph", "heading", "statictext"]
        var axNodes: [[String: Sendable]] = []
        for role in roles {
            let emptyChildren: [[String: Sendable]] = []
            axNodes.append([
                "role": ["value": role as Sendable],
                "name": ["value": role as Sendable],
                "focusable": ["value": false as Sendable],
                "children": emptyChildren
            ])
        }

        let input: [String: Sendable] = ["nodes": axNodes]
        let tree = AXTreeParser.parse(input)

        // 6 interactable (button, link, textbox, checkbox, menuitem) + 3 non-interactable
        #expect(tree.interactableCount == 5)
    }
}
