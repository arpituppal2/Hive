import SwiftUI
import WebKit
import HiveCore

// MARK: - ClearDataView
//
// A confirmation modal for clearing browsing data. Triggered from Settings or
// ⌘⇧Delete. Groups data into categories (history, cache, cookies, downloads)
// with a time-range selector. Actual WKWebsiteDataStore operations run async.

struct ClearDataView: View {

    @Environment(ChromeState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var timeRange: ClearTimeRange = .allTime
    @State private var clearHistory: Bool = true
    @State private var clearCache: Bool = true
    @State private var clearCookies: Bool = false
    @State private var clearDownloads: Bool = false
    @State private var isClearing: Bool = false
    @State private var clearedCount: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Clear Browsing Data")
                    .hiveType(.chromeTitle)
                    .foregroundStyle(.hiveInk)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.hiveGraphite)
            }
            .padding(.horizontal, HiveSpacing.s16)
            .padding(.top, HiveSpacing.s16)
            .padding(.bottom, HiveSpacing.s12)

            Divider().overlay(Color.hiveBorderSubtle)

            ScrollView {
                VStack(alignment: .leading, spacing: HiveSpacing.s16) {
                    // Time range picker
                    VStack(alignment: .leading, spacing: HiveSpacing.s8) {
                        Text("Time Range")
                            .hiveType(.chromeLabel)
                            .foregroundStyle(.hiveGraphite)
                        Picker("Time Range", selection: $timeRange) {
                            ForEach(ClearTimeRange.allCases, id: \.self) { range in
                                Text(range.label).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    // Categories
                    VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                        Text("Data to Clear")
                            .hiveType(.chromeLabel)
                            .foregroundStyle(.hiveGraphite)

                        ToggleRow(icon: "clock", label: "Browsing History",
                                  subtitle: "URLs, titles, and visit timestamps",
                                  isOn: $clearHistory)
                        ToggleRow(icon: "square.stack.3d.up", label: "Cached Images & Files",
                                  subtitle: "Page resources stored for faster loading",
                                  isOn: $clearCache)
                        ToggleRow(icon: "hand.raised", label: "Cookies & Site Data",
                                  subtitle: "Login sessions, preferences, tracking data",
                                  isOn: $clearCookies)
                        ToggleRow(icon: "arrow.down.circle", label: "Download History",
                                  subtitle: "List of files downloaded through Hive",
                                  isOn: $clearDownloads)
                    }

                    // Status
                    if !clearedCount.isEmpty {
                        HStack(spacing: HiveSpacing.s8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(clearedCount)
                                .hiveType(.bodySmall)
                                .foregroundStyle(.green)
                        }
                        .padding(HiveSpacing.s12)
                        .background(RoundedRectangle(cornerRadius: HiveRadius.r8).fill(Color.green.opacity(0.1)))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(clearedCount)
                    }

                    // Action button
                    Button(action: performClear) {
                        HStack(spacing: HiveSpacing.s8) {
                            if isClearing {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 16, height: 16)
                                    .accessibilityLabel("Clearing browsing data")
                            }
                            Text(isClearing ? "Clearing…" : "Clear Data")
                                .hiveType(.body)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HiveSpacing.s12)
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.r8)
                                .fill(canClear ? Color.red.opacity(0.85) : Color.hiveSurface)
                        )
                        .foregroundStyle(canClear ? .white : .hiveGraphite)
                    }
                    .disabled(!canClear || isClearing)
                    .accessibilityLabel(isClearing ? "Clearing browsing data" : "Clear selected browsing data")
                    .buttonStyle(.plain)
                }
                .padding(HiveSpacing.s16)
            }
        }
        .frame(width: 440, height: 480)
        .background(Color.hiveBackground)
    }

    private var canClear: Bool { clearHistory || clearCache || clearCookies || clearDownloads }

    private func performClear() {
        guard canClear, !isClearing else { return }
        isClearing = true
        clearedCount = ""

        Task {
            var itemsCleared = 0

            // 1. Clear history from prefs
            if clearHistory {
                state.clearHistory()
                itemsCleared += 1
            }

            // 2. Clear cache + cookies via WKWebsiteDataStore
            if clearCache || clearCookies {
                var types: Set<String> = []
                if clearCache { types.insert(WKWebsiteDataTypeDiskCache)
                    types.insert(WKWebsiteDataTypeMemoryCache)
                    types.insert(WKWebsiteDataTypeOfflineWebApplicationCache) }
                if clearCookies { types.insert(WKWebsiteDataTypeCookies)
                    types.insert(WKWebsiteDataTypeLocalStorage)
                    types.insert(WKWebsiteDataTypeSessionStorage)
                    types.insert(WKWebsiteDataTypeIndexedDBDatabases) }

                let since: Date = switch timeRange {
                case .lastHour:     Date().addingTimeInterval(-3600)
                case .lastDay:      Date().addingTimeInterval(-86400)
                case .lastWeek:     Date().addingTimeInterval(-604800)
                case .lastMonth:    Date().addingTimeInterval(-2592000)
                case .allTime:      .distantPast
                }

                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    WKWebsiteDataStore.default().removeData(
                        ofTypes: types,
                        modifiedSince: since
                    ) { cont.resume() }
                }
                itemsCleared += 1
            }

            // 3. Clear download history
            if clearDownloads {
                await DownloadManager.shared.clearFinished()
                itemsCleared += 1
            }

            await MainActor.run {
                isClearing = false
                clearedCount = "Cleared \(itemsCleared) categor\(itemsCleared == 1 ? "y" : "ies")"
            }
        }
    }
}

// MARK: - ClearTimeRange

enum ClearTimeRange: String, CaseIterable {
    case lastHour
    case lastDay
    case lastWeek
    case lastMonth
    case allTime

    var label: String {
        switch self {
        case .lastHour:   return "Last Hour"
        case .lastDay:    return "24 Hours"
        case .lastWeek:   return "7 Days"
        case .lastMonth:  return "30 Days"
        case .allTime:    return "All Time"
        }
    }
}

// MARK: - ToggleRow

private struct ToggleRow: View {
    let icon: String
    let label: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: HiveSpacing.s12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.hiveGraphite)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .hiveType(.body)
                    .foregroundStyle(.hiveInk)
                Text(subtitle)
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
            }
            Spacer()
            Toggle(label, isOn: $isOn)
                .labelsHidden()
                .accessibilityLabel("\(label), \(subtitle)")
        }
        .padding(.vertical, HiveSpacing.s8)
        .padding(.horizontal, HiveSpacing.s12)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r8)
                .fill(Color.hiveSurfaceElevated)
        )
    }
}
