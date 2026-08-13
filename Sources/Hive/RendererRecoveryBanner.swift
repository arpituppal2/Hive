import SwiftUI
import HiveCore

/// Branded renderer-crash recovery banner. Shown only when the crash-loop
/// policy stops automatic retries (three crashes inside five minutes) and hands
/// recovery to the user — the page's process kept crashing, so Hive surfaces it
/// honestly instead of leaving a silently hung page.
struct RendererRecoveryBanner: View {
    let notice: BrowserState.RendererRecoveryNotice

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
                Text(notice.detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(HiveDesign.Text.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: HiveDesign.Space.xs)

            if notice.canRetry {
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        state.retryRendererRecovery()
                    }
                } label: {
                    Text("Reload")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(HiveDesign.Accent.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reload the crashed page")
                .accessibilityHint("Loads the crashed address again")
            }

            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    state.dismissRendererRecovery()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(HiveDesign.Typography.sectionHeader)
                    .foregroundStyle(HiveDesign.Text.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss crash notice")
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
}
