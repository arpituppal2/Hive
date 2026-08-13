import SwiftUI
import HiveCore

struct NavigationBlockBanner: View {
    let notice: NavigationBlockNotice

    @Environment(BrowserState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: HiveDesign.Space.sm) {
            Image(systemName: "nosign")
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
                    state.dismissNavigationBlockNotice()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(HiveDesign.Typography.sectionHeader)
                    .foregroundStyle(HiveDesign.Text.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss navigation blocked notice")
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
