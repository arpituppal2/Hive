import SwiftUI
import HiveCore

// MARK: - OnboardingStep

private enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case importData = 1
    case layout = 2
}

// MARK: - OnboardingView

/// A minimal, browser-first first-run sheet. It appears over the real browser window so the
/// user can immediately see Hive as a browser. No full-screen cards, no archive ideology,
/// no forced AI education. Each step is skippable and persists its choice.
struct OnboardingView: View {

    @Environment(ChromeState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: OnboardingStep = .welcome
    @State private var detectedBrowsers: [ImportableBrowser] = []
    @State private var selectedBrowserID: String? = nil
    @State private var importResult: ImportResult? = nil
    @State private var isImporting = false

    private var selectedBrowser: ImportableBrowser? {
        detectedBrowsers.first { $0.id == selectedBrowserID }
    }

    var body: some View {
        ZStack {
            // Dim the live browser chrome just enough to focus attention on the sheet,
            // but keep the browser silhouette visible so it still reads as a browser.
            // Tapping the dim dismisses onboarding entirely.
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { state.completeOnboarding() }

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 80)
                sheet
                Spacer()
            }
            .padding(.horizontal, HiveSpacing.s48)
        }
        .onAppear {
            detectedBrowsers = ImportableBrowser.supportedBrowsers.filter(\.isDetected)
        }
    }

    // MARK: Sheet

    private var sheet: some View {
        VStack(spacing: HiveSpacing.s24) {
            HStack {
                Spacer()
                Button(action: { state.completeOnboarding() }) {
                    Image(systemName: "xmark")
                        .font(HiveTypography.font(.caption1Medium))
                        .foregroundStyle(.hiveGraphite)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip onboarding")
                .help("Skip onboarding")
            }
            stepIndicator
            stepContent
        }
        .padding(HiveSpacing.s24)
        .frame(maxWidth: 480)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r16)
                .fill(Color.hiveSurface.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: HiveRadius.r16)
                        .stroke(Color.hiveBorderSubtle, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.20), radius: 32, x: 0, y: 12)
    }

    private let stepLabels: [OnboardingStep: String] = [
        .welcome: "Welcome",
        .importData: "Import",
        .layout: "Layout"
    ]

    private var stepIndicator: some View {
        VStack(spacing: HiveSpacing.s8) {
            HStack(spacing: HiveSpacing.s8) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? Color.hiveAccent : Color.hiveBorderSubtle)
                        .frame(width: s == step ? 20 : 6, height: 6)
                        .animation(reduceMotion ? nil : .hiveMicro, value: step)
                }
            }
            // Step label — Apple-setup-assistant style.
            Text(stepLabels[step] ?? "")
                .hiveType(.caption2)
                .foregroundStyle(Color.hiveGraphite)
                .animation(reduceMotion ? nil : .hiveMicro, value: step)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count), \(stepLabels[step] ?? "")")
    }

    @ViewBuilder private var stepContent: some View {
        switch step {
        case .welcome:
            welcomeStep
        case .importData:
            importStep
        case .layout:
            layoutStep
        }
    }

    // MARK: Welcome

    private var welcomeStep: some View {
        VStack(spacing: HiveSpacing.s24) {
            // Branded hexagon icon — the Hive identity mark.
            ZStack {
                RoundedRectangle(cornerRadius: HiveRadius.r12)
                    .fill(
                        LinearGradient(
                            colors: [Color.hiveAccent, Color.hiveAccent.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.hiveAccent.opacity(0.25), radius: 16, x: 0, y: 4)

                Image(systemName: "hexagon.fill")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.bottom, HiveSpacing.s4)

            VStack(spacing: HiveSpacing.s4) {
                Text("Welcome to Hive")
                    .hiveType(.brandTitle)
                    .foregroundStyle(Color.hiveInk)
                    .multilineTextAlignment(.center)

                Text("A fast, familiar browser that remembers your work.\nBrowse normally — advanced assistance unlocks when you need it.")
                    .hiveType(.body)
                    .foregroundStyle(Color.hiveGraphite)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Button("Get Started") {
                withAnimation(reduceMotion ? nil : .hiveStandard) { step = .importData }
            }
            .buttonStyle(HivePrimaryButtonStyle())
            .padding(.top, HiveSpacing.s4)

            Button("Skip onboarding") {
                state.completeOnboarding()
            }
            .buttonStyle(HiveSecondaryButtonStyle())
        }
    }

    // MARK: Import

    private var importStep: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s16) {
            VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                Text("Import from another browser?")
                    .hiveType(.body)
                    .foregroundStyle(Color.hiveInk)
                Text("Bring your bookmarks and history. You can skip and do this later in Settings.")
                    .hiveType(.bodySmall)
                    .foregroundStyle(Color.hiveGraphite)
            }

            if detectedBrowsers.isEmpty {
                Text("No other browsers detected on this Mac.")
                    .hiveType(.bodySmall)
                    .foregroundStyle(Color.hiveGraphite)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, HiveSpacing.s16)
            } else {
                VStack(spacing: HiveSpacing.s8) {
                    ForEach(detectedBrowsers) { browser in
                        browserRow(browser)
                    }
                }
            }

            if let result = importResult, !result.isEmpty {
                HStack(spacing: HiveSpacing.s8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.hiveAccent)
                    Text("Imported \(result.bookmarks) bookmarks and \(result.history) history items.")
                        .hiveType(.caption1)
                        .foregroundStyle(Color.hiveGraphite)
                }
                .padding(.vertical, HiveSpacing.s4)
            }

            HStack(spacing: HiveSpacing.s16) {
                Button("Skip") {
                    withAnimation(reduceMotion ? nil : .hiveStandard) { step = .layout }
                }
                .buttonStyle(HiveSecondaryButtonStyle())

                Spacer()

                Button(isImporting ? "Importing…" : (importResult != nil ? "Continue" : "Import")) {
                    importAndContinue()
                }
                .buttonStyle(HivePrimaryButtonStyle())
                .disabled(isImporting || importResult != nil || selectedBrowserID == nil)
            }
            .padding(.top, HiveSpacing.s8)
        }
    }

    private func browserRow(_ browser: ImportableBrowser) -> some View {
        let selected = selectedBrowserID == browser.id
        return Button {
            withAnimation(reduceMotion ? nil : .hiveMicro) { selectedBrowserID = browser.id }
        } label: {
            HStack(spacing: HiveSpacing.s12) {
                browserIconView(for: browser.id)

                VStack(alignment: .leading, spacing: 2) {
                    Text(browser.name)
                        .hiveType(.chromeTitle)
                        .foregroundStyle(Color.hiveInk)
                    Text("Detected")
                        .hiveType(.caption2)
                        .foregroundStyle(Color.hiveGraphite)
                }

                Spacer()

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.hiveAccent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, HiveSpacing.s12)
            .padding(.vertical, HiveSpacing.s8)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r8)
                    .fill(selected ? Color.hiveAccent.opacity(0.10) : Color.hiveSurfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HiveRadius.r8)
                    .stroke(selected ? Color.hiveAccent : Color.hiveBorderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(browser.name), Detected")
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(reduceMotion ? nil : .hiveMicro, value: selected)
    }

    /// Renders a styled browser icon with appropriate SF Symbol and background tint.
    private func browserIconView(for id: String) -> some View {
        let (symbol, tint): (String, Color) = {
            switch id {
            case "safari":   return ("safari", Color.blue)
            case "chrome":   return ("globe", Color.green)
            case "firefox":  return ("flame", Color.orange)
            case "brave":    return ("shield.fill", Color.orange)
            case "arc":      return ("arcade.stick.console", Color.purple)
            case "edge":     return ("globe", Color.teal)
            default:         return ("globe", Color.hiveGraphite)
            }
        }()
        return ZStack {
            RoundedRectangle(cornerRadius: HiveRadius.r4)
                .fill(tint.opacity(0.12))
                .frame(width: 28, height: 28)
            Image(systemName: symbol)
                .font(HiveTypography.font(.panelTitle))
                .foregroundStyle(tint)
        }
    }

    private func importAndContinue() {
        if importResult != nil {
            withAnimation(reduceMotion ? nil : .hiveStandard) { step = .layout }
            return
        }
        guard let browser = selectedBrowser else { return }
        isImporting = true

        if let preset = browser.preset {
            state.applyPreset(preset)
        }

        ImportableBrowser.mergeHandler = { [weak state] bookmarks, history in
            var prefs = state?.prefs ?? ChromeUserPrefs.defaults
            let existingURLs = Set(prefs.bookmarks.compactMap { $0.url })
            for bm in bookmarks where !existingURLs.contains(bm.url) {
                prefs.bookmarks.append(Bookmark(title: bm.title, url: bm.url))
            }
            let historyURLs = Set(prefs.historyEntries.map { $0.url })
            for entry in history where !historyURLs.contains(entry.url) {
                prefs.historyEntries.append(
                    BrowsingHistoryEntry(url: entry.url, title: entry.title,
                                         visitDate: entry.visitDate)
                )
            }
            let histCap = Array<BrowsingHistoryEntry>.hiveHistoryCap
            if prefs.historyEntries.count > histCap {
                prefs.historyEntries = Array(prefs.historyEntries.prefix(histCap))
            }
            state?.prefs = prefs
        }

        Task {
            let result = await browser.performImport()
            await MainActor.run {
                importResult = result
                isImporting = false
                ImportableBrowser.mergeHandler = nil
                withAnimation(reduceMotion ? nil : .hiveStandard.delay(0.4)) {
                    step = .layout
                }
            }
        }
    }

    // MARK: Layout

    private var layoutStep: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s16) {
            VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                Text("Choose your layout")
                    .hiveType(.body)
                    .foregroundStyle(Color.hiveInk)
                Text("Pick a layout that feels like home. You can change this anytime.")
                    .hiveType(.bodySmall)
                    .foregroundStyle(Color.hiveGraphite)
            }

            VStack(spacing: HiveSpacing.s8) {
                layoutCard(title: "Hive Default",
                           subtitle: "Vertical rail, clean and focused",
                           icon: "sidebar.left",
                           position: .vertical)
                layoutCard(title: "Safari / Chrome",
                           subtitle: "Horizontal tabs on top",
                           icon: "menubar.rectangle",
                           position: .top)
            }

            HStack(spacing: HiveSpacing.s16) {
                Button("Back") {
                    withAnimation(reduceMotion ? nil : .hiveStandard) { step = .importData }
                }
                .buttonStyle(HiveSecondaryButtonStyle())

                Spacer()

                Button("Start Browsing") {
                    state.completeOnboarding()
                }
                .buttonStyle(HivePrimaryButtonStyle())
            }
            .padding(.top, HiveSpacing.s8)
        }
    }

    private func layoutCard(title: String, subtitle: String, icon: String, position: TabPosition) -> some View {
        let selected = state.prefs.tabPosition == position
        return Button {
            withAnimation(reduceMotion ? nil : .hiveStandard) { state.setLayout(position) }
        } label: {
            HStack(spacing: HiveSpacing.s12) {
                // Layout preview — a mini visual mockup of the tab layout.
                layoutPreview(position: position, selected: selected)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .hiveType(.chromeTitle)
                        .foregroundStyle(Color.hiveInk)
                    Text(subtitle)
                        .hiveType(.caption2)
                        .foregroundStyle(Color.hiveGraphite)
                }

                Spacer()

                if selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.hiveAccent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, HiveSpacing.s12)
            .padding(.vertical, HiveSpacing.s12)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r8)
                    .fill(selected ? Color.hiveAccent.opacity(0.08) : Color.hiveSurfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HiveRadius.r8)
                    .stroke(selected ? Color.hiveAccent : Color.hiveBorderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(reduceMotion ? nil : .hiveMicro, value: selected)
    }

    /// A miniature visual preview of the tab layout — vertical rail or horizontal top tabs.
    private func layoutPreview(position: TabPosition, selected: Bool) -> some View {
        let accent = selected ? Color.hiveAccent : Color.hiveBorderSubtle
        return ZStack(alignment: .topLeading) {
            // Browser window chrome
            RoundedRectangle(cornerRadius: HiveRadius.r4)
                .fill(Color.hiveSurfaceElevated)
                .frame(width: 44, height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: HiveRadius.r4)
                        .stroke(accent.opacity(0.4), lineWidth: 1)
                )

            if position == .vertical {
                // Vertical rail — thin bar on the left
                RoundedRectangle(cornerRadius: 1)
                    .fill(accent)
                    .frame(width: 6, height: 22)
                    .offset(x: 5, y: 5)
            } else {
                // Horizontal top tabs — bar at the top
                RoundedRectangle(cornerRadius: 1)
                    .fill(accent)
                    .frame(width: 32, height: 5)
                    .offset(x: 6, y: 5)
            }
        }
    }

    // MARK: Button styles

    private struct HivePrimaryButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .hiveType(.chromeButton)
                .foregroundStyle(Color.black)
                .padding(.horizontal, HiveSpacing.s16)
                .padding(.vertical, HiveSpacing.s8)
                .background(
                    RoundedRectangle(cornerRadius: HiveRadius.r6)
                        .fill(Color.hiveAccent.opacity(configuration.isPressed ? 0.85 : 1.0))
                )
        }
    }

    private struct HiveSecondaryButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .hiveType(.chromeButton)
                .foregroundStyle(Color.hiveInk.opacity(configuration.isPressed ? 0.6 : 0.8))
                .padding(.horizontal, HiveSpacing.s16)
                .padding(.vertical, HiveSpacing.s8)
                .background(Color.clear)
        }
    }
}
