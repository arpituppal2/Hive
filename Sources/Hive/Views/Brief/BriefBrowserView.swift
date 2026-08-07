import SwiftUI
import HiveCore

// MARK: - BriefBrowserView
//
// Lists all saved Briefs from BriefStore, newest first. Each Brief shows its
// title, content preview (first 120 chars), creation date, source count, and
// a delete button. Tapping a Brief opens its full content in a detail sheet.
// Accessible from the Settings window or the Start Page.

struct BriefBrowserView: View {

    @Environment(ChromeState.self) private var state

    @State private var briefs: [Brief] = []
    @State private var isLoading = false
    @State private var selectedBrief: Brief?
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: HiveSpacing.s8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(.hiveAccent)
                    .font(HiveTypography.font(.dialogTitle))
                Text("Saved Journals")
                    .hiveType(.chromeTitle)
                    .foregroundStyle(.hiveInk)
                Spacer()
                if !briefs.isEmpty {
                    Text("\(briefs.count) journal\(briefs.count == 1 ? "" : "s")")
                        .hiveType(.chromeLabel)
                        .foregroundStyle(.hiveGraphite)
                }
            }
            .padding(.horizontal, HiveSpacing.s12)
            .padding(.vertical, HiveSpacing.s8)

            Divider().overlay(Color.hiveBorderSubtle)

            if isLoading {
                Spacer()
                ProgressView().progressViewStyle(.circular)
                Spacer()
            } else if briefs.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filteredBriefs) { brief in
                        briefRow(brief)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .onTapGesture { selectedBrief = brief }
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color.hiveSurfaceElevated)
        .task { await loadBriefs() }
        .onChange(of: state.selectedBriefID) { _, newID in
            if let id = newID, let brief = briefs.first(where: { $0.id == id }) {
                selectedBrief = brief
                state.selectedBriefID = nil
            }
        }
        .sheet(item: $selectedBrief) { brief in
            briefDetail(brief)
                .frame(width: 600, height: 500)
        }
    }

    private var filteredBriefs: [Brief] {
        guard !searchText.isEmpty else { return briefs }
        return briefs.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var emptyState: some View {
        VStack(spacing: HiveSpacing.s8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(HiveTypography.font(.display3))
                .foregroundStyle(.hiveMist)
            Text("No journals yet")
                .hiveType(.body)
                .foregroundStyle(.hiveGraphite)
            Text("Ask the Librarian a research question, then save the answer as a Journal.")
                .hiveType(.caption2)
                .foregroundStyle(.hiveMist)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HiveSpacing.s24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(HiveSpacing.s48)
    }

    private func briefRow(_ brief: Brief) -> some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s4) {
            HStack {
                Text(brief.title)
                    .hiveType(.chromeTitle)
                    .foregroundStyle(.hiveInk)
                    .lineLimit(1)
                Spacer()
                Text(brief.createdAt, style: .date)
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveGraphite)
            }
            Text(brief.content.prefix(120))
                .hiveType(.bodySmall)
                .foregroundStyle(.hiveGraphite)
                .lineLimit(2)
            HStack(spacing: HiveSpacing.s4) {
                if !brief.sourceIDs.isEmpty {
                    Image(systemName: "link")
                        .font(HiveTypography.font(.micro))
                    Text("\(brief.sourceIDs.count) source\(brief.sourceIDs.count == 1 ? "" : "s")")
                        .hiveType(.caption2)
                        .foregroundStyle(.hiveAccent)
                }
                Spacer()
                Button {
                    deleteBrief(brief)
                } label: {
                    Image(systemName: "trash")
                        .font(HiveTypography.font(.caption2))
                        .foregroundStyle(.hiveMist)
                }
                .buttonStyle(.plain)
                .help("Delete journal")
            }
        }
        .padding(.horizontal, HiveSpacing.s12)
        .padding(.vertical, HiveSpacing.s8)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func briefDetail(_ brief: Brief) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(brief.title)
                        .hiveType(.chromeTitle)
                        .foregroundStyle(.hiveInk)
                    Text("Saved \(brief.createdAt, style: .date)")
                        .hiveType(.caption2)
                        .foregroundStyle(.hiveGraphite)
                }
                Spacer()
                Button("Done") { selectedBrief = nil }
                    .buttonStyle(.plain)
                    .foregroundStyle(.hiveAccent)
            }
            .padding(HiveSpacing.s12)

            Divider().overlay(Color.hiveBorderSubtle)

            ScrollView {
                if let attributed = try? AttributedString(markdown: brief.content,
                    options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    Text(attributed)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(HiveSpacing.s12)
                } else {
                    Text(brief.content)
                        .hiveType(.body)
                        .foregroundStyle(.hiveInk)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(HiveSpacing.s12)
                }
            }
        }
        .background(Color.hiveBackground)
    }

    private func loadBriefs() async {
        guard let store = state.briefStore else { return }
        isLoading = true
        briefs = (try? await store.list(limit: 50)) ?? []
        isLoading = false
    }

    private func deleteBrief(_ brief: Brief) {
        Task {
            try? await state.briefStore?.delete(id: brief.id)
            await loadBriefs()
        }
    }
}
