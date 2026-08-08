import SwiftUI
import AppKit

// MARK: - PasswordManagerSheet
//
// Chrome-style password manager. Shows saved credentials with masked passwords,
// search, copy-to-clipboard, and delete. Never shows passwords in clear text.

struct PasswordManagerSheet: View {
    @Environment(BrowserState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var searchText: String = ""
    @State private var addUsername: String = ""
    @State private var addPassword: String = ""
    @State private var addSite: String = ""
    @State private var showAddForm: Bool = false
    @FocusState private var isSearchFocused: Bool

    private var filteredPasswords: [SavedPassword] {
        guard !searchText.isEmpty else { return state.savedPasswords }
        let q = searchText.lowercased()
        return state.savedPasswords.filter {
            $0.site.lowercased().contains(q) ||
            $0.username.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(HiveDesign.Typography.dialogTitle)
                    .foregroundStyle(Color.hiveAccent)

                Text("Passwords")
                    .font(HiveDesign.Typography.subHeadingBold)

                Spacer()

                Text("\(state.savedPasswords.count) saved")
                    .font(HiveDesign.Typography.smallLabelMedium)
                    .foregroundStyle(.secondary)

                Button("Done") { state.isPasswordsManagerOpen = false }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(Color.hiveAccent)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            PanelSearchField(prompt: "Search passwords", text: $searchText, isFocused: $isSearchFocused)

            // Add password toggle
            HStack {
                Spacer()
                Button(action: { withAnimation(reduceMotion ? nil : .spring()) { showAddForm.toggle() } }) {
                    Label(showAddForm ? "Cancel" : "Add Password",
                          systemImage: showAddForm ? "xmark" : "plus")
                        .font(HiveDesign.Typography.sidebarItemMedium)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.hiveAccent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, showAddForm ? 0 : 8)

            if showAddForm {
                addPasswordForm
            }

            // Content
            if state.savedPasswords.isEmpty && !showAddForm {
                emptyState
            } else if !state.savedPasswords.isEmpty && filteredPasswords.isEmpty {
                noResults
            } else if !filteredPasswords.isEmpty {
                List {
                    ForEach(filteredPasswords) { item in
                        PasswordRow(item: item)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .frame(width: 540, height: 460)
        .background(HiveDesign.Material.panel)
        .onAppear { isSearchFocused = true }
    }

    private var addPasswordForm: some View {
        HStack(spacing: 10) {
            TextField("example.com", text: $addSite, prompt: Text("Site"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)
            TextField("user@example.com", text: $addUsername, prompt: Text("Username"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 130)
            SecureField("password", text: $addPassword, prompt: Text("Password"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 130)
            Button("Save") {
                state.savePassword(
                    username: addUsername,
                    password: addPassword,
                    site: addSite)
                addUsername = ""; addPassword = ""; addSite = ""
                showAddForm = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(Color.hiveAccent)
            .disabled(addUsername.isEmpty || addPassword.isEmpty || addSite.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "key.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No saved passwords")
                .font(HiveDesign.Typography.subHeadingSemiBold)
                .foregroundStyle(.secondary)
            Text("Passwords you save will appear here, stored locally.")
                .font(HiveDesign.Typography.sidebarItem).foregroundStyle(.tertiary)
            Spacer()
        }
    }

    private var noResults: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("No passwords matching \"\(searchText)\"")
                .font(HiveDesign.Typography.bodyLarge).foregroundStyle(.secondary)
            Button("Clear search") { searchText = "" }
                .buttonStyle(.borderless).font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(Color.hiveAccent)
            Spacer()
        }
    }
}

// MARK: - PasswordRow

private struct PasswordRow: View {
    let item: SavedPassword
    @Environment(BrowserState.self) private var state
    @State private var isRevealed: Bool = false
    @State private var copied: Bool = false
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(Color.hiveAccent)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.site)
                    .font(HiveDesign.Typography.bodySemiBold)
                    .foregroundStyle(.primary)
                Text(item.username)
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isHovered {
                HStack(spacing: 6) {
                    // Reveal/hide toggle
                    Button(action: { isRevealed.toggle() }) {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .font(HiveDesign.Typography.smallLabel)
                    }
                    .buttonStyle(.plain)
                    .help(isRevealed ? "Hide password" : "Show password")

                    // Copy password
                    Button(action: { copyPassword() }) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(HiveDesign.Typography.smallLabel)
                    }
                    .buttonStyle(.plain)
                    .help("Copy password")
                }
                .padding(.trailing, 4)
            }

            Group {
                if isRevealed {
                    Text(item.password)
                        .font(HiveDesign.Typography.monoSmall)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(String(repeating: "•", count: min(item.password.count, 16)))
                        .font(HiveDesign.Typography.monoSmall)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 120, alignment: .leading)
        }
        .padding(.vertical, 3)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Copy Password") { copyPassword() }
            Button(isRevealed ? "Hide Password" : "Reveal Password") {
                isRevealed.toggle()
            }
            Divider()
            Button("Delete", role: .destructive) { state.deletePassword(id: item.id) }
        }
    }

    private func copyPassword() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.password, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
    }
}
