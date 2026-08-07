import SwiftUI

/// Discloses when a durable browser store is unavailable or a session write
/// failed. This is a safety surface: users must not mistake a successful
/// in-session write for durable persistence after SQLite setup failed.
struct PersistenceHealthBanner: View {
    @Environment(ChromiumBrowserState.self) private var state

    var body: some View {
        HStack(spacing: HiveDesign.Space.sm) {
            Image(systemName: "externaldrive.badge.xmark")
                .font(HiveDesign.Typography.subHeadingSemiBold)
                .foregroundStyle(HiveDesign.State.warning)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(HiveDesign.Text.primary)
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(HiveDesign.Text.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: HiveDesign.Space.xs)

            Button("Dismiss") {
                state.dismissPersistenceHealthNotice()
            }
            .buttonStyle(.plain)
            .foregroundStyle(HiveDesign.Accent.primary)
            .accessibilityLabel("Dismiss storage unavailable notice")
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
                .shadow(color: .black.opacity(0.35), radius: 14, y: 4)
        )
        .padding(.horizontal, HiveDesign.Space.md)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(detail)")
    }

    private var title: String {
        state.persistenceHealthPolicy.title
    }

    private var detail: String {
        state.persistenceHealthPolicy.detail
    }
}
