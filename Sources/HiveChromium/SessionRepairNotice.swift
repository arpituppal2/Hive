import SwiftUI
import HiveCore

/// Non-blocking session-health disclosure shown when durable state was repaired
/// before Chromium models were rehydrated. It intentionally summarizes repair
/// classes instead of exposing raw IDs or session-file internals.
struct SessionRepairNotice: View {
    @Environment(ChromiumBrowserState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var didAnnounce = false

    private var summary: RepairSummary {
        RepairSummary(reasons: state.sessionRepairReasons)
    }

    var body: some View {
        HStack(alignment: .top, spacing: HiveDesign.Space.sm) {
            Image(systemName: "checkmark.shield.fill")
                .font(HiveDesign.Typography.subHeadingSemiBold)
                .foregroundStyle(HiveDesign.Accent.primary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: HiveDesign.Space.xs) {
                    Text("Session repaired")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(HiveDesign.Text.primary)
                    Text(summary.total == 1 ? "1 adjustment" : "\(summary.total) adjustments")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(HiveDesign.Text.tertiary)
                }

                Text(summary.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(HiveDesign.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(summary.lines, id: \.self) { line in
                            Label(line.text, systemImage: line.icon)
                                .font(HiveDesign.Typography.smallLabel)
                                .foregroundStyle(HiveDesign.Text.secondary)
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    Text(isExpanded ? "Hide details" : "Show details")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(HiveDesign.Accent.primary)
                }
                .accessibilityLabel(isExpanded ? "Hide session repair details" : "Show session repair details")
            }

            Button(action: state.dismissSessionRepairNotice) {
                Image(systemName: "xmark")
                    .font(HiveDesign.Typography.sectionHeader)
                    .foregroundStyle(HiveDesign.Text.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss session repaired notice")
        }
        .padding(.horizontal, HiveDesign.Space.md)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous)
                .fill(HiveDesign.Surface.level1)
                .overlay(
                    RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous)
                        .strokeBorder(HiveDesign.Surface.hairline, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 14, y: 4)
        )
        .padding(.horizontal, HiveDesign.Space.md)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session repaired")
        .accessibilityValue(summary.accessibilityValue)
        .onAppear {
            guard !didAnnounce else { return }
            didAnnounce = true
            AccessibilityNotification.Announcement("Session repaired. \(summary.accessibilityValue)").post()
        }
        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
    }

    private struct RepairSummary {
        struct Line: Hashable {
            let text: String
            let icon: String
        }

        let total: Int
        let lines: [Line]
        let subtitle: String
        let accessibilityValue: String

        init(reasons: [TabOrganizationNormalizer.RepairReason]) {
            total = reasons.count
            var counts: [(String, String, Int)] = []
            func add(_ label: String, _ icon: String, _ count: Int) {
                guard count > 0 else { return }
                counts.append((label, icon, count))
            }

            add("Removed duplicate records", "square.3.layers.3d.down.right", reasons.count { reason in
                switch reason {
                case .duplicateProfile, .duplicateWorkspace, .duplicateGroup, .duplicateTab: return true
                default: return false
                }
            })
            add("Excluded private tabs", "theatermasks", reasons.count { reason in
                if case .privateTabDropped = reason { return true }
                return false
            })
            add("Repaired tab scope", "square.stack.3d.up", reasons.count { reason in
                switch reason {
                case .tabMovedToFallbackProfile, .tabMovedToFallbackWorkspace, .tabDroppedWithoutValidScope: return true
                default: return false
                }
            })
            add("Cleared invalid groups", "folder.badge.questionmark", reasons.count { reason in
                if case .invalidGroupDropped = reason { return true }
                if case .tabGroupCleared = reason { return true }
                return false
            })
            add("Repaired active selection", "cursorarrow.click.2", reasons.count { reason in
                switch reason {
                case .activeProfileRepaired, .activeWorkspaceRepaired, .activeTabRepaired, .splitSecondaryTabCleared: return true
                default: return false
                }
            })

            lines = counts.map { label, icon, count in
                Line(text: count == 1 ? label : "\(label) (\(count))", icon: icon)
            }
            subtitle = lines.isEmpty ? "Hive verified the saved browser state." : "Hive kept the valid state and repaired stale references before restoring tabs."
            accessibilityValue = lines.map(\.text).joined(separator: ", ")
        }
    }
}
