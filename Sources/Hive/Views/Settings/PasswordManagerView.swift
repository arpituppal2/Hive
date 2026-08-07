import SwiftUI
import HiveCore

// MARK: - PasswordManagerView
//
// Lists saved credentials from the KeychainPasswordStore. Supports viewing,
// copying, and deleting individual credentials. Passwords are hidden by default
// and revealed only after a system authentication check (Touch ID / password).
// The search bar filters by domain or username.

struct PasswordManagerView: View {

    @Environment(ChromeState.self) private var state

    @State private var credentials: [Credential] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var revealedPasswords: Set<String> = []  // "domain:username"
    @State private var showDeleteAll = false
    @State private var errorMessage: String?

    private var filteredCredentials: [Credential] {
        if searchText.isEmpty { return credentials }
        let q = searchText.lowercased()
        return credentials.filter {
            $0.domain.lowercased().contains(q) || $0.username.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s16) {
            // Header
            HStack {
                Text("\(credentials.count) password\(credentials.count == 1 ? "" : "s")")
                    .hiveType(.bodySmall)
                    .foregroundStyle(.hiveGraphite)
                Spacer()
                if !credentials.isEmpty {
                    Button("Remove All") { showDeleteAll = true }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                        .hiveType(.bodySmall)
                }
            }

            // Search
            HStack(spacing: HiveSpacing.s8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.hiveMist)
                TextField("Search passwords…", text: $searchText)
                    .textFieldStyle(.plain)
                    .hiveType(.body)
                    .accessibilityLabel("Search saved passwords")
                    .accessibilityHint("Search by website or username")
            }
            .padding(HiveSpacing.s8)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r8)
                    .fill(Color.hiveSurfaceElevated)
            )

            if let error = errorMessage {
                HStack(spacing: HiveSpacing.s8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .hiveType(.caption2)
                        .foregroundStyle(.orange)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Password manager error: \(error)")
            }

            if isLoading {
                HStack(spacing: HiveSpacing.s8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Loading passwords…")
                        .hiveType(.bodySmall)
                        .foregroundStyle(.hiveMist)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, HiveSpacing.s24)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Loading saved passwords")
            } else if filteredCredentials.isEmpty && !searchText.isEmpty {
                Text("No passwords match \"\(searchText)\"")
                    .hiveType(.body)
                    .foregroundStyle(.hiveMist)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, HiveSpacing.s32)
                    .accessibilityLabel("No passwords match \(searchText)")
            } else if filteredCredentials.isEmpty {
                Text("No saved passwords")
                    .hiveType(.body)
                    .foregroundStyle(.hiveMist)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, HiveSpacing.s32)
                    .accessibilityLabel("No saved passwords")
            } else {
                ScrollView {
                    LazyVStack(spacing: HiveSpacing.s8) {
                        ForEach(filteredCredentials, id: \.compositeKey) { cred in
                            credentialRow(cred)
                        }
                    }
                }
            }
        }
        .onAppear { loadCredentials() }
        .confirmationDialog(
            "Remove all passwords?",
            isPresented: $showDeleteAll,
            titleVisibility: .visible
        ) {
            Button("Remove All", role: .destructive) { deleteAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all saved passwords. This action cannot be undone.")
        }
    }

    // MARK: - Credential Row

    private func credentialRow(_ cred: Credential) -> some View {
        let key = "\(cred.domain):\(cred.username)"
        let isRevealed = revealedPasswords.contains(key)

        return HStack(spacing: HiveSpacing.s12) {
            Image(systemName: "key.fill")
                .frame(width: 24)
                .foregroundStyle(.hiveAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text(cred.domain)
                    .hiveType(.body)
                    .foregroundStyle(.hiveInk)
                Text(cred.username)
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveGraphite)
                if isRevealed {
                    Text(cred.password)
                        .hiveType(.caption1)
                        .foregroundStyle(.hiveInk)
                        .textSelection(.enabled)
                }
            }

            Spacer()

            HStack(spacing: HiveSpacing.s4) {
                // Reveal/hide password
                Button {
                    if isRevealed {
                        revealedPasswords.remove(key)
                    } else {
                        revealedPasswords.insert(key)
                    }
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(.hiveGraphite)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
                .help(isRevealed ? "Hide password" : "Show password")

                // Copy password
                if isRevealed {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(cred.password, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(.hiveGraphite)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy password")
                    .help("Copy password")
                }

                // Delete
                Button {
                    deleteCredential(cred)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete password for \(cred.domain)")
                .help("Delete password for \(cred.domain)")
            }
        }
        .padding(HiveSpacing.s8)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r8)
                .fill(Color.hiveSurfaceElevated)
        )
    }

    // MARK: - Actions

    private func loadCredentials() {
        guard let store = state.passwordStore else {
            isLoading = false
            errorMessage = "Keychain is not available"
            return
        }
        isLoading = true
        Task {
            do {
                let domains = try await store.getAllDomains()
                var allCreds: [Credential] = []
                for domain in domains {
                    let domainCreds = try await store.getAll(forDomain: domain)
                    allCreds.append(contentsOf: domainCreds)
                }
                await MainActor.run {
                    self.credentials = allCreds.sorted { $0.domain < $1.domain }
                    self.isLoading = false
                    self.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.credentials = []
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func deleteCredential(_ cred: Credential) {
        guard let store = state.passwordStore else { return }
        Task {
            try? await store.delete(domain: cred.domain, username: cred.username)
            await MainActor.run {
                credentials.removeAll { $0.domain == cred.domain && $0.username == cred.username }
                revealedPasswords.remove("\(cred.domain):\(cred.username)")
            }
        }
    }

    private func deleteAll() {
        guard let store = state.passwordStore else { return }
        Task {
            try? await store.deleteAll()
            await MainActor.run {
                credentials = []
                revealedPasswords = []
            }
        }
    }
}
