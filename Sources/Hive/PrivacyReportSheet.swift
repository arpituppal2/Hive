import SwiftUI

// MARK: - PrivacyReportSheet
//
// An honest privacy report showing real tracker-block counts from EasyList.
// No fabricated tracker domains — shows categories and an honest summary.

struct PrivacyReportSheet: View {
    @Environment(BrowserState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "shield.checkered")
                    .font(HiveDesign.Typography.heading)
                    .foregroundStyle(.green)
                Text("Privacy Report")
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                Button(action: { state.closePrivacyReport() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(HiveDesign.Typography.heading)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)

            // Summary card — shows real count
            VStack(spacing: 4) {
                Text("\(state.trackerBlockedCount)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .smooth, value: state.trackerBlockedCount)

                Text(state.trackerBlockedCount == 1
                    ? "tracker blocked this session"
                    : "trackers blocked this session")
                    .font(HiveDesign.Typography.bodyMedium)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous)
                    .fill(Color.green.opacity(0.08))
            )
            .padding(.horizontal, 20)

            // Blocklist info
            VStack(alignment: .leading, spacing: 0) {
                Text("How it works")
                    .font(HiveDesign.Typography.sidebarItemSemiBold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                // EasyList explanation
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(HiveDesign.Typography.bodyLarge)
                        .foregroundStyle(.green)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("EasyList blocklist")
                            .font(HiveDesign.Typography.bodyMedium)
                        Text("Over 1,500 ad and tracker domains blocked automatically.")
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                Divider().padding(.leading, 52)

                // Categories
                HStack(spacing: 12) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(HiveDesign.Typography.bodyLarge)
                        .foregroundStyle(.green)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Blocks these categories")
                            .font(HiveDesign.Typography.bodyMedium)
                        Text("Advertisers, analytics, social trackers, data brokers, ad networks.")
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                Divider().padding(.leading, 52)

                // Local + private
                HStack(spacing: 12) {
                    Image(systemName: "lock.square.fill")
                        .font(HiveDesign.Typography.bodyLarge)
                        .foregroundStyle(.green)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Private by default")
                            .font(HiveDesign.Typography.bodyMedium)
                        Text("Blocking happens locally on your device. No browsing data is ever sent anywhere.")
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }

            Spacer()
        }
        .frame(width: 420, height: 420)
        .background(HiveDesign.Material.panel)
    }
}
