import SwiftUI
import HiveCore

// MARK: - OnboardingSheet
//
// First-launch onboarding: 3-step wizard shown once when the app first opens.
//   Step 1: Import — detect installed browsers, offer to import bookmarks
//   Step 2: Theme — pick accent color
//   Step 3: Start — summary and launch CTA
//
// Guarded by UserDefaults "HiveHasSeenOnboarding" flag.

struct OnboardingSheet: View {
    @Environment(BrowserState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: Int = 0
    @State private var detectedBrowsers: [(String, String, Int, Int)] = []
    @State private var selectedBrowsers: Set<String> = []
    @State private var isImporting: Bool = false
    @State private var importedBookmarkCount: Int = 0
    @State private var importedHistoryCount: Int = 0
    @State private var importError: String? = nil
    @State private var selectedColorHex: String = "#F5A623"

    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i <= step ? Color.hiveAccent : Color.secondary.opacity(0.2))
                        .frame(width: 8, height: 8)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: step)
                }
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            // Step content
            Group {
                switch step {
                case 0: importStep
                case 1: themeStep
                default: startStep
                }
            }
            .frame(height: 340)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: step)

            // Bottom actions
            HStack {
                if step > 0 {
                    Button("Back") { withAnimation { step -= 1 } }
                        .buttonStyle(.borderless)
                        .font(HiveDesign.Typography.panelTitleMedium)
                }
                Spacer()
                if step < totalSteps - 1 {
                    Button("Next") { withAnimation { step += 1 } }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.hiveAccent)
                        .font(HiveDesign.Typography.panelTitle)
                } else {
                    Button("Start Browsing") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.hiveAccent)
                    .font(HiveDesign.Typography.panelTitle)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 480, height: 480)
        .background(HiveDesign.Material.panel)
        .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 6)
        .onAppear { detectBrowsers() }
    }

    // MARK: - Step 1: Import

    private var importStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.branch")
                .font(HiveDesign.Typography.heroDisplayXL)
                .foregroundStyle(Color.hiveAccent)

            Text("Import Your Browser Data")
                .font(HiveDesign.Typography.headingXL)

            Text("Bring your bookmarks and history from other browsers so you feel right at home. Nothing leaves your device.")
                .font(HiveDesign.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)

            if detectedBrowsers.isEmpty && !isImporting {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Detecting browsers...")
                        .font(HiveDesign.Typography.sidebarItem)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 8)
            } else if isImporting {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Importing bookmarks and history...")
                        .font(HiveDesign.Typography.bodyMedium)
                    let importedCount = importedBookmarkCount + importedHistoryCount
                    if importedCount > 0 {
                        Text("\(importedCount) imported so far")
                            .font(HiveDesign.Typography.sidebarItem)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 12)
            } else {
                VStack(spacing: 8) {
                    ForEach(detectedBrowsers, id: \.0) { browser in
                        browserRow(browser)
                    }
                }
                .padding(.horizontal, 48)

                if !selectedBrowsers.isEmpty {
                    Button(action: importSelected) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import \(selectedBrowsers.count) browser\(selectedBrowsers.count > 1 ? "s" : "")")
                        }
                        .font(HiveDesign.Typography.bodyMedium)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.hiveAccent)
                    .disabled(isImporting)
                }
            }

            if let error = importError {
                Text(error)
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            }
        }
    }

    private func browserRow(_ browser: (String, String, Int, Int)) -> some View {
        Button(action: { toggleBrowser(browser.0) }) {
            HStack(spacing: 10) {
                Image(systemName: browser.1)
                    .font(HiveDesign.Typography.panelTitleMedium)
                    .foregroundStyle(selectedBrowsers.contains(browser.0) ? Color.hiveAccent : .secondary)
                    .frame(width: 22)

                Text(browser.0)
                    .font(HiveDesign.Typography.bodyMedium)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(browser.2) bookmarks · \(browser.3) history")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.tertiary)

                if selectedBrowsers.contains(browser.0) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(HiveDesign.Typography.bodyLarge)
                        .foregroundStyle(Color.hiveAccent)
                } else {
                    Image(systemName: "circle")
                        .font(HiveDesign.Typography.bodyLarge)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selectedBrowsers.contains(browser.0)
                        ? HiveDesign.Surface.level2
                        : Color.secondary.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    private func toggleBrowser(_ name: String) {
        if selectedBrowsers.contains(name) {
            selectedBrowsers.remove(name)
        } else {
            selectedBrowsers.insert(name)
        }
    }

    private func importSelected() {
        isImporting = true
        importError = nil
        importedBookmarkCount = 0
        importedHistoryCount = 0

        let selectedNames = selectedBrowsers
        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                let all = BrowserImport.detectAvailableBrowsers()
                var bookmarks: [ImportedBookmark] = []
                var histories: [ImportedHistoryEntry] = []
                var errors: [String] = []

                for browser in all where selectedNames.contains(browser.name) {
                    if browser.bookmarks.isEmpty && browser.history.isEmpty {
                        errors.append("\(browser.name): no bookmarks or history found")
                        continue
                    }
                    bookmarks.append(contentsOf: browser.bookmarks)
                    histories.append(contentsOf: browser.history)
                }
                return (bookmarks, histories, errors)
            }.value

            let counts = state.mergeImportedData(bookmarks: result.0, history: result.1)
            importedBookmarkCount = counts.bookmarks
            importedHistoryCount = counts.history
            isImporting = false
            let importedCount = counts.bookmarks + counts.history
            if !result.2.isEmpty && importedCount == 0 {
                importError = result.2.joined(separator: "; ")
            } else {
                importError = nil
            }
        }
    }

    // MARK: - Step 2: Theme

    private var themeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "paintpalette.fill")
                .font(HiveDesign.Typography.heroDisplayXL)
                .foregroundStyle(Color.hiveAccent)

            Text("Choose Your Theme")
                .font(HiveDesign.Typography.headingXL)

            Text("Pick an accent color for Hive. You can always change this later in Settings.")
                .font(HiveDesign.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52, maximum: 56), spacing: 14)], spacing: 14) {
                ForEach(ThemePreset.presets) { preset in
                    Button(action: { selectedColorHex = preset.colorHex }) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: preset.colorHex) ?? Color.hiveAccent)
                                .frame(width: 44, height: 44)
                                .shadow(color: (Color(hex: preset.colorHex) ?? Color.hiveAccent).opacity(0.3),
                                        radius: 8, x: 0, y: 4)

                            if selectedColorHex == preset.colorHex {
                                Image(systemName: "checkmark")
                                    .font(HiveDesign.Typography.panelTitleBold)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(preset.name)
                }
            }
            .padding(.horizontal, 48)
            .padding(.top, 8)
        }
    }

    // MARK: - Step 3: Start

    private var startStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "hexagon.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.hiveAccent, Color.orange],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

            Text("You're All Set")
                .font(HiveDesign.Typography.headingXL)

            VStack(spacing: 8) {
                summaryRow("checkmark.circle.fill", "Bookmarks imported: \(importedBookmarkCount)")
                summaryRow("clock.arrow.circlepath", "History imported: \(importedHistoryCount)")
                summaryRow("paintpalette.fill", "Theme: \(ThemePreset.presets.first(where: { $0.colorHex == selectedColorHex })?.name ?? "Hive Amber")")
                summaryRow("shield.checkered", "Tracker blocking and Safe Browsing are enabled")
            }
            .padding(.horizontal, 48)

            Text("Your browser is ready. Start exploring the web with Hive.")
                .font(HiveDesign.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
        }
    }

    private func summaryRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(HiveDesign.Typography.body)
                .foregroundStyle(.green)
                .frame(width: 18)
            Text(text)
                .font(HiveDesign.Typography.body)
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    // MARK: - Completion

    private func completeOnboarding() {
        state.setAccentColor(hex: selectedColorHex)
        UserDefaults.standard.set(true, forKey: "HiveHasSeenOnboarding")
        dismiss()
    }

    private func detectBrowsers() {
        DispatchQueue.global(qos: .userInitiated).async {
            let all = BrowserImport.detectAvailableBrowsers()
            let mapped = all.map { ($0.name, $0.icon, $0.bookmarkCount, $0.historyCount) }
            DispatchQueue.main.async { detectedBrowsers = mapped }
        }
    }
}
