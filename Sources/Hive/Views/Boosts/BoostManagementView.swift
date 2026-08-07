//
//  BoostManagementView.swift
//  Hive
//
//  A library view listing every installed Boost. Users can toggle,
//  edit, or delete boosts from here.
//

import SwiftUI
import HiveCore

struct BoostManagementView: View {
    @State private var boosts: [Boost] = []
    @State private var selectedBoost: Boost? = nil
    @State private var showEditor = false
    @State private var searchText = ""

    private let store = BoostStore.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: HiveSpacing.s8) {
                Image(systemName: "paintbrush.pointed.fill").foregroundStyle(.hiveAccent)
                Text("Boosts").font(HiveTypography.font(.brandSubtitle))
                Spacer()
                Text("\(boosts.count) boost\(boosts.count == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.hiveGraphite)
            }
            .padding(.horizontal, HiveSpacing.s16)
            .padding(.vertical, HiveSpacing.s8)

            // Search
            HStack(spacing: HiveSpacing.s4) {
                Image(systemName: "magnifyingglass").foregroundStyle(.hiveGraphite)
                TextField("Search boosts...", text: $searchText).textFieldStyle(.plain)
            }
            .padding(.horizontal, HiveSpacing.s8)
            .padding(.vertical, HiveSpacing.s4)
            .background(.hiveMist.opacity(0.3), in: RoundedRectangle(cornerRadius: HiveRadius.r8))
            .padding(.horizontal, HiveSpacing.s16)
            .padding(.bottom, HiveSpacing.s8)

            Divider()

            if boosts.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: HiveSpacing.s4) {
                        ForEach(filteredBoosts) { boost in
                            boostRow(boost)
                        }
                    }
                    .padding(HiveSpacing.s8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .onAppear { Task { await loadBoosts() } }
        .sheet(isPresented: $showEditor) {
            if let b = selectedBoost,
               let url = URL(string: "https://" + b.urlPattern.replacingOccurrences(of: "*", with: "example")) {
                BoostEditorView(boost: b, pageURL: url, pageTitle: b.name)
            }
        }
    }

    private var filteredBoosts: [Boost] {
        guard !searchText.isEmpty else { return boosts }
        let q = searchText.lowercased()
        return boosts.filter { $0.name.lowercased().contains(q) || $0.urlPattern.lowercased().contains(q) }
    }

    private var emptyState: some View {
        VStack(spacing: HiveSpacing.s16) {
            Image(systemName: "paintbrush.pointed").font(HiveTypography.font(.display2)).foregroundStyle(.hiveGraphite)
            VStack(spacing: HiveSpacing.s4) {
                Text("No Boosts yet").font(HiveTypography.font(.brandSubtitle))
                Text("Right‑click any page and choose\n«Create Boost for This Site» to start.")
                    .font(.caption).foregroundStyle(.hiveGraphite).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    private func boostRow(_ boost: Boost) -> some View {
        HStack(spacing: HiveSpacing.s8) {
            Toggle(isOn: Binding(
                get: { boost.isEnabled },
                set: { _ in Task { await store.toggle(id: boost.id); await self.loadBoosts() } }
            )) { EmptyView() }.toggleStyle(.switch).controlSize(.small)

            VStack(alignment: .leading, spacing: 1) {
                Text(boost.name).font(HiveTypography.font(.bodyMedium)).lineLimit(1)
                Text(boost.urlPattern).font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.hiveGraphite).lineLimit(1)
            }

            Spacer()

            HStack(spacing: HiveSpacing.s4) {
                if boost.forceDarkMode {
                    Image(systemName: "moon.fill").font(.caption2).foregroundStyle(.hiveAccent)
                }
                if !boost.zappedSelectors.isEmpty {
                    Text("\(boost.zappedSelectors.count)z").font(.caption2.weight(.medium)).foregroundStyle(.hiveError)
                }
                if !boost.css.isEmpty { Text("CSS").font(.caption2.weight(.medium)).foregroundStyle(.hiveSuccess) }
                if !boost.js.isEmpty { Text("JS").font(.caption2.weight(.medium)).foregroundStyle(.hiveWarning) }
            }

            Button {
                selectedBoost = boost
                showEditor = true
            } label: {
                Image(systemName: "pencil").font(.caption)
            }.buttonStyle(.plain).foregroundStyle(.hiveGraphite)
        }
        .padding(.horizontal, HiveSpacing.s8)
        .padding(.vertical, HiveSpacing.s4)
        .background(.hiveMist.opacity(0.15), in: RoundedRectangle(cornerRadius: HiveRadius.r6))
        .contextMenu {
            Button {
                Task { await store.toggle(id: boost.id); await loadBoosts() }
            } label: {
                Label(boost.isEnabled ? "Disable" : "Enable", systemImage: boost.isEnabled ? "pause" : "play")
            }
            Divider()
            Button(role: .destructive) {
                Task { await store.delete(id: boost.id); await loadBoosts() }
            } label: {
                Label("Delete Boost", systemImage: "trash")
            }
        }
    }

    private func loadBoosts() async {
        boosts = await store.allBoosts()
    }
}
