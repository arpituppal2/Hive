import SwiftUI

// MARK: - ProfilePalette

/// Colors and icons for the profile picker, matching the workspace palette's
/// breadth. Chrome uses silhouette-style profile avatars; here we use colored
/// circles with an SF Symbol icon layered on top.
enum ProfilePalette {
    static let colors: [String] = [
        "#F97316", "#3B82F6", "#22C55E", "#8B5CF6", "#EC4899",
        "#F5A623", "#10B981", "#E11D48", "#6366F1", "#14B8A6"
    ]

    static let iconNames: [String] = [
        "person.fill", "person.2.fill", "person.3.fill", "person.circle.fill",
        "briefcase.fill", "graduationcap.fill", "heart.fill", "star.fill",
        "bolt.fill", "leaf.fill", "flame.fill", "sparkles",
        "book.fill", "pencil.and.outline", "music.note", "gamecontroller.fill",
        "cart.fill", "airplane", "sun.max.fill", "moon.fill"
    ]

    static func colorName(for hex: String) -> String {
        switch hex.lowercased() {
        case "#f97316": return "Brand"
        case "#3b82f6": return "Blue"
        case "#22c55e": return "Green"
        case "#8b5cf6": return "Purple"
        case "#ec4899": return "Pink"
        case "#f5a623": return "Amber"
        case "#10b981": return "Emerald"
        case "#e11d48": return "Red"
        case "#6366f1": return "Indigo"
        case "#14b8a6": return "Teal"
        default: return "Custom"
        }
    }
}

// MARK: - ProfileManagerPanel

/// Chrome/Safari-class profile manager sheet: see all profiles at a glance,
/// create, rename, recolor, reicon, switch, and delete browsing profiles.
struct ProfileManagerPanel: View {
    @Environment(BrowserState.self) private var state
    @State private var query: String = ""
    @State private var renameTargetID: UUID?
    @State private var renameText: String = ""
    @State private var showNewProfileField: Bool = false
    @State private var newProfileName: String = ""
    @State private var pendingDelete: BrowserState.Profile?

