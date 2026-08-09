import Testing
import Foundation
@testable import HiveCore

// MARK: - AXTreeContextTests
//
// Locks the flat CDP Accessibility.getFullAXTree -> AXTree parsing contract
// (stable refs, child/root wiring, interactable counting) and the LLM prompt
// renderer used by hive.agent.axContext.

@Suite("AXTreeContext")
struct AXTreeContextTests {

    /// A realistic flat getFullAXTree payload: nodeId/parentId/childIds,
    /// AXValue objects, focusable inside properties, one ignored node, and
    /// one orphan (parentId referencing a missing node).
    private func fixture() -> [String: Any] {
        [
            "nodes": [
                [
                    "nodeId": 1,
                    "role": ["value": "rootWebArea"],
                    "name": ["value": "Example"],
                    "childIds": [2, 3],
                ],
                [
                    "nodeId": 2,
                    "role": ["value": "heading"],
                    "name": ["value": "Welcome"],
                    "parentId": 1,
                ],
                [
                    "nodeId": 3,
                    "role": ["value": "button"],
                    "name": ["value": "Search"],
                    "parentId": 1,
                    "boundingBox": ["x": 0, "y": 0, "width": 100, "height": 20],
                    "properties": [
                        ["name": "focusable", "value": ["type": "boolean", "value": true]]
                    ],
                ],
                [
                    "nodeId": 4,
                    "role": ["value": "textbox"],
                    "name": ["value": ""],
                    "parentId": 1,
                ],
                [
                    "nodeId": 5,
                    "role": ["value": "link"],
                    "name": ["value": "Docs"],
                    "parentId": 999,  // parent missing -> orphan root
                ],
                [
                    "nodeId": 6,
                    "role": ["value": "banner"],
                    "ignored": true,  // must be skipped
                ],
                [
                    "nodeId": 7,
                    "role": ["value": "paragraph"],
                    "name": ["value": "Body"],
                    "parentId": 1,
                ],
            ]
        ]
    }

    @Test("parses the flat shape with stable refs and skips ignored nodes")
    func parseBasics() {
        let tree = AXTreeParser.parse(fixture(), pageURL: "https://example.com", pageTitle: "Example")
        #expect(tree.nodes.count == 6)
        #expect(tree.nodeOrder == ["ref_0", "ref_1", "ref_2", "ref_3", "ref_4", "ref_6"])
        #expect(tree.nodes["ref_0"]?.role == "rootWebArea")
        #expect(tree.nodes["ref_1"]?.name == "Welcome")
        // ref_5 is the ignored banner — must not exist.
        #expect(tree.nodes["ref_5"] == nil)
    }

    @Test("wires children from childIds and supplements via parentId")
    func childWiring() {
        let tree = AXTreeParser.parse(fixture())
        // nodeId 1's childIds [2, 3] -> ref_1, ref_2; supplemented by ref_3
        // and ref_6 whose parentId resolves to nodeId 1.
        #expect(tree.nodes["ref_0"]?.children == ["ref_1", "ref_2", "ref_3", "ref_6"])
        #expect(tree.nodes["ref_2"]?.children == nil)
        #expect(tree.nodes["ref_1"]?.children == nil)
    }

    @Test("roots = parentless nodes; orphans with missing parents become roots")
    func rootDetection() {
        let tree = AXTreeParser.parse(fixture())
        // ref_0 (rootWebArea) is parentless; ref_4's parent (999) is missing.
        #expect(tree.rootRefs == ["ref_0", "ref_4"])
    }

    @Test("counts interactable roles and focusable nodes")
    func interactableCount() {
        let tree = AXTreeParser.parse(fixture())
        // button + textbox + link = 3 (paragraph/heading/root are not).
        #expect(tree.interactableCount == 3)
    }

    @Test("toPromptContext renders refs, roles, values, bounds, keyboard")
    func promptRendering() {
        let tree = AXTreeParser.parse(fixture(), pageURL: "https://example.com", pageTitle: "Example")
        let prompt = tree.toPromptContext()
        #expect(prompt.contains("[Page: Example]"))
        #expect(prompt.contains("[Interactable elements: 3]"))
        #expect(prompt.contains("ref_2 button \"Search\" [0,0 100x20] ⌨"))
        #expect(prompt.contains("ref_1 heading \"Welcome\""))
        #expect(prompt.contains("ref_4 link \"Docs\""))
    }

    @Test("toPromptContext truncates at maxNodes with a remainder note")
    func promptTruncation() {
        let tree = AXTreeParser.parse(fixture())
        let prompt = tree.toPromptContext(maxNodes: 2)
        let lines = prompt.split(separator: "\n").count
        // Header (2) + blank + up to 2 nodes + remainder note.
        #expect(lines <= 6)
        #expect(prompt.contains("more elements"))
    }

    @Test("empty payload yields an empty tree")
    func parseEmpty() {
        let tree = AXTreeParser.parse(["nodes": []])
        #expect(tree.nodes.isEmpty)
        #expect(tree.rootRefs.isEmpty)
        #expect(tree.interactableCount == 0)
        #expect(tree.toPromptContext().contains("[Page: unknown]"))
    }
}
