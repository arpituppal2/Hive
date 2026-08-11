import SwiftUI

// MARK: - CustomizePanel
//
// Chrome-style appearance panel for picking accent color and toggling performance features.

struct CustomizePanel: View {
    @Environment(BrowserState.self) private var state

    var body: some View {
        @Bindable var state = state

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Customize Hive")
                    .font(HiveDesign.Typography.dialogTitleBold)
                Spacer()
                Button(action: { state.isCustomizePanelOpen = false }) {
                    Image(systemName: "xmark")
                        .font(HiveDesign.Typography.sidebarItemBold)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("Theme")
                .font(HiveDesign.Typography.sidebarItemSemiBold)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 36))], spacing: 10) {
                ForEach(ThemePreset.presets) { preset in
                    Button(action: { state.setAccentColor(hex: preset.colorHex) }) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: preset.colorHex) ?? Color.hiveAccent)
                                .frame(width: 28, height: 28)
                            if state.browserAccentColorHex == preset.colorHex {
                                Image(systemName: "checkmark")
                                    .font(HiveDesign.Typography.captionBold)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(preset.name)
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Memory Saver")
                        .font(HiveDesign.Typography.bodyMedium)
                    Text("Free memory from inactive tabs")
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $state.isMemorySaverEnabled)
            }

            Divider()

            Button(action: { state.isBoostsPanelOpen = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(HiveDesign.Typography.bodyMedium)
                        .foregroundStyle(Color.hiveAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Boosts")
                            .font(HiveDesign.Typography.bodyMedium)
                            .foregroundStyle(.primary)
                        Text("\(state.boosts.count) site style\(state.boosts.count == 1 ? "" : "s")")
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(HiveDesign.Typography.captionBold)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Manage site boosts")
        }
        .padding(16)
        .frame(width: 220)
        .background(HiveDesign.Material.panel)
        .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 5)
    }
}
