import SwiftUI
import HiveCore

// MARK: - HiveSettingsView
//
// The browser's preferences window. Wired through SwiftUI's built-in `Settings` scene so
// macOS supplies the menu item, ⌘, shortcut, and window management for free.

struct HiveSettingsView: View {

    /// The live browser state. We read and mutate `state.prefs` directly, then ask the
    /// state to persist. This keeps the settings window in sync with the main window.
    let state: ChromeState

    @State private var selection: SettingsSection = .appearance
    @State private var showClearData: Bool = false
    @State private var settingsSearch = ""

    private var filteredSections: [SettingsSection] {
        let query = settingsSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Array(SettingsSection.allCases) }
        return SettingsSection.allCases.filter { section in
            section.title.localizedCaseInsensitiveContains(query)
                || section.keywords.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(filteredSections, id: \.self, selection: $selection) { section in
                Label(section.title, systemImage: section.icon)
                    .foregroundStyle(Color.hiveInk)
                    .accessibilityLabel(section.title)
                    .accessibilityAddTraits(selection == section ? .isSelected : [])
                    .tag(section)
            }
            .listStyle(.plain)
            .background(Color.hiveBackground)
            .searchable(text: $settingsSearch, placement: .sidebar, prompt: "Search settings")
            .onChange(of: settingsSearch) { _, _ in
                guard !filteredSections.contains(selection) else { return }
                selection = filteredSections.first ?? .appearance
            }
            .navigationSplitViewColumnWidth(160)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: HiveSpacing.s32) {
                    if filteredSections.isEmpty, !settingsSearch.isEmpty {
                        VStack(spacing: HiveSpacing.s8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(.hiveMist)
                            Text("No settings found")
                                .hiveType(.body)
                                .foregroundStyle(.hiveGraphite)
                            Text("Try a different search term.")
                                .hiveType(.caption2)
                                .foregroundStyle(.hiveMist)
                        }
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("No settings found. Try a different search term.")
                    } else {
                        content(for: selection)
                    }
                }
                .padding(HiveSpacing.s32)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(Color.hiveSurface)
        }
        .hiveSurface(.passiveChrome)
        .sheet(isPresented: $showClearData) {
            ClearDataView()
                .hiveSurface(.modal)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func content(for section: SettingsSection) -> some View {
        switch section {
        case .general:
            generalSection
        case .appearance:
            appearanceSection
        case .privacy:
            privacySection
        case .permissions:
            PermissionManagerView()
        case .passwords:
            PasswordManagerView()
        case .briefs:
            BriefBrowserView()
        case .studio:
            CodeStudioView()
        case .graph:
            HoneycombGraphView()
        case .boosts:
            BoostManagementView()
        case .privacyReport:
            PrivacyReportView()
        case .generator:
            PasswordGeneratorView()
        case .network:
            NetworkSettingsView()
        case .updates:
            UpdateSettingsView()
        case .siteData:
            SiteDataView()
        case .models:
            VStack(alignment: .leading, spacing: HiveSpacing.s48) {
                TavilySettingsView()
                VaneSettingsView()
                BYOKSettingsView()
            }
        case .shortcuts:
            shortcutsSection
        }
    }

    private var generalSection: some View {
        FormSection(title: "General") {
            // Google first — it is the shipped default and the Chrome convention;
            // the first segment reads as the default, so it must match the actual one.
            Picker("Default Search Engine", selection: searchEngineBinding) {
                Text("Google").tag("Google")
                Text("DuckDuckGo").tag("DuckDuckGo")
                Text("Bing").tag("Bing")
            }
            .pickerStyle(.segmented)

            Toggle("Show Bookmarks Sidebar on Launch", isOn: sidebarOpenBinding)
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s48) {
            themeSection

            FormSection(title: "Tab Layout") {
                Picker("Tab Layout", selection: layoutBinding) {
                    Text("Top Tabs").tag(TabPosition.top)
                    Text("Vertical Rail").tag(TabPosition.vertical)
                }
                .pickerStyle(.segmented)

                Picker("Tab Density", selection: densityBinding) {
                    Text("Compact").tag(TabDensity.compact)
                    Text("Standard").tag(TabDensity.standard)
                    Text("Spacious").tag(TabDensity.spacious)
                }
                .pickerStyle(.segmented)

                Toggle("Tree Mode (vertical layout only)", isOn: treeModeBinding)
                    .disabled(state.prefs.tabPosition == .top)
            }
        }
    }

    // MARK: - Theme Section (SPEC §23)

    private var themeSection: some View {
        FormSection(title: "Theme") {
            // Theme selector — segmented picker for the three modes.
            Picker("Appearance", selection: themeBinding) {
                ForEach(HiveTheme.allCases, id: \.self) { theme in
                    HStack(spacing: HiveSpacing.s8) {
                        Image(systemName: themeIcon(for: theme))
                            .foregroundStyle(.hiveAccent)
                            .font(HiveTypography.font(.panelTitleRegular))
                        Text(theme.displayName)
                    }
                    .tag(theme)
                }
            }
            .pickerStyle(.segmented)

            // Accent color palette — a horizontal row of color swatches.
            VStack(alignment: .leading, spacing: HiveSpacing.s8) {
                Text("Accent Color")
                    .hiveType(.chromeTitle)
                    .foregroundStyle(.hiveGraphite)

                LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(accentColors, id: \.0) { tokenName, color in
                        accentSwatch(tokenName: tokenName, color: color)
                    }
                }
            }

            // Live preview — a mini browser chrome mockup showing the selected theme.
            themePreview
        }
    }

    /// Predefined accent colors users can choose from, mapped to HiveColorToken names.
    private var accentColors: [(String, Color)] {
        [
            ("accent", Color(hex: "#FFC824")),    // Hive warm amber (default)
            ("gold", Color(hex: "#D4AF37")),
            ("ruby", Color(hex: "#E0115F")),
            ("emerald", Color(hex: "#50C878")),
            ("sapphire", Color(hex: "#0F52BA")),
            ("amethyst", Color(hex: "#9966CC")),
            ("rose", Color(hex: "#FF007F")),
            ("sky", Color(hex: "#87CEEB")),
            ("coral", Color(hex: "#FF7F50")),
            ("jade", Color(hex: "#00A86B")),
            ("lavender", Color(hex: "#B57EDC")),
            ("sunset", Color(hex: "#F4A460")),
            ("steel", Color(hex: "#4682B4")),
            ("mint", Color(hex: "#98FF98")),
        ]
    }

    private func accentSwatch(tokenName: String, color: Color) -> some View {
        let isSelected = state.prefs.accentColorName == tokenName
        return Circle()
            .fill(color)
            .frame(width: 28, height: 28)
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.hiveInk : Color.hiveBorderSubtle, lineWidth: isSelected ? 2 : 1)
            )
            .overlay(
                Group {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(HiveTypography.font(.caption3Bold))
                            .foregroundStyle(isSelected ? Color.hiveInk : .clear)
                    }
                }
            )
            .contentShape(Circle())
            .onTapGesture {
                state.setAccentColor(tokenName)
            }
            .help(tokenName.capitalized)
    }

    /// A mini browser preview showing the selected theme and accent color.
    private var themePreview: some View {
        VStack(spacing: 0) {
            // Mock tab bar
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: HiveRadius.r6)
                        .fill(idx == 0 ? Color(hiveSurfaceFor(isDarkPreview ? .dark : .light)) : Color(hiveSurfaceFor(isDarkPreview ? .dark : .light)).opacity(0.5))
                        .frame(height: 24)
                        .overlay(
                            Text("Tab \(idx + 1)")
                                .font(HiveTypography.font(.micro))
                                .foregroundStyle(idx == 0 ? Color(hiveInkFor(isDarkPreview ? .dark : .light)) : Color(hiveGraphiteFor(isDarkPreview ? .dark : .light)))
                        )
                }
                Spacer(minLength: 0)
            }
            .padding(6)
            .background(Color(hiveBackgroundFor(isDarkPreview ? .dark : .light)))

            // Mock address bar
            HStack {
                Circle()
                    .fill(Color(hiveAccentFor(isDarkPreview ? .dark : .light)))
                    .frame(width: 8, height: 8)
                RoundedRectangle(cornerRadius: HiveRadius.r4)
                    .fill(Color(hiveSurfaceFor(isDarkPreview ? .dark : .light)).opacity(0.6))
                    .frame(height: 16)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color(hiveBackgroundFor(isDarkPreview ? .dark : .light)))

            // Mock content
            Color(hiveSurfaceFor(isDarkPreview ? .dark : .light)).opacity(0.3)
                .frame(height: 40)
                .overlay(
                    Text(isDarkPreview ? "Dark" : "Light")
                        .font(HiveTypography.font(.micro))
                        .foregroundStyle(Color(hiveGraphiteFor(isDarkPreview ? .dark : .light)))
                )
        }
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r8))
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.r8)
                .stroke(Color.hiveBorderSubtle, lineWidth: 1)
        )
    }

    /// Whether the current theme selection should show a dark-mode preview.
    private var isDarkPreview: Bool {
        switch state.prefs.theme {
        case .hiveDark:  return true
        case .hiveLight: return false
        case .system:
            return NSApp.effectiveAppearance.name == .darkAqua
        }
    }

    private func themeIcon(for theme: HiveTheme) -> String {
        switch theme {
        case .system:   return "gearshape"
        case .hiveDark:  return "moon.fill"
        case .hiveLight: return "sun.max.fill"
        }
    }

    private var themeBinding: Binding<HiveTheme> {
        Binding(
            get: { state.prefs.theme },
            set: { state.setTheme($0) }
        )
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s32) {
            FormSection(title: "Content & Security") {
                Toggle("Block Trackers & Ads", isOn: contentBlockerBinding)
                Text("Uses a built-in blocklist to prevent cross-site tracking, cryptominers, and intrusive ads. Disabling it may speed up some sites but reduces privacy.")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)

                Divider().overlay(Color.hiveBorderSubtle)

                Toggle("Enforce HTTPS", isOn: httpsBinding)
                Text("Automatically upgrades HTTP connections to HTTPS. When upgrade fails, the insecure connection is blocked.")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)

                Divider().overlay(Color.hiveBorderSubtle)

                Toggle("Global Privacy Control", isOn: gpcBinding)
                Text("Sends the Sec-GPC: 1 header on every request, signaling \"Do Not Sell or Share My Personal Information.\" Required by CCPA. Most privacy-respecting sites honour this signal.")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
            }

            FormSection(title: "Accessibility") {
                Toggle("Honor Reduce Motion", isOn: reduceMotionBinding)
                Text("Respects the system-wide Reduce Motion setting. When enabled, Hive replaces spring animations with linear fades.")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
            }

            FormSection(title: "Data") {
                Toggle("Index History in Spotlight", isOn: spotlightBinding)
                Text("Allows browsing history to appear in Spotlight (⌘Space) search results. History remains local on your device — nothing is sent to Apple.")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)

                Divider().overlay(Color.hiveBorderSubtle)

                Button {
                    showClearData = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Browsing Data…")
                            .hiveType(.body)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(HiveTypography.font(.caption1Medium))
                    }
                    .foregroundStyle(.red)
                    .padding(.vertical, HiveSpacing.s4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var shortcutsSection: some View {
        FormSection(title: "Keyboard Shortcuts") {
            VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                ForEach(Array(shortcutItems.enumerated()), id: \.offset) { idx, item in
                    ShortcutRow(keys: item.keys, action: item.action, isAlternate: idx % 2 == 1)
                }
            }
        }
    }

    private var shortcutItems: [(keys: String, action: String)] {
        [
            ("⌘T", "New Tab"),
            ("⌘W", "Close Tab"),
            ("⌘⇧T", "Reopen Closed Tab"),
            ("⌘⇧N", "New Private Tab"),
            ("⌘L", "Focus Omnibar"),
            ("⌘⇧L", "Toggle Layout"),
            ("⌘[", "Back"),
            ("⌘]", "Forward"),
            ("⌘R", "Reload"),
            ("⌘F", "Find in Page"),
            ("⌘D", "Bookmark Page"),
            ("⌘⇧B", "Toggle Bookmark Bar"),
            ("⌘⇧O", "Tab Overview"),
            ("⌘K", "Command Palette"),
            ("⌘Y", "History"),
            ("⌘J", "Downloads"),
            ("⌘⌃F", "Fullscreen"),
            ("⌘+/⌥/0", "Zoom In/Out/Reset"),
            ("⌘P", "Print"),
            ("⌘⇧Delete", "Clear Browsing Data"),
            ("⌘1–⌘9", "Switch to Tab 1–9"),
            ("⌘⇧[/]", "Previous/Next Tab"),
        ]
    }

    private var contentBlockerBinding: Binding<Bool> {
        Binding(
            get: { state.prefs.contentBlockerEnabled },
            set: { state.setContentBlockerEnabled($0) }
        )
    }

    private var httpsBinding: Binding<Bool> {
        Binding(
            get: { state.prefs.enforceHTTPS },
            set: { state.setHTTPSEnforced($0) }
        )
    }

    private var gpcBinding: Binding<Bool> {
        Binding(
            get: { state.prefs.globalPrivacyControlEnabled },
            set: { state.setGlobalPrivacyControl($0) }
        )
    }

    private var spotlightBinding: Binding<Bool> {
        Binding(
            get: { SpotlightIndexer.shared.isEnabled },
            set: { SpotlightIndexer.shared.setEnabled($0) }
        )
    }

    // MARK: - Bindings

    private var searchEngineBinding: Binding<String> {
        Binding(
            get: { state.prefs.defaultSearchEngine },
            set: { state.setDefaultSearchEngine($0) }
        )
    }

    private var sidebarOpenBinding: Binding<Bool> {
        Binding(
            get: { state.prefs.sidebarOpen },
            set: { state.setSidebarOpen($0) }
        )
    }

    private var layoutBinding: Binding<TabPosition> {
        Binding(
            get: { state.prefs.tabPosition },
            set: { state.setLayout($0) }
        )
    }

    private var densityBinding: Binding<TabDensity> {
        Binding(
            get: { state.prefs.tabDensity },
            set: { state.setDensity($0) }
        )
    }

    private var treeModeBinding: Binding<Bool> {
        Binding(
            get: { state.prefs.isTreeMode },
            set: { state.setTreeMode($0) }
        )
    }

    private var reduceMotionBinding: Binding<Bool> {
        Binding(
            get: { state.prefs.honorReduceMotion },
            set: { state.setHonorReduceMotion($0) }
        )
    }
}

