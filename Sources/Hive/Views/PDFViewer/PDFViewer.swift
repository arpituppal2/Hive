import SwiftUI
import PDFKit

// MARK: - PDFViewer
//
// A native PDF viewer for the browser, rendered when a tab navigates to a PDF URL.
// Wraps PDFKit's `PDFView` in an NSViewRepresentable. Includes a compact toolbar
// with zoom controls (zoom in/out/reset), page navigation (prev/next, page counter),
// and a download button. The toolbar auto-hides after 2 seconds of inactivity.

struct PDFViewer: View {

    let url: URL
    let filename: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pdfView: PDFView?
    @State private var currentPage = 1
    @State private var pageCount = 1
    @State private var scaleFactor: CGFloat = 1.0
    @State private var showToolbar = true
    @State private var hideToolbarWorkItem: DispatchWorkItem?

    var body: some View {
        ZStack(alignment: .bottom) {
            PDFKitView(url: url, pdfView: $pdfView, onPageChange: { page, total in
                currentPage = page
                pageCount = total
            }, onScaleChange: { scale in
                scaleFactor = scale
            })
            .onTapGesture { toggleToolbar() }

            if showToolbar {
                toolbar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear { resetToolbarTimer() }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 16) {
            // Page navigation
            Button { pdfView?.goToPreviousPage(nil) } label: {
                Image(systemName: "chevron.left")
                    .font(HiveTypography.font(.bodyMedium))
            }
            .buttonStyle(.plain)
            .disabled(currentPage <= 1)

            Text("\(currentPage) / \(pageCount)")
                .hiveType(.chromeLabel)
                .foregroundStyle(.hiveInk)
                .monospacedDigit()
                .frame(minWidth: 50, alignment: .center)

            Button { pdfView?.goToNextPage(nil) } label: {
                Image(systemName: "chevron.right")
                    .font(HiveTypography.font(.bodyMedium))
            }
            .buttonStyle(.plain)
            .disabled(currentPage >= pageCount)

            Rectangle()
                .fill(Color.hiveBorderSubtle)
                .frame(width: 1, height: 20)

            // Zoom
            Button {
                let newScale = max(0.25, scaleFactor - 0.25)
                pdfView?.scaleFactor = newScale
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(HiveTypography.font(.bodyMedium))
            }
            .buttonStyle(.plain)

            Text("\(Int(scaleFactor * 100))%")
                .hiveType(.chromeLabel)
                .foregroundStyle(.hiveInk)
                .monospacedDigit()
                .frame(width: 40, alignment: .center)

            Button {
                let newScale = min(5.0, scaleFactor + 0.25)
                pdfView?.scaleFactor = newScale
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(HiveTypography.font(.bodyMedium))
            }
            .buttonStyle(.plain)

            Button {
                pdfView?.autoScales = true
            } label: {
                Image(systemName: "arrow.down.backward.and.arrow.up.forward")
                    .font(HiveTypography.font(.captionMedium))
            }
            .buttonStyle(.plain)
            .help("Fit to window")

            Rectangle()
                .fill(Color.hiveBorderSubtle)
                .frame(width: 1, height: 20)

            // Download
            Button {
                Task { await DownloadManager.shared.startDownload(from: url, suggestedFilename: filename) }
            } label: {
                Image(systemName: "arrow.down.to.line")
                    .font(HiveTypography.font(.bodyMedium))
            }
            .buttonStyle(.plain)
            .help("Download PDF")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r8))
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.r8)
                .stroke(Color.hiveBorderSubtle, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        .padding(.bottom, 16)
    }

    // MARK: Toolbar timer

    private func toggleToolbar() {
        if showToolbar {
            hideToolbar()
        } else {
            showToolbar = true
            resetToolbarTimer()
        }
    }

    private func hideToolbar() {
        withAnimation(reduceMotion ? .linear(duration: 0.12) : .hiveMicro) {
            showToolbar = false
        }
    }

    private func resetToolbarTimer() {
        hideToolbarWorkItem?.cancel()
        showToolbar = true
        let work = DispatchWorkItem { [self] in hideToolbar() }
        hideToolbarWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
    }
}

// MARK: - PDFKitView (NSViewRepresentable)

private struct PDFKitView: NSViewRepresentable {

    let url: URL
    @Binding var pdfView: PDFView?
    nonisolated(unsafe) let onPageChange: (Int, Int) -> Void
    nonisolated(unsafe) let onScaleChange: (CGFloat) -> Void

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument(url: url)
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displaysPageBreaks = true
        view.backgroundColor = .controlBackgroundColor

        // Track page changes via notification.
        NotificationCenter.default.addObserver(
            forName: .PDFViewPageChanged,
            object: view,
            queue: .main
        ) { _ in
            guard let doc = view.document else { return }
            let current = doc.index(for: view.currentPage ?? doc.page(at: 0) ?? PDFPage())
            onPageChange(current + 1, doc.pageCount)
        }

        // Track scale changes via KVO
        view.addObserver(context.coordinator, forKeyPath: "scaleFactor", options: .new, context: nil)

        DispatchQueue.main.async { self.pdfView = view }
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScaleChange: onScaleChange)
    }

    class Coordinator: NSObject {
        let onScaleChange: (CGFloat) -> Void
        init(onScaleChange: @escaping (CGFloat) -> Void) {
            self.onScaleChange = onScaleChange
        }
        override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                    change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "scaleFactor", let view = object as? PDFView {
                onScaleChange(view.scaleFactor)
            }
        }
    }
}
