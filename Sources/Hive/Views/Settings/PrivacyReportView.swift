import SwiftUI
import HiveCore

// MARK: - PrivacyReportView
//
// A local report of measured content-blocking counts. The browser currently
// records a flat blocked-request total per tab, so this view intentionally does
// not invent category attribution.

struct PrivacyReportView: View {

    @Environment(ChromeState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredHost: String?

    private var summary: PrivacyReportSummary {
        PrivacyReportSummary(tabs: state.tabs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s24) {
            heroCard

            if summary.totalBlocked > 0 {
                measuredScopeNote
            }

            if !summary.topSites.isEmpty {
                topSitesList
            }

            if summary.totalBlocked == 0 {
                emptyState
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: HiveSpacing.s12) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.hiveAccent)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(summary.totalBlocked)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.hiveInk)
                    Text("requests blocked")
                        .hiveType(.caption2)
                        .foregroundStyle(.hiveMist)
                }
            }

            Text("Measured across \(summary.measuredTabCount) non-private tab\(summary.measuredTabCount == 1 ? "" : "s") in this session.")
                .hiveType(.caption2)
                .foregroundStyle(.hiveMist)
                .lineLimit(3)
        }
        .padding(HiveSpacing.s16)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r16)
                .fill(Color.hiveSurfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.r16)
                .stroke(Color.hiveAccent.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Measured Scope

    private var measuredScopeNote: some View {
        Label {
            Text("Hive currently records totals and host-level counts only. Category attribution is not available from the active blocker data, so no category estimates are shown.")
                .hiveType(.caption2)
                .foregroundStyle(.hiveGraphite)
        } icon: {
            Image(systemName: "info.circle")
                .foregroundStyle(.hiveAccent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Measured report scope. Hive records totals and host-level counts only. Category attribution is not available, so no category estimates are shown.")
    }

    // MARK: - Top Sites

    private var topSitesList: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s12) {
            Text("Top Sites")
                .hiveType(.chromeTitle)
                .foregroundStyle(.hiveInk)

            ForEach(summary.topSites) { site in
                HStack(spacing: HiveSpacing.s12) {
                    Image(systemName: "globe")
                        .frame(width: 22)
                        .foregroundStyle(.hiveGraphite)

                    Text(site.host)
                        .hiveType(.body)
                        .foregroundStyle(.hiveInk)
                        .lineLimit(1)

                    Spacer()

                    Text("\(site.count)")
                        .hiveType(.bodySmall)
                        .monospacedDigit()
                        .foregroundStyle(.hiveGraphite)
                }
                .padding(.vertical, HiveSpacing.s4)
                .contentShape(RoundedRectangle(cornerRadius: HiveRadius.r8))
                .background(
                    RoundedRectangle(cornerRadius: HiveRadius.r8)
                        .fill(hoveredHost == site.host ? Color.hiveSurface : Color.clear)
                )
                .onHover { hovering in
                    withAnimation(reduceMotion ? nil : .hiveMicro) {
                        hoveredHost = hovering ? site.host : nil
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(site.host), \(site.count) blocked requests")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: HiveSpacing.s12) {
            Image(systemName: "shield.checkered")
                .font(HiveTypography.font(.display2))
                .foregroundStyle(.hiveMist)

            Text("No Measured Blocks")
                .hiveType(.body)
                .foregroundStyle(.hiveMist)

            Text("Open websites to see measured blocking counts appear here. Private tabs are excluded from this report.")
                .hiveType(.caption2)
                .foregroundStyle(.hiveMist)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HiveSpacing.s48)
    }
}
