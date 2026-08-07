import SwiftUI
import AppKit

// MARK: - SessionRecoveryBanner
//
// Honest recovery surface for a corrupt persisted session (AGENTS.md: no false
// theater, reversible by design). When `SessionFileStore` finds the main
// session.json unreadable, the corrupt copy is quarantined — never deleted —
// and the last known-good rolling backup is restored when one exists. This
// pill tells the user exactly that, offers to reveal the quarantined file in
// Finder, and can be dismissed. Opaque warm Hive surface per the verified
// shell visual language (no materials, no competing accent hues), Reduce
// Motion aware, VoiceOver labeled.

struct SessionRecoveryBanner: View {
    let notice: ChromiumBrowserState.SessionRecoveryNotice

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ChromiumBrowserState.self) private var state

    var body: some View {
        HStack(spacing: HiveDesign.Space.sm) {
            Image(systemName: notice.recoveredFromBackup
                  ? "arrow.uturn.backward.circle.fill"
                  : "exclamationmark.triangle.fill")
                .font(HiveDesign.Typography.subHeadingSemiBold)
                .foregroundStyle(HiveDesign.Accent.primary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(notice.recoveredFromBackup
                     ? "Last session restored from backup"
                     : "Session file couldn't be read")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(HiveDesign.Text.primary)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(HiveDesign.Text.secondary)
            }

            if let url = notice.quarantineURL {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Label("Reveal file", systemImage: "magnifyingglass")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(HiveDesign.Accent.primary)
                .accessibilityLabel("Reveal quarantined session file in Finder")
            }

            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    state.sessionRecoveryNotice = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(HiveDesign.Typography.sectionHeader)
                    .foregroundStyle(HiveDesign.Text.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss session recovery notice")
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
    }

    private var subtitle: String {
        if notice.quarantineURL != nil {
            return "The unreadable session file was set aside — not deleted."
        }
        return notice.recoveredFromBackup
            ? "Your tabs and workspaces were restored from the last good backup."
            : "No readable session was found. Nothing was deleted."
    }
}
