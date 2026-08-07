import SwiftUI
import HiveCore

// MARK: - PermissionManagerView
//
// Lists all site permission grants from ChromeUserPrefs.sitePermissions.
// Shows host, permission kind, current state (Allow/Deny/Ask), and allows
// revoking individual grants. Includes a "Reset All" button with confirmation.

struct PermissionManagerView: View {

    @Environment(ChromeState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showResetConfirmation = false
    @State private var selectedFilter: SitePermissionKind?
    @State private var hoveredPermissionID: String?

    private var permissions: [SitePermission] {
        let all = state.prefs.sitePermissions
        if let filter = selectedFilter {
            return all.filter { $0.kind == filter }
        }
        return all
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s16) {
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HiveSpacing.s8) {
                    FilterChip(label: "All", isSelected: selectedFilter == nil) {
                        selectedFilter = nil
                    }
                    ForEach(SitePermissionKind.allCases, id: \.self) { kind in
                        FilterChip(label: kindLabel(kind), isSelected: selectedFilter == kind) {
                            selectedFilter = kind
                        }
                    }
                }
            }

            if permissions.isEmpty {
                VStack(spacing: HiveSpacing.s8) {
                    Image(systemName: "checkmark.shield")
                        .font(HiveTypography.font(.display3))
                        .foregroundStyle(.hiveMist)
                    Text("No site permissions set")
                        .hiveType(.body)
                        .foregroundStyle(.hiveMist)
                    Text("Permissions are created when sites request camera, microphone, or location access.")
                        .hiveType(.caption2)
                        .foregroundStyle(.hiveMist)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, HiveSpacing.s32)
            } else {
                ForEach(permissions) { perm in
                    permissionRow(perm)
                }

                // Reset All
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Label("Reset All Permissions", systemImage: "trash")
                        .hiveType(.bodySmall)
                }
                .padding(.top, HiveSpacing.s8)
                .confirmationDialog(
                    "Reset all site permissions?",
                    isPresented: $showResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Reset All", role: .destructive) {
                        state.prefs.sitePermissions = []
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will clear all Allow and Deny decisions. Sites will ask for permission again on your next visit.")
                }
            }
        }
        .animation(reduceMotion ? nil : .hiveMicro, value: selectedFilter)
    }

    private func permissionRow(_ perm: SitePermission) -> some View {
        let permissionID = String(describing: perm.id)
        return HStack(spacing: HiveSpacing.s12) {
            Image(systemName: iconFor(perm.kind))
                .frame(width: 24)
                .foregroundStyle(.hiveGraphite)

            VStack(alignment: .leading, spacing: 2) {
                Text(perm.host)
                    .hiveType(.body)
                    .foregroundStyle(.hiveInk)
                Text(kindLabel(perm.kind))
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
            }

            Spacer()

            Text(stateLabel(perm.state))
                .hiveType(.bodySmall)
                .foregroundStyle(stateColor(perm.state))
                .padding(.horizontal, HiveSpacing.s8)
                .padding(.vertical, HiveSpacing.s4)
                .background(
                    RoundedRectangle(cornerRadius: HiveRadius.r6)
                        .fill(stateColor(perm.state).opacity(0.12))
                )

            Button {
                state.prefs.sitePermissions.removeAll { $0.id == perm.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.hiveMist)
            }
            .buttonStyle(.plain)
            .help("Revoke permission")
            .accessibilityLabel("Revoke permission")
        }
        .padding(HiveSpacing.s8)
        .contentShape(RoundedRectangle(cornerRadius: HiveRadius.r8))
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r8)
                .fill(hoveredPermissionID == permissionID ? Color.hiveSurface : Color.hiveSurfaceElevated)
        )
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .hiveMicro) {
                hoveredPermissionID = hovering ? permissionID : nil
            }
        }
    }

    private func iconFor(_ kind: SitePermissionKind) -> String {
        switch kind {
        case .camera: return "camera"
        case .microphone: return "mic"
        case .location: return "location"
        case .notifications: return "bell.badge"
        case .popups: return "rectangle.on.rectangle"
        case .automaticDownloads: return "arrow.down.circle"
        }
    }

    private func kindLabel(_ kind: SitePermissionKind) -> String {
        switch kind {
        case .camera: return "Camera"
        case .microphone: return "Microphone"
        case .location: return "Location"
        case .notifications: return "Notifications"
        case .popups: return "Pop-ups"
        case .automaticDownloads: return "Auto Downloads"
        }
    }

    private func stateLabel(_ state: SitePermissionState) -> String {
        switch state {
        case .allow: return "Allowed"
        case .deny: return "Denied"
        case .ask: return "Ask"
        }
    }

    private func stateColor(_ state: SitePermissionState) -> Color {
        switch state {
        case .allow: return .green
        case .deny: return .red
        case .ask: return .hiveGraphite
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .hiveType(.caption2)
                .foregroundStyle(isSelected ? .white : .hiveGraphite)
                .padding(.horizontal, HiveSpacing.s12)
                .padding(.vertical, HiveSpacing.s4)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.hiveAccent : Color.hiveSurface)
                )
        }
        .buttonStyle(.plain)
    }
}
