import SwiftUI
import HiveCore

/// Row-scoped drag/drop behavior for the horizontal tab strip.
///
/// The delegate owns only horizontal coordinate interpretation and payload
/// extraction. `BrowserState.reorderTab` remains the authority for
/// workspace, pinned/essential, group, and duplicate-ID validation.
@MainActor
struct HorizontalTabPillDropDelegate: DropDelegate {
    let targetID: String
    let state: BrowserState
    @Binding var insertionEdge: TabInsertionPlanner.Edge?
    @Binding var isTargeted: Bool
    let pillWidth: CGFloat

    /// The rendered pill width determines the midpoint. The delegate never
    /// consults a global backing-array index, so filtered strips remain safe.

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
        guard let selectedEdge = insertionEdge ?? edge(for: info) else {
            reset()
            return false
        }
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

    private func edge(for info: DropInfo) -> TabInsertionPlanner.Edge? {
        TabDropCoordinate.insertionEdge(x: info.location.x, targetWidth: pillWidth)
    }

    private func reset() {
        insertionEdge = nil
        isTargeted = false
    }
}
