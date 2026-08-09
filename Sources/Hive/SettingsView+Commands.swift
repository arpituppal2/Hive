//
//  SettingsView+Commands.swift
//  Hive
//
//  Carved out of SettingsView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Custom Commands
//

import SwiftUI
import AppKit
import HiveCore

// MARK: - SettingsView + Commands

@MainActor
extension SettingsView {


    // MARK: - Custom Commands

    var commandsTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsGroup("Custom launcher entries") {
                Text("Create focused ⌘K commands for pages you open often. Commands only open http:// or https:// URLs and never execute shell or app actions.")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    TextField("Command title", text: $commandTitle)
                        .textFieldStyle(.roundedBorder)
                    TextField("https://example.com", text: $commandURL)
                        .textFieldStyle(.roundedBorder)
                        .font(HiveDesign.Typography.monoMedium)
                    HStack(spacing: 8) {
                        TextField("Icon (SF Symbol)", text: $commandIcon)
                            .textFieldStyle(.roundedBorder)
                        TextField("Keywords, comma separated", text: $commandKeywords)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        if let commandError {
                            Label(commandError, systemImage: "exclamationmark.triangle")
                                .font(HiveDesign.Typography.smallLabel)
                                .foregroundStyle(.orange)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button("Add Command") { addCommand() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(commandTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || commandURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }

            settingsGroup("Saved commands") {
                if state.userDefinedCommands.isEmpty {
                    Text("No custom commands yet.")
                        .font(HiveDesign.Typography.sidebarItem)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 6) {
                        ForEach(state.userDefinedCommands) { command in
                            HStack(spacing: 8) {
                                Image(systemName: command.icon)
                                    .foregroundStyle(Color.hiveAccent)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(command.title)
                                        .font(HiveDesign.Typography.sidebarItemMedium)
                                    Text(command.url)
                                        .font(HiveDesign.Typography.monoCaption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button("Delete", role: .destructive) {
                                    state.removeUserDefinedCommand(id: command.id)
                                }
                                .buttonStyle(.borderless)
                                .font(HiveDesign.Typography.smallLabel)
                                .help("Delete \(command.title)")
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }


    func addCommand() {
        let title = commandTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = commandURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let keywords = commandKeywords
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let command = UserDefinedCommand(title: title, url: url, icon: commandIcon, keywords: keywords)
        guard command.isValidWebURL else {
            commandError = "Enter a valid http:// or https:// URL without credentials."
            return
        }
        guard state.addUserDefinedCommand(command) else {
            commandError = "That command could not be saved."
            return
        }
        commandTitle = ""
        commandURL = ""
        commandIcon = "link"
        commandKeywords = ""
        commandError = nil
    }


    func searchEngineDescription(for engine: BrowserState.SearchEngine) -> String {
        switch engine {
        case .duckduckgo: return "Private search, no tracking"
        case .google: return "Fast, comprehensive results"
        case .bing: return "Microsoft's search engine with AI features"
        }
    }
}
