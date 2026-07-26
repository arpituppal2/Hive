import SwiftUI

// The Hive Browser — single macOS product.
// Swarm is integrated inside Hive (home, sidebar, omnibar modes, controlled actions).
// This is the rebuild starting point: no inherited slop, Cells not Bees.

@main
struct HiveApp: App {
    var body: some Scene {
        WindowGroup {
            RebootView()
        }
    }
}

private struct RebootView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("The Hive Browser")
                .font(.system(size: 22, weight: .semibold))
            Text("Rebuild in progress.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
