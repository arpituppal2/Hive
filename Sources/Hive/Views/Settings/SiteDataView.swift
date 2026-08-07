import SwiftUI
import WebKit

// MARK: - SiteDataView
//
// Lists sites that have stored data (cache, cookies, localStorage, etc.) via
// WKWebsiteDataStore. Supports per-site deletion and a "Remove All" action.
// The data list is fetched asynchronously on appear.

struct SiteDataView: View {

    @State private var records: [WKWebsiteDataRecord] = []
    @State private var isLoading = false
    @State private var showRemoveAll = false
    @State private var removedCount = 0

    private var sortedRecords: [WKWebsiteDataRecord] {
        records.sorted(by: { a, b in a.displayName < b.displayName })
    }

    private var totalStorage: String {
        let count = records.reduce(into: 0) { $0 += $1.dataTypes.count }
        return "\(records.count) site\(records.count == 1 ? "" : "s"), \(count) data type\(count == 1 ? "" : "s")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s16) {
            // Summary header
            HStack {
                Text("\(records.count) site\(records.count == 1 ? "" : "s") · \(totalStorage)")
                    .hiveType(.bodySmall)
                    .foregroundStyle(.hiveGraphite)
                Spacer()
                if !records.isEmpty {
                    Button("Remove All") { showRemoveAll = true }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                        .hiveType(.bodySmall)
                }
            }

            if isLoading {
                HStack(spacing: HiveSpacing.s8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Loading site data…")
                        .hiveType(.bodySmall)
                        .foregroundStyle(.hiveMist)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, HiveSpacing.s24)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Loading site data")
            } else if records.isEmpty {
                VStack(spacing: HiveSpacing.s8) {
                    Image(systemName: "tray")
                        .font(HiveTypography.font(.display3))
                        .foregroundStyle(.hiveMist)
                    Text("No site data stored")
                        .hiveType(.body)
                        .foregroundStyle(.hiveMist)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, HiveSpacing.s32)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No site data stored")
            } else {
                ForEach(sortedRecords, id: \.displayName) { record in
                    siteRow(record)
                }

                if removedCount > 0 {
                    HStack(spacing: HiveSpacing.s8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Removed data for \(removedCount) site\(removedCount == 1 ? "" : "s")")
                            .hiveType(.caption2)
                            .foregroundStyle(.green)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Removed data for \(removedCount) site\(removedCount == 1 ? "" : "s")")
                }
            }
        }
        .onAppear { fetchData() }
        .confirmationDialog(
            "Remove all site data?",
            isPresented: $showRemoveAll,
            titleVisibility: .visible
        ) {
            Button("Remove All", role: .destructive) { removeAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove cache, cookies, and all stored data for every site. You may be signed out of websites.")
        }
    }

    private func siteRow(_ record: WKWebsiteDataRecord) -> some View {
        HStack(spacing: HiveSpacing.s12) {
            Image(systemName: "globe")
                .frame(width: 24)
                .foregroundStyle(.hiveGraphite)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.displayName)
                    .hiveType(.body)
                    .foregroundStyle(.hiveInk)
                    .lineLimit(1)
                Text(record.dataTypes.joined(separator: ", "))
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                removeSite(record)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.hiveMist)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove data for \(record.displayName)")
            .help("Remove data for \(record.displayName)")
        }
        .padding(HiveSpacing.s8)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r8)
                .fill(Color.hiveSurfaceElevated)
        )
    }

    private func fetchData() {
        isLoading = true
        WKWebsiteDataStore.default().fetchDataRecords(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()
        ) { records in
            DispatchQueue.main.async {
                self.records = records
                self.isLoading = false
            }
        }
    }

    private func removeSite(_ record: WKWebsiteDataRecord) {
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            for: [record]
        ) {
            DispatchQueue.main.async {
                records.removeAll { $0.displayName == record.displayName }
                removedCount += 1
            }
        }
    }

    private func removeAll() {
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        ) {
            DispatchQueue.main.async {
                records = []
                removedCount = records.count
            }
        }
    }
}
