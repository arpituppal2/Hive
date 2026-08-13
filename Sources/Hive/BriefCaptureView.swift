import SwiftUI
import HiveCore

// MARK: - BriefCaptureView
///
/// Captures the current page into Honeycomb as a Source node, bridging the
/// Browse → Remember → Organize steps of the demo spine. The user sees:
/// 1. What will be captured (URL, title, host)
/// 2. A confidence score (content hash-based dedup)
/// 3. A "Capture" button that creates Honeycomb nodes and updates hot memory
///
/// After capture, the node appears in the KnowledgePanel and hot memory.
struct BriefCaptureView: View {
    @Environment(BrowserState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isCapturing = false
    @State private var capturedNodeID: String?
    @State private var captureError: String?
    @State private var hasAppeared: Bool = false
    @State private var showCheckmark: Bool = false

    private var pageContext: PageContext? {
        state.activePageContext
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(HiveDesign.Typography.subHeadingSemiBold)
                    .foregroundStyle(HiveDesign.Accent.primary)
                Text("Capture Page")
                    .font(HiveDesign.Typography.heading)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(HiveDesign.Typography.subHeading)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close capture")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if isCapturing {
                capturingView
            } else if let _ = capturedNodeID {
                successView
            } else {
                previewView
            }
        }
        .frame(width: 380, height: 420)
        .background(HiveDesign.Material.panel)
        .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 5)
        .transition(
            reduceMotion
                ? .opacity
                : .scale(scale: 0.95).combined(with: .opacity)
        )
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
        }
    }

    // MARK: - Preview

    private var previewView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let ctx = pageContext {
                        capturePreview(context: ctx)
                    } else {
                        noPageView
                    }
                }
                .padding(16)
            }

            Divider()

            // Action bar
            HStack {
                if let error = captureError {
                    Text(error)
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundStyle(.red)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.borderless)
                    .font(HiveDesign.Typography.bodyMedium)
                Button(action: performCapture) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Capture")
                    }
                    .font(HiveDesign.Typography.bodySemiBold)
                }
                .buttonStyle(.borderedProminent)
                .tint(HiveDesign.Accent.primary)
                .disabled(pageContext == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func capturePreview(context: PageContext) -> some View {
        // Page info card
        VStack(alignment: .leading, spacing: 10) {
            Label("Current Page", systemImage: "globe")
                .font(HiveDesign.Typography.sectionHeader)
                .foregroundStyle(HiveDesign.Text.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text(context.title)
                    .font(HiveDesign.Typography.subHeadingSemiBold)
                    .lineLimit(2)
                Text(context.url?.absoluteString ?? "")
                    .font(HiveDesign.Typography.monoSmall)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                if let host = context.url?.host {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(HiveDesign.Typography.microLabelSecondary)
                        Text(host)
                            .font(HiveDesign.Typography.smallLabel)
                    }
                    .foregroundStyle(HiveDesign.Accent.primary.opacity(0.7))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HiveDesign.Surface.level2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }

        // What happens next
        VStack(alignment: .leading, spacing: 8) {
            Label("After Capture", systemImage: "brain.head.profile")
                .font(HiveDesign.Typography.sectionHeader)
                .foregroundStyle(HiveDesign.Text.secondary)

            VStack(alignment: .leading, spacing: 6) {
                captureInfoRow("hexagon.fill", "Stored in Honeycomb as a Source node")
                captureInfoRow("flame.fill", "Added to Hot Memory for AI context")
                captureInfoRow("link", "Linked to your current workspace")
                captureInfoRow("clock.arrow.circlepath", "Revisits will boost relevance")
            }
        }
        .padding(12)
        .background(HiveDesign.Surface.level1)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var noPageView: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.square.dashed")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No page to capture")
                .font(HiveDesign.Typography.panelTitleMedium)
                .foregroundStyle(.secondary)
            Text("Open a web page first, then capture it into your Hive knowledge graph.")
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Capture in progress

    private var capturingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Capturing page into Honeycomb...")
                .font(HiveDesign.Typography.panelTitleMedium)
            Text("Creating Source node with content hash for deduplication")
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    // MARK: - Success

    /// Phase-driven checkmark entrance: scale up → bounce-larger → settle.
    /// Three phases create a satisfying physical reveal that feels like a
    /// stamp of approval rather than a static icon.
    private var successView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(HiveDesign.Typography.heroDisplayXL)
                .foregroundStyle(.green)
                .phaseAnimator(
                    reduceMotion ? PhaseCheckmark.allCases : PhaseCheckmark.allCases,
                    trigger: showCheckmark
                ) { content, phase in
                    content
                        .scaleEffect(phase.scale)
                        .opacity(phase.opacity)
                        .rotationEffect(.degrees(phase.rotation))
                } animation: { phase in
                    switch phase {
                    case .hidden: return .easeOut(duration: 0.01)
                    case .scaling: return HiveDesign.Animation.bouncy
                    case .settled: return HiveDesign.Animation.spring
                    }
                }
                .onAppear { showCheckmark = true }
            Text("Page Captured")
                .font(HiveDesign.Typography.dialogTitleBold)
                .opacity(showCheckmark ? 1 : 0)
                .offset(y: showCheckmark ? 0 : 8)
                .animation(
                    reduceMotion
                        ? .easeOut(duration: 0.01)
                        : HiveDesign.Animation.entrance.delay(0.15),
                    value: showCheckmark
                )
            Text("This page is now in your knowledge graph and hot memory.\nThe AI will reference it in future queries.")
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .opacity(showCheckmark ? 1 : 0)
                .offset(y: showCheckmark ? 0 : 6)
                .animation(
                    reduceMotion
                        ? .easeOut(duration: 0.01)
                        : HiveDesign.Animation.entrance.delay(0.30),
                    value: showCheckmark
                )
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(HiveDesign.Accent.primary)
                .padding(.top, 8)
                .opacity(showCheckmark ? 1 : 0)
                .animation(
                    reduceMotion
                        ? .easeOut(duration: 0.01)
                        : HiveDesign.Animation.entrance.delay(0.45),
                    value: showCheckmark
                )
            Spacer()
        }
    }

    // MARK: - Helpers

    private func captureInfoRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(HiveDesign.Accent.primary.opacity(0.6))
                .frame(width: 16)
            Text(text)
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Capture action

    private func performCapture() {
        guard pageContext != nil else { return }
        isCapturing = true
        captureError = nil

        Task {
            do {
                let nodeID = try await state.captureCurrentPage()
                await MainActor.run {
                    capturedNodeID = nodeID
                    isCapturing = false
                }
            } catch {
                await MainActor.run {
                    captureError = error.localizedDescription
                    isCapturing = false
                }
            }
        }
    }
}

// MARK: - Checkmark Phase

private enum PhaseCheckmark: CaseIterable {
    case hidden, scaling, settled

    var scale: CGFloat {
        switch self {
        case .hidden: return 0.3
        case .scaling: return 1.2
        case .settled: return 1.0
        }
    }

    var opacity: CGFloat {
        switch self {
        case .hidden: return 0
        case .scaling: return 1
        case .settled: return 1
        }
    }

    var rotation: CGFloat {
        switch self {
        case .hidden: return -15
        case .scaling: return 5
        case .settled: return 0
        }
    }
}

// MARK: - Preview

#if DEBUG
struct BriefCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        BriefCaptureView()
            .environment(BrowserState())
    }
}
#endif