// MARK: - Settings sections

private enum SettingsSection: String, CaseIterable {
    case general
    case appearance
    case privacy
    case privacyReport
    case passwords
    case generator
    case permissions
    case network
    case briefs
    case studio
    case graph
    case boosts
    case updates
    case siteData
    case models
    case shortcuts

    var title: String {
        switch self {
        case .general:    return "General"
        case .appearance: return "Appearance"
        case .privacy:    return "Privacy"
        case .privacyReport: return "Privacy Report"
        case .passwords:  return "Passwords"
        case .generator:  return "Password Gen"
        case .permissions:return "Permissions"
        case .network:    return "Network"
        case .briefs:     return "Briefs"
        case .studio:     return "Studio"
        case .graph:      return "Graph"
        case .boosts:     return "Boosts"
        case .updates:    return "Updates"
        case .siteData:   return "Site Data"
        case .models:     return "Models"
        case .shortcuts:  return "Shortcuts"
        }
    }

    var keywords: [String] {
        switch self {
        case .general: return ["search", "engine", "bookmarks", "sidebar"]
        case .appearance: return ["theme", "color", "tabs", "layout", "density", "motion"]
        case .privacy: return ["trackers", "ads", "https", "gpc", "data", "clear"]
        case .privacyReport: return ["blocked", "trackers", "report", "protection"]
        case .passwords: return ["keychain", "credentials", "login"]
        case .generator: return ["generate", "strong", "password"]
        case .permissions: return ["camera", "microphone", "location", "site access"]
        case .network: return ["proxy", "dns", "network", "connection"]
        case .briefs: return ["research", "sources", "saved briefs"]
        case .studio: return ["code", "project", "developer"]
        case .graph: return ["honeycomb", "memory", "knowledge", "links"]
        case .boosts: return ["css", "js", "dark mode", "site styles", "paint"]
        case .updates: return ["version", "release", "update"]
        case .siteData: return ["cookies", "storage", "cache", "website data"]
        case .models: return ["AI", "Tavily", "Vane", "BYOK", "provider"]
        case .shortcuts: return ["keyboard", "keys", "commands"]
        }
    }

