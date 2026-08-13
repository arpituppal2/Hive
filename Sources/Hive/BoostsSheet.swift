import SwiftUI
import AppKit
import HiveCore

// MARK: - BoostsSheet
//
// Arc-style site Boosts manager: list user-authored per-host CSS, toggle,
// edit, and delete. "New Boost" opens the editor; the page context menu's
// "Boost This Site…" action pre-fills the host via `pendingBoostHost`.

struct BoostsSheet: View {
    @Environment(BrowserState.self) private var state
    @State private var editorPresented: Bool = false
    @State private var editingBoost: Boost? = nil
    @State private var editorPrefillHost: String = ""
    @State private var didConsumePendingHost: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if state.boosts.isEmpty { emptyState } else { boostList }
        }
        .frame(width: 580, height: 420)
        .background(HiveDesign.Material.panel)
        .onAppear { consumePendingHost() }
        .sheet(isPresented: $editorPresented) {
            BoostEditorSheet(
                isPresented: $editorPresented,
                existing: editingBoost,
                prefillHost: editorPrefillHost
            )
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(HiveDesign.Typography.dialogTitle)
                .foregroundStyle(Color.hiveAccent)

            Text("Boosts")
                .font(HiveDesign.Typography.subHeadingBold)

            Spacer()

            Text("\(state.boosts.count) boost\(state.boosts.count == 1 ? "" : "s")")
                .font(HiveDesign.Typography.smallLabelMedium)
                .foregroundStyle(.secondary)

            Button("New Boost") { beginEditor(with: nil, prefillHost: "") }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Create a new site boost")

            Button("Done") { state.isBoostsPanelOpen = false }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color.hiveAccent)
                .accessibilityLabel("Close boosts manager")
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var boostList: some View {
        List {
            ForEach(state.boosts) { boost in
                BoostRow(boost: boost) { onEdit(boost) }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wand.and.stars")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No boosts yet")
                .font(HiveDesign.Typography.subHeadingSemiBold)
                .foregroundStyle(.secondary)
            Text("Boost a site with your own CSS — right-click any page and choose \"Boost This Site…\".")
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Spacer()
        }
    }

    // MARK: - Flow

    private func onEdit(_ boost: Boost) {
        beginEditor(with: boost, prefillHost: "")
    }

    private func beginEditor(with boost: Boost?, prefillHost: String) {
        editingBoost = boost
        editorPrefillHost = prefillHost
        editorPresented = true
    }

    /// The page context menu sets `pendingBoostHost` before opening this
    /// sheet; consume it exactly once to pre-fill the editor.
    private func consumePendingHost() {
        guard !didConsumePendingHost, let host = state.pendingBoostHost else { return }
        didConsumePendingHost = true
        state.pendingBoostHost = nil
        beginEditor(with: nil, prefillHost: host)
    }
}

// MARK: - BoostRow

private struct BoostRow: View {
    let boost: Boost
    let onEdit: () -> Void
    @Environment(BrowserState.self) private var state
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { boost.isEnabled },
                set: { _ in state.toggleBoostEnabled(id: boost.id) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .accessibilityLabel(boost.isEnabled ? "Disable boost for \(boost.host)" : "Enable boost for \(boost.host)")

            VStack(alignment: .leading, spacing: 2) {
                Text(boost.name)
                    .font(HiveDesign.Typography.bodyMedium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(boost.host) · \(boost.css.count) characters of CSS")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Edit boost")
                .accessibilityLabel("Edit boost for \(boost.host)")

                Button(role: .destructive) { state.deleteBoost(id: boost.id) } label: {
                    Image(systemName: "trash")
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete boost")
                .accessibilityLabel("Delete boost for \(boost.host)")
            }
        }
        .padding(.vertical, 4)
        .onHover { isHovered = $0 }
    }
}

// MARK: - BoostEditorSheet

private struct BoostEditorSheet: View {
    @Environment(BrowserState.self) private var state
    @Binding var isPresented: Bool
    let existing: Boost?
    let prefillHost: String

    @State private var host: String
    @State private var name: String
    @State private var css: String
    @State private var errorMessage: String?

    init(isPresented: Binding<Bool>, existing: Boost?, prefillHost: String) {
        _isPresented = isPresented
        self.existing = existing
        self.prefillHost = prefillHost
        _host = State(initialValue: existing?.host ?? prefillHost)
        _name = State(initialValue: existing?.name ?? "")
        _css = State(initialValue: existing?.css ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(existing == nil ? "New Boost" : "Edit Boost")
                    .font(HiveDesign.Typography.subHeadingBold)
                Spacer()
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Cancel boost editor")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Host")
                        .font(HiveDesign.Typography.smallLabelBold)
                        .foregroundStyle(.secondary)
                    TextField("example.com or .example.com", text: $host)
                        .textFieldStyle(.roundedBorder)
                        .font(HiveDesign.Typography.bodyMedium)
                    Text("A leading dot (.example.com) also styles subdomains.")
                        .font(HiveDesign.Typography.microLabel)
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(HiveDesign.Typography.smallLabelBold)
                        .foregroundStyle(.secondary)
                    TextField("e.g. Dark news", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(HiveDesign.Typography.bodyMedium)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("CSS")
                        .font(HiveDesign.Typography.smallLabelBold)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $css)
                        .font(.system(size: 12, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(HiveDesign.Surface.level2, in: RoundedRectangle(cornerRadius: HiveDesign.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: HiveDesign.Radius.md, style: .continuous)
                                .stroke(HiveDesign.Surface.hairline, lineWidth: 1)
                        )
                        .frame(height: 180)
                    Text("Applied after page load. No scripts, no page content is read.")
                        .font(HiveDesign.Typography.microLabel)
                        .foregroundStyle(.tertiary)
                }

                if let errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(HiveDesign.Typography.microLabel)
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.borderless)
                Button(existing == nil ? "Create Boost" : "Save Changes") { save() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.hiveAccent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 540, height: 470)
        .background(HiveDesign.Material.panel)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if var edited = existing {
            edited.host = host
            edited.name = trimmedName.isEmpty ? host : trimmedName
            edited.css = css
            guard edited.hasValidHost, edited.hasUsableCSS else {
                errorMessage = "Enter a valid host and at least one CSS rule."
                return
            }
            state.updateBoost(edited)
        } else {
            guard state.addBoost(host: host, name: name, css: css) != nil else {
                errorMessage = "Enter a valid host and at least one CSS rule."
                return
            }
        }
        isPresented = false
    }
}
