import SwiftUI
import AppKit
import HiveCore

// MARK: - SpaceBarView (horizontal)
//
// A compact, horizontally-scrolling strip of workspace pills shown in top-tabs layout.
// Renders every Space in `ChromeState.spaces`, highlights the active one, and lets the user
// switch spaces with a tap. A trailing "+" creates a new space.

struct SpaceBarView: View {
    @Environment(ChromeState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Tracks which space pill is hovered for hover micro-interactions.
    @State private var hoveredSpaceID: String? = nil

    var body: some View {
        HStack(spacing: HiveSpacing.s8) {
            ForEach(state.spaces) { space in
                spacePill(space)
            }
            newSpaceButton
            Spacer(minLength: 0)
        }
        .padding(.horizontal, HiveSpacing.s8)
        .padding(.vertical, HiveSpacing.s4)
        .frame(height: 28)
        .hiveSurface(.passiveChrome)
    }

    private func spacePill(_ space: Space) -> some View {
        let isActive = space.id == state.activeSpace.id
        let accent = Color(HiveColorToken(rawValue: space.accentTokenName) ?? .accent)
        let pillHovered = hoveredSpaceID == space.id
        return Button {
            withAnimation(reduceMotion ? .none : .hiveExpand) {
                state.switchSpace(to: space.id)
            }
        } label: {
            HStack(spacing: HiveSpacing.s4) {
                Image(systemName: space.iconName)
                    .font(HiveTypography.font(.caption3Semibold))
                    .foregroundStyle(isActive ? accent : Color.hiveGraphite)
                Text(space.name)
                    .hiveType(.chromeLabel)
                    .lineLimit(1)
                    .foregroundStyle(isActive ? Color.hiveInk : Color.hiveGraphite)
            }
            .padding(.horizontal, HiveSpacing.s8)
            .padding(.vertical, HiveSpacing.s4)
            .background(
                Capsule()
                    .fill(isActive ? Color.hiveSurface : (pillHovered ? Color.hiveSurface.opacity(0.4) : Color.clear))
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? accent.opacity(0.3) : (pillHovered ? Color.hiveBorderSubtle : Color.clear), lineWidth: 1)
            )
            .scaleEffect(pillHovered ? 1.03 : 1.0)
            .animation(reduceMotion ? .linear(duration: 0.12) : .easeOut(duration: 0.15), value: pillHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredSpaceID = hovering ? space.id : nil
        }
        .accessibilityLabel("Space: \(space.name)")
        .contextMenu { spaceContextMenu(for: space) }
    }

    @State private var newButtonHovered = false

    private var newSpaceButton: some View {
        Button {
            state.newSpace()
        } label: {
            Image(systemName: "plus")
                .font(HiveTypography.font(.captionMedium))
                .foregroundStyle(newButtonHovered ? state.activeAccentColor : Color.hiveGraphite)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(newButtonHovered ? state.activeAccentColor.opacity(0.12) : Color.hiveSurface)
                )
                .scaleEffect(newButtonHovered ? 1.10 : 1.0)
                .animation(reduceMotion ? .linear(duration: 0.12) : .easeOut(duration: 0.15), value: newButtonHovered)
        }
        .buttonStyle(.plain)
        .onHover { newButtonHovered = $0 }
        .accessibilityLabel("New space")
    }

    @ViewBuilder
    private func spaceContextMenu(for space: Space) -> some View {
        Button("Rename Space…") {
            state.renameSpace(space.id, to: promptForSpaceName(space.name) ?? space.name)
        }
        SpaceAccentPicker(space: space, state: state)
        SpaceIconPicker(space: space, state: state)
        Divider()
        if state.spaces.count > 1 {
            Button("Delete Space", role: .destructive) {
                state.deleteSpace(space.id)
            }
        }
    }
}
