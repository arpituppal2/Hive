import SwiftUI
import HiveCore

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

                // Word count (Safari reader parity): "~1,250 words". Reported
                // by the injected reader JS over the console bridge; hidden
                // until the first report lands.
                if let words = state.readerWordCount, words > 0 {
                    Text("·")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                    Text("\(words.formatted(.number)) words")
                        .font(HiveDesign.Typography.sidebarItem)
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel("\(words.formatted(.number)) words in this article")
                }

                Spacer()

                // Font size controls (Safari parity)
                HStack(spacing: 4) {
                    Button(action: { state.adjustReaderFontScale(by: -ReaderStyle.fontScaleStep) }) {
                        Image(systemName: "textformat.size.smaller")
                            .font(HiveDesign.Typography.sidebarItem)
                            .foregroundStyle(state.readerStyle.fontScale > ReaderStyle.fontScaleRange.lowerBound ? Color.primary : Color.secondary.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .disabled(state.readerStyle.fontScale <= ReaderStyle.fontScaleRange.lowerBound)
                    .help("Decrease text size")
                    .accessibilityLabel("Decrease reader text size")

                    Text("\(state.readerStyle.fontSizePoints) pt")
                        .font(HiveDesign.Typography.buttonCaption)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 30)
                        .accessibilityLabel("Reader text size \(state.readerStyle.fontSizePoints) point")

                    Button(action: { state.adjustReaderFontScale(by: ReaderStyle.fontScaleStep) }) {
                        Image(systemName: "textformat.size.larger")
                            .font(HiveDesign.Typography.sidebarItem)
                            .foregroundStyle(state.readerStyle.fontScale < ReaderStyle.fontScaleRange.upperBound ? Color.primary : Color.secondary.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .disabled(state.readerStyle.fontScale >= ReaderStyle.fontScaleRange.upperBound)
                    .help("Increase text size")
                    .accessibilityLabel("Increase reader text size")
                }

                Divider().frame(height: 16).padding(.horizontal, 10)

                // Theme picker (Auto / Light / Sepia / Dark)
                ForEach(ReaderTheme.allCases) { theme in
                    Button(action: { state.setReaderTheme(theme) }) {
                        themeSwatch(theme)
                    }
                    .buttonStyle(.plain)
                    .help(theme.title)
                    .accessibilityLabel("Reader theme: \(theme.title)")
                    .accessibilityAddTraits(state.readerStyle.theme == theme ? .isSelected : [])
                }

                // Font family toggle (Serif / Sans, Safari parity)
                ForEach(ReaderFontFamily.allCases, id: \.self) { family in
                    Button(action: { state.setReaderFontFamily(family) }) {
                        Text(family == .serif ? "Aa" : "Aa")
                            .font(.system(size: 13, weight: .semibold, design: family == .serif ? .serif : .rounded))
                            .foregroundStyle(state.readerStyle.fontFamily == family ? Color.hiveAccent : Color.secondary)
                            .frame(width: 22, height: 20)
                            .background(state.readerStyle.fontFamily == family ? Color.hiveAccent.opacity(0.14) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help(family == .serif ? "Serif font" : "Sans-serif font")
                    .accessibilityLabel(family == .serif ? "Reader serif font" : "Reader sans-serif font")
                    .accessibilityAddTraits(state.readerStyle.fontFamily == family ? .isSelected : [])
                }

                Divider().frame(height: 16).padding(.horizontal, 10)

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

    private func themeSwatch(_ theme: ReaderTheme) -> some View {
        let color: Color = {
            switch theme {
            case .auto: return .secondary.opacity(0.55)
            case .light: return Color(hex: "#faf9f7") ?? .white
            case .sepia: return Color(hex: "#f6efe3") ?? .brown
            case .dark: return Color(hex: "#1a1a1c") ?? .black
            }
        }()
        let isSelected = state.readerStyle.theme == theme
        return Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(Color.primary.opacity(0.25), lineWidth: 1))
            .overlay(
                Circle()
                    .stroke(Color.hiveAccent, lineWidth: 2)
                    .frame(width: 18, height: 18)
                    .opacity(isSelected ? 1 : 0)
            )
            .frame(width: 20, height: 20)
            .contentShape(Circle())
    }
}
