import SwiftUI
import CefKit
import HiveCore

// MARK: - TaskManagerSheet
//
// Chrome ⇧⎋ Task Manager: a live table of every CEF process task with real
// memory and CPU columns, a search field, and an "End process" action for
// killable tasks. Rows refresh every two seconds while open.

struct TaskManagerSheet: View {
    @Environment(BrowserState.self) private var state
    @State private var searchText: String = ""
    @State private var selectedTaskID: Int64?
    @State private var isConfirmingEnd: Bool = false

    private var filteredRows: [TaskManagerRow] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return state.taskManagerRows }
        return state.taskManagerRows.filter {
            $0.title.lowercased().contains(q) || $0.subtitle.lowercased().contains(q)
        }
    }

    private var selectedRow: TaskManagerRow? {
        filteredRows.first { $0.id == selectedTaskID }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.fill")
                    .font(HiveDesign.Typography.panelTitleMedium)
                    .foregroundStyle(Color.hiveAccent)
                Text("Task Manager")
                    .font(HiveDesign.Typography.subHeadingBold)
                Spacer()
                Button(action: { state.closeTaskManager() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: HiveDesign.Icon.medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close task manager")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter processes", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(HiveDesign.Typography.body)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, HiveDesign.Space.md)
            .padding(.vertical, HiveDesign.Space.xs)
            .background(HiveDesign.Surface.level1)
            .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.md, style: .continuous))
            .padding(.horizontal, HiveDesign.Space.xl)
            .padding(.bottom, HiveDesign.Space.md)

            // Column headers
            HStack(spacing: 12) {
                Text("Task")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Memory")
                    .frame(width: 90, alignment: .trailing)
                Text("CPU")
                    .frame(width: 70, alignment: .trailing)
            }
            .font(HiveDesign.Typography.smallLabelBold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            // Rows
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredRows) { row in
                        TaskManagerRowView(row: row, isSelected: row.id == selectedTaskID)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedTaskID = row.id }
                    }
                }
                .padding(.horizontal, 8)
            }

            Divider()

            // Footer: honest note + End process
            HStack {
                Text("Live per-process memory and CPU from the Chromium task manager. Ending a page's process leaves the tab in a crashed state until you reload, like Chrome.")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("End Process…", role: .destructive) {
                    isConfirmingEnd = true
                }
                .disabled(selectedRow?.isKillable != true)
                .font(HiveDesign.Typography.smallLabelBold)
            }
            .padding(14)
        }
        .frame(width: 560, height: 460)
        .background(HiveDesign.Surface.canvas)
        .onAppear { refresh() }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            refresh()
        }
        .confirmationDialog(
            "End “\(selectedRow?.title ?? "process")”?",
            isPresented: $isConfirmingEnd,
            titleVisibility: .visible
        ) {
            Button("End Process", role: .destructive) {
                if let id = selectedTaskID { state.endTask(taskID: id) }
                selectedTaskID = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The tab's process will terminate and the page will show a crashed state. Reload it to restore the page.")
        }
    }

    private func refresh() {
        // Touch the refresh tick so @Observable recomputes taskManagerRows.
        state.taskManagerRefreshTick += 1
    }
}

// MARK: - TaskManagerRowView

private struct TaskManagerRowView: View {
    let row: TaskManagerRow
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                if let favicon = row.faviconURL {
                    FaviconImage(url: favicon)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: typeIcon)
                        .font(.system(size: 13))
                        .foregroundStyle(typeColor)
                        .frame(width: 16, height: 16)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.title)
                        .font(HiveDesign.Typography.smallLabelBold)
                        .foregroundStyle(HiveDesign.Text.primary)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Text(row.subtitle)
                            .font(HiveDesign.Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if row.isActiveTab {
                            Text("ACTIVE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.hiveAccent)
                        }
                        if row.isPrivateTab {
                            Text("PRIVATE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.purple)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.memoryString)
                .font(HiveDesign.Typography.body)
                .frame(width: 90, alignment: .trailing)
            Text(row.cpuString)
                .font(HiveDesign.Typography.body)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            isSelected ? HiveDesign.Surface.level2 : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
    }

    private var typeIcon: String {
        switch row.type {
        case .browser: return "macwindow"
        case .gpu: return "cpu"
        case .renderer, .extensionProcess, .guest: return "globe"
        case .utility: return "gearshape"
        case .zygote, .sandboxHelper, .plugin: return "shippingbox"
        case .dedicatedWorker, .sharedWorker, .serviceWorker: return "arrow.triangle.branch"
        case .unknown: return "questionmark"
        }
    }

    private var typeColor: Color {
        switch row.type {
        case .browser: return .blue
        case .gpu: return .purple
        case .renderer: return .green
        default: return .secondary
        }
    }
}
