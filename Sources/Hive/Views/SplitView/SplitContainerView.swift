import SwiftUI
import AppKit
import HiveCore

// MARK: - SplitConstants

enum SplitConstants {
    static let dividerWidth: CGFloat = 4
    static let minPaneWidth: CGFloat = 160
    static let minPaneHeight: CGFloat = 120
    static let maxPanes = 4
}

// MARK: - SplitPaneWebArea

/// Renders a single tab's content inside a split pane.
struct SplitPaneWebArea: View {
    let tab: BrowserTab
    @Environment(ChromeState.self) private var state

    var body: some View {
        ZStack {
            if tab.isHibernated {
                RoundedRectangle(cornerRadius: HiveRadius.r8)
                    .fill(.hiveSurface)
                    .overlay(
                        Image(systemName: "leaf.fill")
                            .font(.title2)
                            .foregroundStyle(.hiveGraphite)
                    )
            } else if let url = tab.url ?? tab.pendingURL {
                SplitPaneContentHolder(tab: tab, url: url)
            } else {
                StartPageView()
            }
        }
    }
}

private struct SplitPaneContentHolder: View {
    let tab: BrowserTab
    let url: URL
    @Environment(ChromeState.self) private var state

    var body: some View {
        WebViewContainer(
            url: url,
            isPrivate: tab.isPrivate,
            command: state.commandTabID == tab.id ? state.pendingCommand : nil,
            tabID: tab.id,
            broker: state.sessionBroker,
            hibernateRequestID: state.hibernateRequests[tab.id, default: 0],
            captureRequestID: state.captureRequests[tab.id, default: 0],
            screenshotRequestID: state.screenshotRequests[tab.id, default: 0],
            readerModeRequestID: state.readerModeRequests[tab.id, default: 0],
            findInPageRequestID: state.findInPageRequests[tab.id, default: 0],
            findInPageSearchText: state.findInPageText,
            findInPageForward: state.findInPageDirectionForward,
            enforceHTTPS: true,
            gpcEnabled: state.prefs.globalPrivacyControlEnabled,
            autofillController: nil,
            permissionState: { host, kind in
                state.sitePermissionState(host: host, kind: kind, isPrivate: tab.isPrivate)
            },
            setPermission: { host, kind, decision in
                state.setSitePermission(host: host, kind: kind, state: decision, isPrivate: tab.isPrivate)
            },
            onUpdate: { update in
                state.applyWebViewUpdate(update, forTabID: tab.id)
            }
        )
    }
}

// MARK: - SplitContainerView

struct SplitContainerView: View {
    @Environment(ChromeState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var fractions: [CGFloat] = []
    @State private var dragStartFractions: [CGFloat] = []

    private var splitTabs: [BrowserTab] { state.splitTabs }
    private var isHorizontal: Bool { state.prefs.splitOrientation == .horizontal }

    var body: some View {
        GeometryReader { geo in
            let count = splitTabs.count
            if count >= 2 {
                if isHorizontal {
                    horizontalLayout(count: count, geo: geo)
                } else {
                    verticalLayout(count: count, geo: geo)
                }
            }
        }
        .onAppear { resetFractions() }
        .onChange(of: splitTabs.count) { _, _ in resetFractions() }
        .onChange(of: state.prefs.splitOrientation) { _, _ in resetFractions() }
    }

    // MARK: - Horizontal

    private func horizontalLayout(count: Int, geo: GeometryProxy) -> some View {
        let totalWidth = geo.size.width
        let dividerTotal = SplitConstants.dividerWidth * CGFloat(count - 1)
        let availableWidth = max(totalWidth - dividerTotal, 0)

        return HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { i in
                SplitPaneWebArea(tab: splitTabs[i])
                    .frame(width: fractionWidth(i, available: availableWidth))
                    .clipped()
                if i < count - 1 {
                    dividerBar(index: i, totalWidth: availableWidth, geo: geo)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Vertical

    private func verticalLayout(count: Int, geo: GeometryProxy) -> some View {
        let totalHeight = geo.size.height
        let dividerTotal = SplitConstants.dividerWidth * CGFloat(count - 1)
        let availableHeight = max(totalHeight - dividerTotal, 0)

        return VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { i in
                SplitPaneWebArea(tab: splitTabs[i])
                    .frame(height: fractionHeight(i, available: availableHeight))
                    .clipped()
                if i < count - 1 {
                    dividerBarVertical(index: i, totalHeight: availableHeight, geo: geo)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Dividers

    private func dividerBar(index: Int, totalWidth: CGFloat, geo: GeometryProxy) -> some View {
        Rectangle()
            .fill(Color.hiveBorderSubtle)
            .frame(width: SplitConstants.dividerWidth)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        dragDividerHorizontal(index: index, translation: value.translation.width,
                                              totalWidth: totalWidth, geo: geo)
                    }
                    .onEnded { _ in dragStartFractions = fractions }
            )
            .onHover { hovering in
                if hovering { NSCursor.resizeLeftRight.push() }
                else { NSCursor.pop() }
            }
            .accessibilityLabel("Resize split pane divider")
    }

    private func dividerBarVertical(index: Int, totalHeight: CGFloat, geo: GeometryProxy) -> some View {
        Rectangle()
            .fill(Color.hiveBorderSubtle)
            .frame(height: SplitConstants.dividerWidth)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        dragDividerVertical(index: index, translation: value.translation.height,
                                            totalHeight: totalHeight, geo: geo)
                    }
                    .onEnded { _ in dragStartFractions = fractions }
            )
            .onHover { hovering in
                if hovering { NSCursor.resizeUpDown.push() }
                else { NSCursor.pop() }
            }
            .accessibilityLabel("Resize split pane divider")
    }

    // MARK: - Drag logic

    private func dragDividerHorizontal(index: Int, translation: CGFloat, totalWidth: CGFloat, geo: GeometryProxy) {
        guard fractions.count > index + 1 else { return }
        let total = geo.size.width
        guard total > 0 else { return }
        let deltaFraction = translation / total
        let left = dragStartFractions[index] + deltaFraction
        let right = dragStartFractions[index + 1] - deltaFraction
        let minFraction = SplitConstants.minPaneWidth / total
        guard left >= minFraction, right >= minFraction else { return }
        fractions[index] = left
        fractions[index + 1] = right
    }

    private func dragDividerVertical(index: Int, translation: CGFloat, totalHeight: CGFloat, geo: GeometryProxy) {
        guard fractions.count > index + 1 else { return }
        let total = geo.size.height
        guard total > 0 else { return }
        let deltaFraction = translation / total
        let top = dragStartFractions[index] + deltaFraction
        let bottom = dragStartFractions[index + 1] - deltaFraction
        let minFraction = SplitConstants.minPaneHeight / total
        guard top >= minFraction, bottom >= minFraction else { return }
        fractions[index] = top
        fractions[index + 1] = bottom
    }

    // MARK: - Fractions

    private func fractionWidth(_ index: Int, available: CGFloat) -> CGFloat {
        guard index < fractions.count, fractions.count > 0 else { return available }
        return available * fractions[index]
    }

    private func fractionHeight(_ index: Int, available: CGFloat) -> CGFloat {
        guard index < fractions.count, fractions.count > 0 else { return available }
        return available * fractions[index]
    }

    private func resetFractions() {
        let count = max(splitTabs.count, 1)
        let equal = 1.0 / CGFloat(count)
        fractions = Array(repeating: equal, count: count)
        dragStartFractions = fractions
    }
}
