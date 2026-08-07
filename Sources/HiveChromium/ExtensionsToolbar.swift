import SwiftUI

// MARK: - ExtensionsToolbar
//
// Chrome-style extensions management. A puzzle piece icon opens a menu of installed
// extensions; pinned extensions render as small icons next to the address bar.

struct ExtensionsToolbar: View {
    @Environment(ChromiumBrowserState.self) private var state

    var body: some View {
        HStack(spacing: 6) {
            ForEach(state.installedExtensions.filter { $0.isPinned && $0.isEnabled }) { ext in
                extensionButton(for: ext)
            }

            if !state.installedExtensions.isEmpty {
                extensionsMenu
            }
        }
    }

    private func extensionButton(for ext: ExtensionItem) -> some View {
        Button(action: { handleExtensionTap(ext) }) {
            Image(systemName: ext.iconName)
                .font(HiveDesign.Typography.sidebarItemSemiBold)
                .foregroundStyle(Color.hiveAccent)
                .frame(width: 26, height: 26)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(ext.name)
    }

    private func handleExtensionTap(_ ext: ExtensionItem) {
        // Real extensions open their own popover/panel. Until install support
        // ships, a pinned icon opens the extensions manager — never a fake
        // assistant response pretending to be the extension.
        state.isExtensionsManagerOpen = true
    }

    private var extensionsMenu: some View {
        Menu {
            ForEach(state.installedExtensions) { ext in
                Toggle(isOn: Binding(
                    get: { ext.isPinned },
                    set: { _ in state.toggleExtensionPin(id: ext.id) }
                )) {
                    HStack(spacing: 8) {
                        Image(systemName: ext.iconName)
                        Text(ext.name)
                    }
                }
            }
        } label: {
            Image(systemName: "puzzlepiece.extension")
                .font(HiveDesign.Typography.sidebarItemSemiBold)
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .help("Extensions")
    }
}
