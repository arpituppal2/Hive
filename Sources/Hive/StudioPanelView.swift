import SwiftUI
import AppKit
import HiveCore

// MARK: - Studio Panel

/// The code studio (STUDIO-002): the demo spine's step 6 surface. Pick a
/// project folder, read a file, edit it, see the live unified diff, and submit
/// the change through the approval center — nothing is written until the user
/// approves the diff. A bounded check runner (same workspace, minimal env,
/// hard timeout) verifies the result.
///
/// This is the first real producer of `PendingAction` through `requestApproval`:
/// the approval panel is no longer dormant.
struct StudioPanel: View {
    @Environment(BrowserState.self) private var state

    @State private var rootPath: String = ""
    @State private var isGitRepo: Bool = false
    @State private var relativePath: String = ""
    @State private var originalContent: String = ""
    @State private var editedContent: String = ""
    @State private var checkCommand: String = "swift test"
    @State private var checkOutput: String = ""
    @State private var isChecking: Bool = false
    @State private var statusMessage: String?
    @State private var statusIsError: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            rootSection
            Divider()
            editorSection
            if state.lastAppliedEdit != nil {
                Divider()
                rollbackSection
            }
            Divider()
            checkSection
        }
        .frame(width: 560, height: 620)
        .background(HiveDesign.Material.panel)
        .task { await refreshWorkspace() }
        // When the approval panel closes, re-read the open file: if the change
        // was approved the workspace applied it, so the editor must reflect the
        // on-disk state (and confirm it); if denied or X-dismissed, re-reading
        // shows the unchanged original — either way the panel can't lie.
        .onChange(of: state.isApprovalPanelOpen) { _, isOpen in
            if !isOpen, !relativePath.trimmingCharacters(in: .whitespaces).isEmpty, !originalContent.isEmpty {
                Task { await refreshAfterApproval() }
            }
        }
        // SWARM-004 wiring: the check now runs through the approval center.
        // Observe the state-published outcome (approved run, failing run,
        // or policy denial) and render it in the panel's status line.
        .onChange(of: state.studioCheckResult) { _, result in
            if let result {
                checkOutput = result
                statusMessage = nil
                statusIsError = false
                isChecking = false
            }
        }
        .onChange(of: state.studioCheckError) { _, error in
            if let error {
                statusMessage = error
                statusIsError = true
                isChecking = false
            }
        }
        .onChange(of: state.lastPolicyDenial) { _, denial in
            if let denial {
                statusMessage = denial
                statusIsError = true
                isChecking = false
            }
        }
        // When rollback fires, re-read the open file so the editor reflects
        // the restored content (git restore or .hivebak restore).
        .onChange(of: state.lastAppliedEdit) { _, edit in
            if edit == nil, !relativePath.trimmingCharacters(in: .whitespaces).isEmpty {
                Task { await loadFile() }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(HiveDesign.Typography.bodySemiBold)
                .foregroundStyle(HiveDesign.Accent.primary)
            Text("Studio")
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(HiveDesign.Text.primary)
            Spacer()
            if isGitRepo {
                Text("git")
                    .font(HiveDesign.Typography.microLabelBold)
                    .foregroundStyle(HiveDesign.Accent.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(HiveDesign.Accent.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .accessibilityLabel("Git repository")
            }
            Button(action: { state.toggleStudioPanel() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(HiveDesign.Typography.bodyLarge)
                    .foregroundStyle(HiveDesign.Text.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Studio")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Root Section

    private var rootSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(HiveDesign.Text.tertiary)
                Text(rootPath.isEmpty ? "No project folder selected" : rootPath)
                    .font(HiveDesign.Typography.monoSmall)
                    .foregroundStyle(rootPath.isEmpty ? HiveDesign.Text.tertiary : HiveDesign.Text.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(rootPath.isEmpty ? "Choose Folder…" : "Change…") { pickFolder() }
                    .font(HiveDesign.Typography.sectionHeader)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel(rootPath.isEmpty ? "Choose project folder" : "Change project folder")
            }

            if rootPath.isEmpty {
                Text("Pick a project folder to read, edit, and run checks inside it. All file access stays within this folder.")
                    .font(HiveDesign.Typography.caption)
                    .foregroundStyle(HiveDesign.Text.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Editor Section

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("relative/path.swift", text: $relativePath)
                    .textFieldStyle(.plain)
                    .font(HiveDesign.Typography.monoSmall)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(HiveDesign.Surface.level1)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .disabled(rootPath.isEmpty)
                    .onSubmit { Task { await loadFile() } }
                Button("Open") { Task { await loadFile() } }
                    .font(HiveDesign.Typography.sectionHeader)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(rootPath.isEmpty || relativePath.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Open file for editing")
            }

            if !originalContent.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(HiveDesign.Accent.primary)
                    Text(relativePath)
                        .font(HiveDesign.Typography.monoCaptionMedium)
                        .foregroundStyle(HiveDesign.Text.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(editedContent.count) chars")
                        .font(HiveDesign.Typography.monoMicroMedium)
                        .foregroundStyle(HiveDesign.Text.tertiary)
                }

                TextEditor(text: $editedContent)
                    .font(HiveDesign.Typography.monoSmall)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .background(HiveDesign.Surface.level1)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                diffPreview

                Button(action: proposeChange) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield")
                            .font(HiveDesign.Typography.sectionHeader)
                        Text("Review Change…")
                            .font(HiveDesign.Typography.sidebarItemSemiBold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(HiveDesign.Accent.primary)
                .disabled(editedContent == originalContent)
                .help("Shows the diff for approval — nothing is written until you approve")
                .accessibilityLabel("Review change for approval")
            } else {
                Text("Open a file to edit it. The diff preview and approval flow appear here.")
                    .font(HiveDesign.Typography.caption)
                    .foregroundStyle(HiveDesign.Text.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 30)
            }

            if let message = statusMessage {
                Text(message)
                    .font(HiveDesign.Typography.caption)
                    .foregroundStyle(statusIsError ? .red : HiveDesign.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Diff Preview

    private var diffPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Diff preview", systemImage: "text.alignleft")
                .font(HiveDesign.Typography.microLabelBold)
                .foregroundStyle(HiveDesign.Text.tertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                Text(StudioWorkspace.unifiedDiff(original: originalContent, new: editedContent, path: relativePath))
                    .font(HiveDesign.Typography.monoCaption)
                    .foregroundStyle(HiveDesign.Text.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: 110)
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Rollback Section

    /// After a studio edit is approved and applied, offer a one-click undo.
    /// For git repos this uses `git restore` (the strongest contract — reverts
    /// to the last committed state); for non-git workspaces it restores the
    /// automatic .hivebak backup. Either way, nothing happens without the
    /// user clicking the explicit Undo button.
    private var rollbackSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let edit = state.lastAppliedEdit {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundStyle(.green)
                    Text("Change applied to \(edit.relativePath)")
                        .font(HiveDesign.Typography.monoCaptionMedium)
                        .foregroundStyle(HiveDesign.Text.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button(action: { Task { await state.rollbackLastEdit() } }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(HiveDesign.Typography.microLabelBold)
                            Text("Undo")
                                .font(HiveDesign.Typography.captionSemiBold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(isGitRepo ? HiveDesign.Accent.primary : .orange)
                    .help(isGitRepo
                        ? "Reverts this file with git restore — returns to the last committed state"
                        : "Restores the automatic backup — undoes only this edit")
                    .accessibilityLabel(isGitRepo ? "Undo — git restore \(edit.relativePath)" : "Undo — restore backup of \(edit.relativePath)")
                }
                if isGitRepo {
                    Text("git restore \(edit.relativePath)")
                        .font(HiveDesign.Typography.monoMicro)
                        .foregroundStyle(HiveDesign.Text.tertiary)
                } else {
                    Text("Rolling back restores .hivebak backup")
                        .font(HiveDesign.Typography.microLabelSecondary)
                        .foregroundStyle(HiveDesign.Text.tertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Check Section

    private var checkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(HiveDesign.Text.tertiary)
                TextField("Check command (e.g. swift test)", text: $checkCommand)
                    .textFieldStyle(.plain)
                    .font(HiveDesign.Typography.monoSmall)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(HiveDesign.Surface.level1)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .disabled(rootPath.isEmpty)
                    .onSubmit { Task { await runCheck() } }
                Button(action: { Task { await runCheck() } }) {
                    if isChecking {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "play.fill")
                            .font(HiveDesign.Typography.microLabelBold)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(rootPath.isEmpty || isChecking)
                .help("Runs in the project folder with a minimal environment and a 60s timeout")
                .accessibilityLabel("Run check")
            }
            if !checkOutput.isEmpty {
                ScrollView {
                    Text(checkOutput)
                        .font(HiveDesign.Typography.monoCaption)
                        .foregroundStyle(HiveDesign.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, maxHeight: 80)
                .padding(8)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Actions

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Project Folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            await state.studioWorkspace.selectRoot(url)
            await refreshWorkspace()
        }
    }

    private func refreshWorkspace() async {
        let root = await state.studioWorkspace.rootURL?.path ?? ""
        let git = await state.studioWorkspace.isGitRepository()
        await MainActor.run {
            rootPath = root
            isGitRepo = git
            statusMessage = nil
        }
    }

    private func loadFile() async {
        let path = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }
        await MainActor.run {
            statusMessage = nil
            statusIsError = false
        }
        do {
            let content = try await state.studioWorkspace.readFile(path)
            await MainActor.run {
                originalContent = content
                editedContent = content
            }
        } catch {
            await MainActor.run {
                originalContent = ""
                editedContent = ""
                statusMessage = (error as? StudioWorkspace.StudioError)?.errorDescription ?? error.localizedDescription
                statusIsError = true
            }
        }
    }

    /// Re-reads the open file after an approval decision lands. If the content
    /// changed on disk the change was applied — surface that honestly.
    private func refreshAfterApproval() async {
        let path = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let content = try? await state.studioWorkspace.readFile(path) else { return }
        await MainActor.run {
            let changed = content != originalContent
            originalContent = content
            editedContent = content
            statusMessage = changed ? "✓ Change applied to \(path)" : nil
            statusIsError = false
        }
    }

    private func proposeChange() {
        let path = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }
        // The diff IS the consent prompt — the approval panel renders it.
        Task {
            await state.proposeCodeEdit(
                relativePath: path,
                originalContent: originalContent,
                newContent: editedContent
            )
        }
    }

    private func runCheck() async {
        let command = checkCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        // SWARM-004: the check now routes through the approval center — the
        // policy engine validates the command (destructive deny-list) before
        // the user approves it. The raw bounded-workspace call no longer
        // happens here; the approved execution runs in
        // BrowserState.performExecution and publishes the output.
        isChecking = true
        checkOutput = ""
        statusMessage = "Waiting for approval…"
        statusIsError = false
        await state.proposeRunCheck(command: command)
    }
}