    private var filteredProfiles: [BrowserState.Profile] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return state.profiles }
        return state.profiles.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if filteredProfiles.isEmpty {
                emptyState
            } else {
                profileList
            }
            Divider()
            footer
        }
        .background(HiveDesign.Material.panel)
        .frame(width: 480, height: 420)
        .alert("Rename Profile", isPresented: Binding(
            get: { renameTargetID != nil },
            set: { if !$0 { renameTargetID = nil } }
        )) {
            TextField("Profile name", text: $renameText)
            Button("Rename") { commitRename() }
            Button("Cancel", role: .cancel) { renameTargetID = nil }
        }
        .alert("Delete Profile?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let profile = pendingDelete {
                    state.deleteProfile(id: profile.id)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            if let profile = pendingDelete {
                let count = state.workspaces.filter { $0.profileID == profile.id }.count
                Text("Delete profile \"" + profile.name + "\"? Its " + String(count) + " workspace" + (count == 1 ? "" : "s") + " and their cookies will be permanently removed. This cannot be undone.")
            } else {
                Text("")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.circle")
                .font(HiveDesign.Typography.panelTitleMedium)
                .foregroundStyle(.secondary)

            TextField("Filter profiles...", text: $query)
                .textFieldStyle(.plain)
                .font(HiveDesign.Typography.subHeading)

            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if showNewProfileField {
                TextField("Profile name", text: $newProfileName)
                    .textFieldStyle(.plain)
                    .font(HiveDesign.Typography.smallLabelMedium)
                    .frame(width: 120)
                    .onSubmit { commitNewProfile() }
            }

            Button(action: {
                if showNewProfileField {
                    commitNewProfile()
                } else {
                    showNewProfileField = true
                    newProfileName = ""
                }
            }) {
                Label("New Profile", systemImage: "plus")
                    .font(HiveDesign.Typography.smallLabelBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(HiveDesign.Accent.primary)
                    .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Create a new browsing profile")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - List

    private var profileList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(Array(filteredProfiles.enumerated()), id: \.element.id) { index, profile in
                    ProfileManagerRow(
                        profile: profile,
                        isActive: state.currentProfileID == profile.id,
                        workspaceCount: state.workspaces.filter { $0.profileID == profile.id }.count,
                        onSelect: { state.switchProfile(to: profile.id) },
                        onRename: {
                            renameTargetID = profile.id
                            renameText = profile.name
                        },
                        onRecolor: { hex in state.setProfileColor(id: profile.id, colorHex: hex) },
                        onReicon: { icon in state.setProfileIcon(id: profile.id, iconName: icon) },
                        onDelete: {
                            pendingDelete = profile
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.slash")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No matching profiles")
                .font(HiveDesign.Typography.bodyMedium)
                .foregroundStyle(.secondary)
            Text("Try a different name, or create a new one")
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Text(String(filteredProfiles.count) + " profile" + (filteredProfiles.count == 1 ? "" : "s"))
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Click a row to switch")
                .font(HiveDesign.Typography.buttonCaption)
                .foregroundStyle(.tertiary)
            Button("Done") { state.isProfileManagerPanelOpen = false }
                .font(HiveDesign.Typography.smallLabelBold)
                .buttonStyle(.borderedProminent)
                .tint(HiveDesign.Accent.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func commitRename() {
        guard let id = renameTargetID else { return }
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            state.renameProfile(id: id, name: name)
        }
        renameTargetID = nil
    }

    private func commitNewProfile() {
        let name = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let paletteIndex = state.profiles.count
        let color = ProfilePalette.colors[paletteIndex % ProfilePalette.colors.count]
        let icon = ProfilePalette.iconNames[paletteIndex % ProfilePalette.iconNames.count]
        state.addProfile(name: name.isEmpty ? "New Profile" : name, iconName: icon, colorHex: color)
        showNewProfileField = false
        newProfileName = ""
    }
}

// MARK: - ProfileManagerRow

private struct ProfileManagerRow: View {
    let profile: BrowserState.Profile
    let isActive: Bool
    let workspaceCount: Int
    let onSelect: () -> Void
    let onRename: () -> Void
    let onRecolor: (String) -> Void
    let onReicon: (String) -> Void
    let onDelete: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            // Badge
            ZStack {
                Circle()
                    .fill(profile.swiftUIColor)
                    .frame(width: 34, height: 34)
                Image(systemName: profile.iconName)
                    .font(HiveDesign.Typography.smallLabelBold)
                    .foregroundStyle(.white)
            }
            .shadow(color: isActive ? profile.swiftUIColor.opacity(0.35) : .clear, radius: 3, x: 0, y: 1)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(HiveDesign.Typography.bodyMedium)
                        .foregroundStyle(isActive ? .primary : HiveDesign.Text.secondary)
                    if isActive {
                        Text("ACTIVE")
                            .font(HiveDesign.Typography.microTinyBold)
                            .foregroundStyle(HiveDesign.Accent.primary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(HiveDesign.Accent.muted)
                            .clipShape(Capsule())
                    }
                }
                Text(String(workspaceCount) + " workspace" + (workspaceCount == 1 ? "" : "s"))
                    .font(HiveDesign.Typography.buttonCaption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if isHovered || isActive {
                // Recolor menu
                Menu {
                    ForEach(ProfilePalette.colors, id: \.self) { hex in
                        Button {
                            onRecolor(hex)
                        } label: {
                            Label {
                                Text(ProfilePalette.colorName(for: hex))
                            } icon: {
                                Image(systemName: profile.colorHex.lowercased() == hex.lowercased()
                                      ? "checkmark.circle.fill" : "circle.fill")
                                    .foregroundStyle(Color(hex: hex) ?? .secondary)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "paintpalette")
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton)
                .help("Profile color")

                // Reicon menu
                Menu {
                    ForEach(ProfilePalette.iconNames, id: \.self) { icon in
                        Button {
                            onReicon(icon)
                        } label: {
                            Label {
                                Text(icon.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " ").capitalized)
                            } icon: {
                                Image(systemName: profile.iconName == icon
                                      ? "checkmark.circle.fill" : icon + "")
                                    .foregroundStyle(profile.swiftUIColor)
                                    .frame(width: 20)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton)
                .help("Profile icon")

                Button(action: onRename) {
                    Image(systemName: "pencil")
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Rename")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(.red.opacity(0.8))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Delete profile")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous)
                .fill(isActive ? HiveDesign.Accent.muted : (isHovered ? HiveDesign.Surface.level1 : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous)
                .stroke(isActive ? HiveDesign.Accent.primary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
    }
}