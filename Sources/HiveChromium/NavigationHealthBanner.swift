import SwiftUI
import HiveCore

struct NavigationHealthBanner: View {
    let notice: ChromiumBrowserState.NavigationHealthNotice

    @Environment(ChromiumBrowserState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: HiveDesign.Space.sm) {
            Image(systemName: "arrow.triangle.2.circlepath.circle")
                .font(HiveDesign.Typography.subHeadingSemiBold)
                .foregroundStyle(HiveDesign.State.warning)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(HiveDesign.Text.primary)
                Text(notice.detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(HiveDesign.Text.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: HiveDesign.Space.xs)

            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    state.retryNavigationHealthNotice()
                }
            } label: {
                Text("Retry")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(HiveDesign.Accent.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retry stalled navigation")
            .accessibilityHint("Loads the same address again")

            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    state.dismissNavigationHealthNotice()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(HiveDesign.Typography.sectionHeader)
                    .foregroundStyle(HiveDesign.Text.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss stalled navigation notice")
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
        .accessibilityLabel(notice.accessibilityLabel)
    }
}
