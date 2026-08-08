import SwiftUI
import HiveCore

/// Row-scoped drag/drop behavior for the vertical tab rail.
///
/// The row owns the visual insertion line; this delegate owns only coordinate
/// interpretation and payload extraction. The model remains the authority on
/// whether the move is valid (workspace, pinned/essential class, and group
/// boundaries are enforced by `BrowserState.reorderTab`).
@MainActor
struct VerticalTabRowDropDelegate: DropDelegate {
    let targetID: String
    let state: BrowserState
    @Binding var insertionEdge: TabInsertionPlanner.Edge?
    @Binding var isTargeted: Bool

    /// The rendered row is 34pt tall with 6pt vertical padding on each side.
    /// The midpoint gives a stable before/after split without using any global
    /// backing-array index.
    private let rowHitHeight: CGFloat = 46

    func dropEntered(info: DropInfo) {
        isTargeted = true
        insertionEdge = edge(for: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        isTargeted = true
        insertionEdge = edge(for: info)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        reset()
    }

    func validateDrop(info: DropInfo) -> Bool {
        !info.itemProviders(for: [.text]).isEmpty
    }

    func performDrop(info: DropInfo) -> Bool {
        let selectedEdge = insertionEdge ?? edge(for: info)
        let providers = info.itemProviders(for: [.text])
        guard let provider = providers.first else {
            reset()
            return false
        }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let movingID = object as? String else { return }
            Task { @MainActor in
                _ = state.reorderTab(
                    movingID: movingID,
                    targetID: targetID,
                    edge: selectedEdge
                )
            }
        }
        reset()
        return true
    }

    private func edge(for info: DropInfo) -> TabInsertionPlanner.Edge {
        info.location.y < rowHitHeight / 2 ? .before : .after
    }

    private func reset() {
        insertionEdge = nil
        isTargeted = false
    }
}
