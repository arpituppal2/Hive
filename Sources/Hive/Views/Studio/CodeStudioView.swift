import SwiftUI
import AppKit

// MARK: - CodeStudioView
//
// A minimal project workspace surface. Lets the user select a project root
// directory, run `swift build`, and see the output. This is the v1 scaffold
// for the Studio mode (STUDIO-001/002) — no code editing yet, just build & see.

struct CodeStudioView: View {

    @Environment(ChromeState.self) private var state

    @State private var projectPath: String = ""
    @State private var buildOutput: String = ""
    @State private var isBuilding = false
    @State private var buildProcess: Process?
    @State private var lastBuildResult: BuildResult = .none
    @State private var buildMode: BuildMode = .build

    private enum BuildResult { case none, success, failure }
    private enum BuildMode: String, CaseIterable { case build, test }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: HiveSpacing.s8) {
                Image(systemName: "hammer")
                    .foregroundStyle(.hiveAccent)
                    .font(HiveTypography.font(.dialogTitle))
                Text("Code Studio")
                    .hiveType(.chromeTitle)
                    .foregroundStyle(.hiveInk)
                Spacer()
                if !projectPath.isEmpty {
                    Text(projectURL?.lastPathComponent ?? projectPath)
                        .hiveType(.chromeLabel)
                        .foregroundStyle(.hiveGraphite)
                }
            }
            .padding(.horizontal, HiveSpacing.s12)
            .padding(.vertical, HiveSpacing.s8)

            Divider().overlay(Color.hiveBorderSubtle)

            if projectPath.isEmpty {
                emptyState
            } else {
                projectContent
            }
        }
        .background(Color.hiveSurfaceElevated)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: HiveSpacing.s16) {
            Image(systemName: "hammer")
                .font(HiveTypography.font(.display2))
                .foregroundStyle(.hiveAccent.opacity(0.5))
            Text("No project selected")
                .hiveType(.body)
                .foregroundStyle(.hiveInk)
            Text("Open a Swift package or Xcode project to build and run from Hive.")
                .hiveType(.caption2)
                .foregroundStyle(.hiveMist)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HiveSpacing.s24)
            Button("Select Project...") { selectProject() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(HiveSpacing.s48)
    }

    // MARK: Project content

    private var projectContent: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: HiveSpacing.s8) {
                Button {
                    selectProject()
                } label: {
                    HStack(spacing: HiveSpacing.s4) {
                        Image(systemName: "folder")
                            .font(HiveTypography.font(.caption2))
                        Text("Change...")
                            .hiveType(.chromeLabel)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.hiveAccent)

                Spacer()

                Picker("Mode", selection: $buildMode) {
                    ForEach(BuildMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 160)
                .disabled(isBuilding)

                Spacer()

                if isBuilding {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                    Button("Stop") {
                        buildProcess?.terminate()
                        buildOutput += "\n$ Build cancelled.\n"
                        lastBuildResult = .failure
                        isBuilding = false
                        buildProcess = nil
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .hiveType(.caption2)
                }

                // Build status badge
                if case .success = lastBuildResult {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(buildMode == .test ? "Tests passed" : "Build passed")
                            .hiveType(.caption2)
                            .foregroundStyle(.green)
                    }
                } else if case .failure = lastBuildResult {
                    HStack(spacing: 2) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(buildMode == .test ? "Tests failed" : "Build failed")
                            .hiveType(.caption2)
                            .foregroundStyle(.red)
                    }
                }

                Button {
                    runBuild()
                } label: {
                    HStack(spacing: HiveSpacing.s4) {
                        Image(systemName: "play.fill")
                            .font(HiveTypography.font(.caption2))
                        Text("Build")
                            .hiveType(.chromeLabel)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isBuilding || projectPath.isEmpty)
            }
            .padding(.horizontal, HiveSpacing.s12)
            .padding(.vertical, HiveSpacing.s8)

            Divider().overlay(Color.hiveBorderSubtle)

            // Path display
            HStack(spacing: HiveSpacing.s4) {
                Image(systemName: "folder.fill")
                    .font(HiveTypography.font(.caption3))
                    .foregroundStyle(.hiveGraphite)
                Text(projectPath)
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveGraphite)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(.horizontal, HiveSpacing.s12)
            .padding(.vertical, HiveSpacing.s4)

            Divider().overlay(Color.hiveBorderSubtle)

            // Build output
            if buildOutput.isEmpty {
                Spacer()
                Text("Press Build to compile the project.")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(buildOutput)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.hiveInk)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(HiveSpacing.s12)
                            .id("outputBottom")
                    }
                    .onChange(of: buildOutput) { _, _ in
                        proxy.scrollTo("outputBottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: Actions

    private var projectURL: URL? {
        guard !projectPath.isEmpty else { return nil }
        return URL(fileURLWithPath: projectPath)
    }

    private func selectProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Project"
        panel.message = "Choose a Swift package or Xcode project directory."

        if panel.runModal() == .OK, let url = panel.url {
            projectPath = url.path
            buildOutput = ""
            lastBuildResult = .none
        }
    }

    private func runBuild() {
        guard let url = projectURL else { return }
        isBuilding = true
        buildOutput = "$ cd \(url.path)\n$ swift \(buildMode.rawValue)\n\n"
        lastBuildResult = .none

        let process = Process()
        buildProcess = process
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", buildMode.rawValue]
        process.currentDirectoryURL = url

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        process.terminationHandler = { proc in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                buildOutput += output
                if proc.terminationStatus != 0 && proc.terminationReason == .exit {
                    buildOutput += "\n$ Exit code: \(proc.terminationStatus)\n"
                }
                lastBuildResult = proc.terminationStatus == 0 ? .success : .failure
                isBuilding = false
                buildProcess = nil
            }
        }

        do {
            try process.run()
        } catch {
            buildOutput += "Error: \(error.localizedDescription)\n"
            lastBuildResult = .failure
            isBuilding = false
        }
    }
}
