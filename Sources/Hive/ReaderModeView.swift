import SwiftUI

// MARK: - ReaderModeView
//
// Safari-style reader mode. The page content is transformed in-place via CSS
// injection (hide nav/ads/sidebars, apply clean typography). This overlay
// just shows a floating "Exit Reader" button and a subtle URL bar.

struct ReaderModeView: View {
    @Environment(BrowserState.self) private var state

    var body: some View {
        VStack {
            // Floating controls bar
            HStack(spacing: 0) {
                Image(systemName: "book.fill")
                    .foregroundStyle(.secondary)
                    .font(HiveDesign.Typography.sidebarItem)

                Text("Reader Mode")
                    .font(HiveDesign.Typography.sidebarItemSemiBold)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)

                if let host = state.activeModel?.url?.host?.replacingOccurrences(of: "www.", with: "") {
                    Text("·")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                    Text(host)
                        .font(HiveDesign.Typography.sidebarItem)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: { state.toggleReaderMode() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark")
                            .font(HiveDesign.Typography.microLabelBold)
                        Text("Exit Reader")
                            .font(HiveDesign.Typography.sidebarItemMedium)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) {
                Rectangle().fill(.primary.opacity(0.06)).frame(height: 1)
            }

            Spacer()
        }
    }
}
