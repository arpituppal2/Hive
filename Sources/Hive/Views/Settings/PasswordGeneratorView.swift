import SwiftUI
import Security
import HiveCore

// MARK: - PasswordGeneratorView
//
// Generates strong, cryptographically random passwords. The user can configure
// length (8–64 chars) and toggle character classes (uppercase, lowercase,
// digits, symbols). Generated passwords are copied to the clipboard and can be
// saved to the Keychain for a specified domain.
//
// The generator uses SecRandomCopyBytes for entropy — not arc4random or any
// predictable PRNG.

struct PasswordGeneratorView: View {

    @Environment(ChromeState.self) private var state

    @State private var passwordLength: Double = 20
    @State private var useUppercase: Bool = true
    @State private var useLowercase: Bool = true
    @State private var useDigits: Bool = true
    @State private var useSymbols: Bool = true
    @State private var generatedPassword: String = ""
    @State private var showCopiedToast: Bool = false
    @State private var saveDomain: String = ""
    @State private var saveUsername: String = ""
    @State private var showSaveSheet: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s24) {
            // Generated password display
            passwordDisplay

            // Configuration
            configurationSection

            // Actions
            actionButtons

            // Save to Keychain
            if !generatedPassword.isEmpty {
                saveSection
            }
        }
        .onAppear { regenerate() }
        .sheet(isPresented: $showSaveSheet) {
            savePasswordSheet
        }
    }

    // MARK: - Password Display

    private var passwordDisplay: some View {
        VStack(spacing: HiveSpacing.s12) {
            HStack(spacing: HiveSpacing.s12) {
                Text(generatedPassword.isEmpty ? "Tap Generate" : generatedPassword)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.hiveInk)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer()

                HStack(spacing: HiveSpacing.s8) {
                    Button {
                        copyPassword()
                    } label: {
                        Image(systemName: showCopiedToast ? "checkmark" : "doc.on.doc")
                            .font(HiveTypography.font(.bodyMedium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(showCopiedToast ? .green : .hiveGraphite)
                    .help("Copy password")

                    Button {
                        regenerate()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(HiveTypography.font(.bodyMedium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.hiveAccent)
                    .help("Generate new password")
                }
            }
            .padding(HiveSpacing.s16)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r12)
                    .fill(Color.hiveSurfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HiveRadius.r12)
                    .stroke(Color.hiveAccent.opacity(0.3), lineWidth: 1)
            )

            // Strength indicator
            strengthIndicator
        }
    }

    private var strengthIndicator: some View {
        let strength = passwordStrength(generatedPassword)

        return VStack(alignment: .leading, spacing: HiveSpacing.s4) {
            HStack(spacing: HiveSpacing.s4) {
                ForEach(0..<4) { i in
                    RoundedRectangle(cornerRadius: HiveRadius.r2)
                        .fill(i < strength.bars ? strength.color : Color.hiveBorderSubtle)
                        .frame(height: 4)
                }
            }
            Text(strength.label)
                .hiveType(.caption2)
                .foregroundStyle(strength.color)
        }
    }

    // MARK: - Configuration

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s16) {
            Text("Configuration")
                .hiveType(.chromeTitle)
                .foregroundStyle(.hiveInk)

            // Length slider
            VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                HStack {
                    Text("Length")
                        .hiveType(.bodySmall)
                        .foregroundStyle(.hiveGraphite)
                    Spacer()
                    Text("\(Int(passwordLength)) characters")
                        .hiveType(.bodySmall)
                        .monospacedDigit()
                        .foregroundStyle(.hiveAccent)
                }
                Slider(value: $passwordLength, in: 8...64, step: 1)
                    .tint(.hiveAccent)
            }

            // Character class toggles
            VStack(spacing: HiveSpacing.s8) {
                charToggle("A–Z", "Uppercase letters", isOn: $useUppercase)
                charToggle("a–z", "Lowercase letters", isOn: $useLowercase)
                charToggle("0–9", "Digits", isOn: $useDigits)
                charToggle("!@#$", "Special characters", isOn: $useSymbols)
            }
        }
    }

    private func charToggle(_ chars: String, _ label: String, isOn: Binding<Bool>) -> some View {
        let canDisable = (useUppercase ? 1 : 0) + (useLowercase ? 1 : 0) + (useDigits ? 1 : 0) + (useSymbols ? 1 : 0) > 1
        return HStack(spacing: HiveSpacing.s12) {
            Text(chars)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.hiveAccent)
                .frame(width: 36, alignment: .leading)
            Text(label)
                .hiveType(.bodySmall)
                .foregroundStyle(.hiveInk)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .disabled(!canDisable && isOn.wrappedValue)
        }
    }

    // MARK: - Copy toast

    private func copyPassword() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(generatedPassword, forType: .string)
        showCopiedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedToast = false
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: HiveSpacing.s12) {
            Button {
                regenerate()
            } label: {
                Label("Regenerate", systemImage: "arrow.clockwise")
                    .hiveType(.body)
            }
            .buttonStyle(.bordered)
            .tint(.hiveAccent)

            Button {
                showSaveSheet = true
            } label: {
                Label("Save to Keychain", systemImage: "key")
                    .hiveType(.body)
            }
            .buttonStyle(.bordered)
            .tint(.hiveGraphite)
            .disabled(generatedPassword.isEmpty)
        }
    }

    // MARK: - Save Section

    private var saveSection: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s8) {
            Text("Save this password for a website")
                .hiveType(.caption2)
                .foregroundStyle(.hiveMist)

            HStack(spacing: HiveSpacing.s8) {
                TextField("domain.com", text: $saveDomain)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                TextField("username", text: $saveUsername)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)

                Button("Save") {
                    saveToKeychain()
                }
                .buttonStyle(.borderedProminent)
                .tint(.hiveAccent)
                .disabled(saveDomain.isEmpty || saveUsername.isEmpty)
            }
        }
        .padding(HiveSpacing.s12)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r8)
                .fill(Color.hiveSurfaceElevated)
        )
    }

    private var savePasswordSheet: some View {
        VStack(spacing: HiveSpacing.s16) {
            Text("Save Password")
                .hiveType(.chromeTitle)

            TextField("Website (e.g. github.com)", text: $saveDomain)
                .textFieldStyle(.roundedBorder)
            TextField("Username or email", text: $saveUsername)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { showSaveSheet = false }
                    .buttonStyle(.bordered)
                Button("Save to Keychain") {
                    saveToKeychain()
                    showSaveSheet = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.hiveAccent)
                .disabled(saveDomain.isEmpty || saveUsername.isEmpty)
            }
        }
        .padding(HiveSpacing.s24)
        .frame(width: 360)
    }

    // MARK: - Generation

    private func regenerate() {
        guard useUppercase || useLowercase || useDigits || useSymbols else {
            generatedPassword = ""
            return
        }

        var charset = ""
        if useUppercase { charset += "ABCDEFGHIJKLMNOPQRSTUVWXYZ" }
        if useLowercase { charset += "abcdefghijklmnopqrstuvwxyz" }
        if useDigits    { charset += "0123456789" }
        if useSymbols   { charset += "!@#$%^&*()_+-=[]{}|;:,.<>?" }

        let length = Int(passwordLength)
        var password = ""
        let chars = Array(charset)

        // Use SecRandomCopyBytes for cryptographically secure random bytes
        var randomBytes = [UInt8](repeating: 0, count: length)
        let result = SecRandomCopyBytes(kSecRandomDefault, length, &randomBytes)
        if result == errSecSuccess {
            for byte in randomBytes {
                password.append(chars[Int(byte) % chars.count])
            }
        } else {
            // Fallback: use system random
            for _ in 0..<length {
                password.append(chars[Int.random(in: 0..<chars.count)])
            }
        }

        // Ensure at least one char from each enabled class
        if useUppercase, !password.contains(where: { "ABCDEFGHIJKLMNOPQRSTUVWXYZ".contains($0) }) {
            password = "A" + password.dropLast()
        }
        if useLowercase, !password.contains(where: { "abcdefghijklmnopqrstuvwxyz".contains($0) }) {
            password = "a" + password.dropLast()
        }
        if useDigits, !password.contains(where: { "0123456789".contains($0) }) {
            password = "1" + password.dropLast()
        }

        generatedPassword = password
    }

    private func saveToKeychain() {
        guard !saveDomain.isEmpty, !saveUsername.isEmpty, !generatedPassword.isEmpty else { return }
        guard let store = state.passwordStore else { return }

        let cred = Credential(domain: saveDomain, username: saveUsername, password: generatedPassword)
        Task {
            try? await store.save(cred)
            await MainActor.run {
                saveDomain = ""
                saveUsername = ""
            }
        }
    }

    // MARK: - Strength

    private func passwordStrength(_ password: String) -> (bars: Int, label: String, color: Color) {
        guard !password.isEmpty else { return (0, "No password", .hiveMist) }

        var score = 0
        if password.count >= 12 { score += 1 }
        if password.count >= 20 { score += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) != nil { score += 1 }

        switch score {
        case 0...1: return (1, "Weak — easy to guess", .red)
        case 2:     return (2, "Fair — could be stronger", .orange)
        case 3:     return (3, "Strong — good protection", .yellow)
        default:    return (4, "Very strong — excellent", .green)
        }
    }
}
