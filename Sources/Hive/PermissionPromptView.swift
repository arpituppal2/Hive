import SwiftUI
import CefKit

// MARK: - PermissionPromptView
//
// Chrome-style permission banner. Shows when a page requests camera,
// microphone, location, notifications, or automatic downloads and no stored
// decision exists. The front of `state.pendingPermissionRequests` renders
// here; resolving pops it and reveals the next queued request.

struct PermissionPromptView: View {
    @Environment(BrowserState.self) private var state
    let prompt: PendingPermissionRequest

    private var requestedKinds: [CefPermissionKind] {
        PermissionKindMapper.kinds(in: prompt.kinds)
    }

    var body: some View {
        HStack(spacing: HiveDesign.Space.lg) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: HiveDesign.Icon.large, weight: .semibold))
                .foregroundStyle(Color.hiveAccent)
                .frame(width: 34, height: 34)
                .background(Color.hiveAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.md, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("\\(prompt.host) wants to use:")
                    .font(.system(size: HiveDesign.Typography.sizeBody, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 10) {
                    ForEach(requestedKinds, id: \.self) { kind in
                        Label(PermissionKindMapper.displayName(for: kind), systemImage: PermissionKindMapper.iconName(for: kind))
                            .font(.system(size: HiveDesign.Typography.sizeMD))
                            .foregroundStyle(HiveDesign.Text.secondary)
                    }
                }
            }

            Spacer()

            Button(action: { state.resolvePermissionPrompt(allow: false) }) {
                Text("Block")
                    .font(.system(size: HiveDesign.Typography.sizeBody, weight: .medium))
                    .padding(.horizontal, HiveDesign.Space.lg)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .keyboardShortcut(.cancelAction)

            Button(action: { state.resolvePermissionPrompt(allow: true) }) {
                Text("Allow")
                    .font(.system(size: HiveDesign.Typography.sizeBody, weight: .semibold))
                    .padding(.horizontal, HiveDesign.Space.xl)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(Color.hiveAccent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, HiveDesign.Space.xl)
        .padding(.vertical, HiveDesign.Space.md)
        .frame(maxWidth: 560)
        .background(HiveDesign.Material.panel)
        .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous)
                .strokeBorder(HiveDesign.Surface.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Permission request from \\(prompt.host)")
        .id(prompt.id)
    }
}
