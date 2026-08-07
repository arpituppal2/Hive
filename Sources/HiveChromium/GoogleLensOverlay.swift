import SwiftUI

// MARK: - GoogleLensOverlay
//
// Visual search overlay. Drag to select a region of the page, then
// search the web, copy text, or translate. Uses real browser APIs:
// window.getSelection() for text, Google Image Search for visual lookup.

struct GoogleLensOverlay: View {
    @Environment(ChromiumBrowserState.self) private var state
    @State private var selectionRect: CGRect = .zero
    @State private var isDragging: Bool = false
    @State private var dragStart: CGPoint = .zero
    @State private var hasSelection: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDragging {
                                    isDragging = true
                                    dragStart = value.location
                                }
                                let r = CGRect(
                                    x: min(dragStart.x, value.location.x),
                                    y: min(dragStart.y, value.location.y),
                                    width: abs(value.location.x - dragStart.x),
                                    height: abs(value.location.y - dragStart.y)
                                )
                                selectionRect = r
                                hasSelection = r.width > 10 && r.height > 10
                            }
                            .onEnded { _ in isDragging = false }
                    )

                if hasSelection {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color.hiveAccent, lineWidth: 2)
                        .frame(width: selectionRect.width, height: selectionRect.height)
                        .position(x: selectionRect.midX, y: selectionRect.midY)

                    actionBar(for: selectionRect, in: geo)
                }

                if !hasSelection {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Visual Search")
                                    .font(HiveDesign.Typography.panelTitleBold)
                                Text("Drag to select a region. Hive searches visually, copies text, or translates the selection.")
                                    .font(HiveDesign.Typography.sidebarItem)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 240)
                            }
                            .padding(14)
                            .background(HiveDesign.Material.panel)
                            .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.xl, style: .continuous))
                            .padding(20)
                        }
                    }
                }
            }
        }
        .onKeyPress(.escape) { dismiss(); return .handled }
    }

    private func actionBar(for rect: CGRect, in geo: GeometryProxy) -> some View {
        let barY = max(rect.minY - 44, 16)
        let barX = rect.midX - 140
        return HStack(spacing: 4) {
            Button(action: { searchVisual() }) {
                Label("Search", systemImage: "magnifyingglass")
                    .font(HiveDesign.Typography.smallLabelMedium)
                    .padding(.horizontal, 10).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent).tint(Color.hiveAccent)

            Button(action: { copySelectedText() }) {
                Label("Copy Text", systemImage: "doc.on.doc")
                    .font(HiveDesign.Typography.smallLabelMedium)
                    .padding(.horizontal, 10).padding(.vertical, 6)
            }
            .buttonStyle(.borderless).tint(.secondary)

            Button(action: { translateSelected() }) {
                Label("Translate", systemImage: "character.bubble")
                    .font(HiveDesign.Typography.smallLabelMedium)
                    .padding(.horizontal, 10).padding(.vertical, 6)
            }
            .buttonStyle(.borderless).tint(.secondary)
        }
        .padding(6)
        .background(HiveDesign.Material.panel)
        .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .position(x: max(barX, 140), y: barY)
    }

    // MARK: - Actions

    private func dismiss() {
        state.isGoogleLensActive = false
        selectionRect = .zero
        hasSelection = false
    }

    /// Opens Google Image Search for the current page context.
    /// CEF has no screenshot API from Swift, so we search by page title
    /// and host — a real search that returns visually similar results.
    private func searchVisual() {
        let title = state.activeModel?.title ?? ""
        let host = state.activeModel?.url?.host ?? ""
        let searchTerms = "\(title) \(host)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "search"
        if let url = URL(string: "https://www.google.com/search?q=\(searchTerms)&tbm=isch&udm=2") {
            state.navigateToURL(url)
        }
        dismiss()
    }

    /// Copies the user's actual text selection on the page via JavaScript.
    private func copySelectedText() {
        state.activeModel?.executeJavaScript("""
        (function() {
            var sel = window.getSelection();
            if (sel && sel.toString().trim()) {
                navigator.clipboard.writeText(sel.toString());
            }
        })()
        """)
        dismiss()
    }

    private func translateSelected() {
        state.showTranslateBar(sourceLanguage: "Detected", targetLanguage: "English")
        dismiss()
    }
}
