import SwiftUI
import HiveCore

/// Branded load-failure banner (Chrome/Arc-style reinforcement of Chromium's
/// own error page). Shown when the active tab's main frame failed to load:
/// the failed URL's host, the Chromium error text, and a one-click Retry.
struct NavigationErrorBanner: View {
    let notice: BrowserState.LoadErrorNotice

    @Environment(BrowserState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: HiveDesign.Space.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(HiveDesign.Typography.subHeadingSemiBold)
                .foregroundStyle(HiveDesign.State.warning)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(HiveDesign.Text.primary)
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(HiveDesign.Text.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: HiveDesign.Space.xs)

            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    state.retryLoadError()
                }
            } label: {
                Text("Retry")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(HiveDesign.Accent.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retry loading \(notice.url.host ?? notice.url.absoluteString)")
            .accessibilityHint("Loads the failed address again")

            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    state.dismissLoadError()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(HiveDesign.Typography.sectionHeader)
                    .foregroundStyle(HiveDesign.Text.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss load error notice")
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
    }

    private var detail: String {
        let host = notice.url.host ?? notice.url.absoluteString
        return "\(host) · \(notice.text)"
    }
}
