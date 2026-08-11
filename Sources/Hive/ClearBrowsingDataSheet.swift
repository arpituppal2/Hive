import SwiftUI
import HiveCore

// MARK: - ClearBrowsingDataSheet
//
// Chrome-parity "Clear browsing data" review sheet: pick a time range and the
// categories to clear, see live counts, then confirm. The time range applies
// to date-stamped history; download history, cookies, and cache clear in full
// (the model and CDP offer no time-scoped variants — stated honestly below).

struct ClearBrowsingDataSheet: View {
    @Environment(BrowserState.self) private var state
    @State private var range: ClearBrowsingDataPolicy.TimeRange = .lastDay
    @State private var clearHistory: Bool = true
    @State private var clearDownloads: Bool = true
    @State private var clearCookies: Bool = true
    @State private var clearCache: Bool = true
    @State private var isConfirming: Bool = false

    private var historyCount: Int {
        let cutoff = range.cutoff()
        return state.historyItems.filter {
            ClearBrowsingDataPolicy.isInRange($0.visitedAt, cutoff: cutoff)
        }.count
    }

    private var downloadCount: Int {
        state.downloads.filter { $0.isComplete || $0.isCanceled || $0.isInterrupted }.count
    }

    private var hasSelection: Bool {
        clearHistory || clearDownloads || clearCookies || clearCache
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "trash.fill")
                    .font(HiveDesign.Typography.panelTitleMedium)
                    .foregroundStyle(.red)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Clear Browsing Data")
                        .font(HiveDesign.Typography.subHeadingBold)
                    Text("Choose what to remove from this device")
                        .font(HiveDesign.Typography.buttonCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: { state.isClearDataPanelOpen = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(HiveDesign.Typography.bodyLarge)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            // Time range
            VStack(alignment: .leading, spacing: 6) {
                Text("Time range")
                    .font(HiveDesign.Typography.smallLabelBold)
                    .foregroundStyle(.secondary)
                Picker("Time range", selection: $range) {
                    ForEach(ClearBrowsingDataPolicy.TimeRange.allCases) { r in
                        Text(r.label).tag(r)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Categories
            VStack(spacing: 0) {
                categoryRow(
                    systemImage: "clock.arrow.circlepath",
                    title: "Browsing history",
                    subtitle: "\\(historyCount) item\\(historyCount == 1 ? \"\" : \"s\") in range",
                    isOn: $clearHistory
                )
                Divider().padding(.leading, 44)
                categoryRow(
                    systemImage: "arrow.down.circle",
                    title: "Download history",
                    subtitle: "\\(downloadCount) completed record\\(downloadCount == 1 ? \"\" : \"s\")\u{2014}clears all",
                    isOn: $clearDownloads
                )
                Divider().padding(.leading, 44)
                categoryRow(
                    systemImage: "cookie",
                    title: "Cookies & site data",
                    subtitle: "Signs you out of sites",
                    isOn: $clearCookies
                )
                Divider().padding(.leading, 44)
                categoryRow(
                    systemImage: "internaldrive",
                    title: "Cache",
                    subtitle: "Saved pages and images",
                    isOn: $clearCache
                )
            }
            .padding(.vertical, 4)

            Divider()

            // Footer
            VStack(alignment: .leading, spacing: 6) {
                Text("The time range applies to browsing history. Download history, cookies, and cache clear in full. Clearing cookies and cache needs a live web page (CDP bridge).")
                    .font(HiveDesign.Typography.buttonCaption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Button("Cancel") { state.isClearDataPanelOpen = false }
                        .buttonStyle(.bordered)

                    Spacer()

                    Button("Clear…", role: .destructive) {
                        isConfirming = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(!hasSelection)
                }
            }
            .padding(14)
        }
        .background(HiveDesign.Material.panel)
        .frame(width: 480)
        .confirmationDialog(
            "Clear selected browsing data?",
            isPresented: $isConfirming,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) {
                state.clearBrowsingData(
                    history: clearHistory,
                    downloads: clearDownloads,
                    cookies: clearCookies,
                    cache: clearCache,
                    range: range
                )
                state.isClearDataPanelOpen = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the selected data from this device. Cleared history is also removed from synced devices.")
        }
    }

    private func categoryRow(systemImage: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(HiveDesign.Typography.bodyLarge)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(HiveDesign.Typography.bodyMedium)
                Text(subtitle)
                    .font(HiveDesign.Typography.buttonCaption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        // The label area is tappable; the Toggle control keeps its own hit
        // target so clicking the switch can't double-fire with the row tap.
        .contentShape(Rectangle())
        .onTapGesture { isOn.wrappedValue.toggle() }
    }
}