    var icon: String {
        switch self {
        case .general:    return "gear"
        case .appearance: return "paintbrush"
        case .privacy:    return "lock.shield"
        case .privacyReport: return "shield.checkered"
        case .passwords:  return "key"
        case .generator:  return "key.horizontal"
        case .permissions:return "hand.raised"
        case .network:    return "network"
        case .briefs:     return "doc.text.magnifyingglass"
        case .studio:     return "hammer"
        case .graph:      return "point.3.connected.trianglepath.dotted"
        case .boosts:     return "paintbrush.pointed"
        case .updates:    return "arrow.triangle.2.circlepath"
        case .siteData:   return "externaldrive"
        case .models:     return "cpu"
        case .shortcuts:  return "command"
        }
    }
}

// MARK: - ShortcutRow

private struct ShortcutRow: View {
    let keys: String
    let action: String
    let isAlternate: Bool

    init(keys: String, action: String, isAlternate: Bool = false) {
        self.keys = keys
        self.action = action
        self.isAlternate = isAlternate
    }

    var body: some View {
        HStack(spacing: HiveSpacing.s12) {
            Text(keys)
                .hiveType(.bodySmall)
                .monospaced()
                .foregroundStyle(.hiveGraphite)
                .frame(width: 100, alignment: .leading)
            Text(action)
                .hiveType(.body)
                .foregroundStyle(.hiveInk)
            Spacer()
        }
        .padding(.horizontal, HiveSpacing.s8)
        .padding(.vertical, HiveSpacing.s4)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r6)
                .fill(isAlternate ? Color.hiveSurface.opacity(0.4) : Color.clear)
        )
    }
}

struct FormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s16) {
            Text(title)
                .hiveType(.chromeTitle)
                .foregroundStyle(Color.hiveInk)

            VStack(alignment: .leading, spacing: HiveSpacing.s16) {
                content
            }
            .padding(HiveSpacing.s16)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r12)
                    .fill(Color.hiveSurfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HiveRadius.r12)
                    .stroke(Color.hiveBorderSubtle, lineWidth: 1)
            )
        }
    }
}
