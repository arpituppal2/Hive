import SwiftUI
import HiveCore

// MARK: - SafetyCheckSheet
//
// Chrome chrome://settings/safetyCheck parity. Runs the pure HiveCore
// SafetyCheckPolicy against live state and renders one row per check with a
// status icon, honest detail copy, and a per-row action that opens the most
// relevant panel. Every check runs locally — passwords never leave the device.

struct SafetyCheckSheet: View {
    @Environment(BrowserState.self) private var state
    @State private var items: [SafetyCheckItem] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield")
                    .font(HiveDesign.Typography.panelTitleMedium)
                    .foregroundStyle(HiveDesign.Accent.primary)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Safety Check")
                        .font(HiveDesign.Typography.subHeadingBold)
                    Text("Reviewing your browsing health")
                        .font(HiveDesign.Typography.buttonCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Run again") { runCheck() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Button(action: { state.isSafetyCheckPanelOpen = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(HiveDesign.Typography.bodyLarge)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            // Report rows
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        row(for: item)
                        if item.id != items.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()

            // Footer
            VStack(alignment: .leading, spacing: 6) {
                Text("Every check runs on this device. Saved passwords are never uploaded, and extension behavior is never inspected — install only from sources you trust.")
                    .font(HiveDesign.Typography.buttonCaption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    Button("Done") { state.isSafetyCheckPanelOpen = false }
                        .buttonStyle(.borderedProminent)
                        .tint(HiveDesign.Accent.primary)
                }
            }
            .padding(14)
        }
        .background(HiveDesign.Material.panel)
        .frame(width: 480)
        .task { runCheck() }
    }

    private func runCheck() {
        items = state.safetyCheckItems()
    }

    private func row(for item: SafetyCheckItem) -> some View {
        Button {
            state.openSafetyCheckTarget(item.kind)
        } label: {
            HStack(spacing: 10) {
                statusIcon(for: item.status)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(HiveDesign.Typography.bodyMedium)
                        .foregroundStyle(.primary)
                    Text(item.detail)
                        .font(HiveDesign.Typography.buttonCaption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(HiveDesign.Typography.microLabel)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statusIcon(for status: SafetyCheckStatus) -> some View {
        switch status {
        case .pass:
            Image(systemName: "checkmark.circle.fill")
                .font(HiveDesign.Typography.bodyLarge)
                .foregroundStyle(.green)
        case .warn:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(HiveDesign.Typography.bodyLarge)
                .foregroundStyle(.orange)
        case .info:
            Image(systemName: "info.circle.fill")
                .font(HiveDesign.Typography.bodyLarge)
                .foregroundStyle(.blue)
        }
    }
}
