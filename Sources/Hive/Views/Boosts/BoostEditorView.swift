//
//  BoostEditorView.swift
//  Hive
//
//  A slide‑out panel for creating and editing per‑site Boosts.
//  Users write custom CSS, JavaScript, toggle dark mode, and manage
//  zapped elements — all without leaving the page they're customising.
//

import SwiftUI
import HiveCore

// MARK: - BoostEditorView

struct BoostEditorView: View {
    let boost: Boost?
    let pageURL: URL
    let pageTitle: String

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var css: String
    @State private var js: String
    @State private var forceDarkMode: Bool
    @State private var zappedSelectors: [String]
    @State private var isEnabled: Bool

    private let store = BoostStore.shared
    private var isNew: Bool { boost == nil }

    init(boost: Boost? = nil, pageURL: URL, pageTitle: String) {
        self.boost = boost
        self.pageURL = pageURL
        self.pageTitle = pageTitle
        _name = State(initialValue: boost?.name ?? pageTitle)
        _css = State(initialValue: boost?.css ?? "")
        _js = State(initialValue: boost?.js ?? "")
        _forceDarkMode = State(initialValue: boost?.forceDarkMode ?? false)
        _zappedSelectors = State(initialValue: boost?.zappedSelectors ?? [])
        _isEnabled = State(initialValue: boost?.isEnabled ?? true)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, HiveSpacing.s16)
                .padding(.vertical, HiveSpacing.s8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: HiveSpacing.s16) {
                    // Name
                    VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                        Text("Name").hiveType(.chromeLabel).foregroundStyle(.hiveGraphite)
                        TextField("Boost name", text: $name).textFieldStyle(.roundedBorder)
                    }

                    // URL pattern
                    VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                        Text("URL pattern").hiveType(.chromeLabel).foregroundStyle(.hiveGraphite)
                        HStack {
                            Image(systemName: "link").foregroundStyle(.hiveGraphite)
                            Text((boost?.urlPattern).flatMap { $0.isEmpty ? nil : $0 } ?? hostPattern)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.hiveInk)
                        }
                        .padding(.horizontal, HiveSpacing.s8)
                        .padding(.vertical, HiveSpacing.s4)
                        .background(.hiveMist.opacity(0.3), in: RoundedRectangle(cornerRadius: HiveRadius.r6))
                    }

                    // Toggles
                    VStack(alignment: .leading, spacing: HiveSpacing.s8) {
                        Text("Quick actions").hiveType(.chromeLabel).foregroundStyle(.hiveGraphite)
                        Toggle(isOn: $forceDarkMode) {
                            Label("Force dark mode", systemImage: "moon.fill")
                        }.toggleStyle(.switch)
                        Toggle(isOn: $isEnabled) {
                            Label("Enable this boost", systemImage: "power")
                        }.toggleStyle(.switch)
                    }

                    // Zapped elements
                    if !zappedSelectors.isEmpty {
                        VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                            Text("Zapped elements (\(zappedSelectors.count))")
                                .hiveType(.chromeLabel).foregroundStyle(.hiveGraphite)
                            ForEach(zappedSelectors, id: \.self) { selector in
                                HStack {
                                    Image(systemName: "eye.slash").foregroundStyle(.hiveError)
                                    Text(selector).font(.system(.caption, design: .monospaced)).lineLimit(1)
                                    Spacer()
                                    Button {
                                        zappedSelectors.removeAll { $0 == selector }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(.hiveGraphite)
                                    }.buttonStyle(.plain)
                                }
                                .padding(.horizontal, HiveSpacing.s8)
                                .padding(.vertical, HiveSpacing.s4)
                                .background(.hiveMist.opacity(0.2), in: RoundedRectangle(cornerRadius: HiveRadius.r4))
                            }
                        }
                    }

                    // CSS editor
                    VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                        HStack {
                            Text("Custom CSS").hiveType(.chromeLabel).foregroundStyle(.hiveGraphite)
                            Spacer()
                            Text("\(css.count) chars").font(.caption2).foregroundStyle(.hiveGraphite)
                        }
                        HiveCodeEditor(text: $css)
                            .frame(minHeight: 120)
                            .overlay(RoundedRectangle(cornerRadius: HiveRadius.r6).stroke(.hiveBorder, lineWidth: 1))
                    }

                    // JS editor
                    VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                        HStack {
                            Text("Custom JavaScript").hiveType(.chromeLabel).foregroundStyle(.hiveGraphite)
                            Spacer()
                            Text("\(js.count) chars").font(.caption2).foregroundStyle(.hiveGraphite)
                        }
                        HiveCodeEditor(text: $js)
                            .frame(minHeight: 120)
                            .overlay(RoundedRectangle(cornerRadius: HiveRadius.r6).stroke(.hiveBorder, lineWidth: 1))
                    }
                }
                .padding(HiveSpacing.s16)
            }

            Divider()

            // Footer
            HStack(spacing: HiveSpacing.s8) {
                Button("Cancel") { dismiss() }.buttonStyle(.plain)
                Spacer()
                if !isNew, let existingID = boost?.id {
                    Button("Delete") {
                        store.delete(id: existingID); dismiss()
                    }.buttonStyle(.plain).foregroundStyle(.hiveError)
                }
                Button(isNew ? "Create Boost" : "Save Changes") { save() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, HiveSpacing.s16)
            .padding(.vertical, HiveSpacing.s8)
        }
        .frame(width: 380)
        .background(.hiveBackground)
    }

    private var header: some View {
        HStack(spacing: HiveSpacing.s8) {
            Image(systemName: "paintbrush.pointed.fill").foregroundStyle(.hiveAccent)
            VStack(alignment: .leading, spacing: 1) {
                Text(isNew ? "New Boost" : "Edit Boost")
                    .font(HiveTypography.font(.brandSubtitle))
                Text(pageTitle).font(.caption).foregroundStyle(.hiveGraphite).lineLimit(1)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.hiveGraphite)
            }.buttonStyle(.plain)
        }
    }

    private var hostPattern: String {
        guard let host = pageURL.host else { return "*" }
        let parts = host.split(separator: ".")
        if parts.count > 2 { return "*." + parts.dropFirst().joined(separator: ".") }
        return host
    }

    private func save() {
        let pattern = boost?.urlPattern ?? hostPattern
        if pattern.isEmpty { dismiss(); return }
        let id = boost?.id ?? UUID().uuidString
        let updated = Boost(
            id: id,
            name: name.isEmpty ? pageTitle : name,
            urlPattern: pattern,
            css: css, js: js,
            forceDarkMode: forceDarkMode,
            zappedSelectors: zappedSelectors,
            isEnabled: isEnabled,
            createdAt: boost?.createdAt ?? Date(),
            updatedAt: Date()
        )
        if isNew { store.create(updated) }
        else { store.update(updated) }
        dismiss()
    }
}

// MARK: - HiveCodeEditor

struct HiveCodeEditor: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.hiveInk)
            .scrollContentBackground(.hidden)
            .background(.hiveMist.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r6))
    }
}
