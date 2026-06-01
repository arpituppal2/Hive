import Foundation
import HiveCore
import HiveDesignSystem
#if canImport(SwiftUI) && canImport(WidgetKit)
import SwiftUI
import WidgetKit
#endif

public enum HiveWidgetFamily: String, CaseIterable, Sendable {
    case small
    case medium
    case large
    case extraLarge
    case accessoryCircular
    case accessoryRectangular
    case accessoryInline
}

public enum HiveWidgetRenderingMode: String, CaseIterable, Sendable {
    case fullColor
    case accented
    case vibrant
}

public enum HiveWidgetAppearance: String, CaseIterable, Sendable {
    case fullColor
    case clear
    case tinted
    case accented
    case vibrant
    case lowLight
}

public struct HiveWidgetSnapshot: Hashable, Sendable {
    public var family: HiveWidgetFamily
    public var stateText: String
    public var memoryCount: Int
    public var claimTitles: [String]
    public var graphTextureUpdatedAt: Date
    public var description: String
    public var deepLinkTarget: String
    public var renderingMode: HiveWidgetRenderingMode
    public var supportedAppearances: Set<HiveWidgetAppearance>
    public var redactsPrivateContentWhenLocked: Bool
    public var interactiveTargetCount: Int
    public var usesColorAsOnlySignal: Bool

    public init(
        family: HiveWidgetFamily,
        stateText: String,
        memoryCount: Int,
        claimTitles: [String],
        graphTextureUpdatedAt: Date = Date(),
        description: String = "See what Hive recently learned.",
        deepLinkTarget: String = "hive://graph",
        renderingMode: HiveWidgetRenderingMode = .fullColor,
        supportedAppearances: Set<HiveWidgetAppearance> = Set(HiveWidgetAppearance.allCases),
        redactsPrivateContentWhenLocked: Bool = true,
        interactiveTargetCount: Int = 1,
        usesColorAsOnlySignal: Bool = false
    ) {
        self.family = family
        self.stateText = stateText
        self.memoryCount = memoryCount
        self.claimTitles = Array(claimTitles.map(SourcePresentationModel.cleanTitle).prefix(HiveWidgetDesignPolicy.maximumVisibleItems))
        self.graphTextureUpdatedAt = graphTextureUpdatedAt
        self.description = description
        self.deepLinkTarget = deepLinkTarget
        self.renderingMode = renderingMode
        self.supportedAppearances = supportedAppearances
        self.redactsPrivateContentWhenLocked = redactsPrivateContentWhenLocked
        self.interactiveTargetCount = interactiveTargetCount
        self.usesColorAsOnlySignal = usesColorAsOnlySignal
    }

    public var isGlanceable: Bool {
        claimTitles.count <= HiveWidgetDesignPolicy.maximumVisibleItems
            && HiveWidgetDesignPolicy.descriptionIsValid(description)
            && !deepLinkTarget.isEmpty
            && interactiveTargetCount <= HiveWidgetDesignPolicy.maximumInteractiveTargets(for: family)
            && !usesColorAsOnlySignal
    }

    public var placeholderTitles: [String] {
        claimTitles.isEmpty ? ["Add sources to Field"] : claimTitles
    }

    public var supportsRequiredAppearances: Bool {
        supportedAppearances.isSuperset(of: Set(HiveWidgetAppearance.allCases))
    }
}

public enum HiveWidgetDesignPolicy {
    public static let maximumVisibleItems = 3
    public static let maximumInteractiveTargets = 2
    public static let usesSystemFontAndSFSymbols = true
    public static let marginsAreConcentricWithContainer = true
    public static let avoidsAppLikeLayouts = true
    public static let supportsRealisticPreviews = true
    public static let supportsAlwaysOnLowLuminanceContrast = true
    public static let neverUsesColorAsOnlySignal = true
    public static let keepsComplexityInsideMainApp = true

    public static func maximumInteractiveTargets(for family: HiveWidgetFamily) -> Int {
        switch family {
        case .accessoryInline:
            return 1
        case .accessoryCircular, .accessoryRectangular:
            return 1
        case .small:
            return 1
        case .medium, .large, .extraLarge:
            return maximumInteractiveTargets
        }
    }

    public static func descriptionIsValid(_ description: String) -> Bool {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lower = trimmed.lowercased()
        let actionVerbs = ["see", "open", "review", "ask", "capture", "show", "track", "resume"]
        return actionVerbs.contains { lower.hasPrefix($0) }
            && !lower.hasPrefix("this widget")
            && !lower.hasPrefix("use this widget")
            && !lower.hasPrefix("add this widget")
    }
}

#if canImport(SwiftUI) && canImport(WidgetKit)
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct HiveMemoryWidgetEntry: TimelineEntry {
    public var date: Date
    public var snapshot: HiveWidgetSnapshot

    public init(date: Date = Date(), snapshot: HiveWidgetSnapshot) {
        self.date = date
        self.snapshot = snapshot
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct HiveMemoryTimelineProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> HiveMemoryWidgetEntry {
        HiveMemoryWidgetEntry(snapshot: placeholderSnapshot(family: widgetFamily(from: context.family)))
    }

    public func getSnapshot(in context: Context, completion: @escaping (HiveMemoryWidgetEntry) -> Void) {
        completion(HiveMemoryWidgetEntry(snapshot: placeholderSnapshot(family: widgetFamily(from: context.family))))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<HiveMemoryWidgetEntry>) -> Void) {
        let entry = HiveMemoryWidgetEntry(snapshot: placeholderSnapshot(family: widgetFamily(from: context.family)))
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
    }

    private func placeholderSnapshot(family: HiveWidgetFamily) -> HiveWidgetSnapshot {
        HiveWidgetSnapshot(
            family: family,
            stateText: "Ready to learn",
            memoryCount: 0,
            claimTitles: ["Add sources to Field"],
            description: "Open Hive to add a source."
        )
    }

    private func widgetFamily(from family: WidgetFamily) -> HiveWidgetFamily {
        switch family {
        case .systemSmall:
            return .small
        case .systemMedium:
            return .medium
        case .systemLarge:
            return .large
        case .systemExtraLarge:
            return .extraLarge
        #if os(watchOS)
        case .accessoryCircular:
            return .accessoryCircular
        case .accessoryRectangular:
            return .accessoryRectangular
        case .accessoryInline:
            return .accessoryInline
        #endif
        default:
            return .small
        }
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct HiveMemoryWidget: Widget {
    public let kind = "HiveMemoryWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HiveMemoryTimelineProvider()) { entry in
            HiveMemoryWidgetView(entry: entry)
        }
        .configurationDisplayName("Hive")
        .description("See recent Hive memory state.")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryCircular, .accessoryRectangular, .accessoryInline]
        #else
        [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]
        #endif
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
private struct HiveMemoryWidgetView: View {
    var entry: HiveMemoryWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            #if os(watchOS)
            switch family {
            case .accessoryInline:
                Text("\(entry.snapshot.memoryCount) Hive memories")
            case .accessoryCircular:
                VStack(spacing: 2) {
                    HiveSymbol(.hiveGraph, size: 16, active: true)
                    Text("\(entry.snapshot.memoryCount)")
                        .font(.caption2.weight(.semibold))
                }
            default:
                standardContent
            }
            #else
            standardContent
            #endif
        }
        .containerBackground(for: .widget) {
            HiveColorToken.backgroundMid.color
        }
        .widgetURL(URL(string: entry.snapshot.deepLinkTarget))
    }

    private var standardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                HiveSymbol(.hiveGraph, size: 16, active: true)
                Text("Hive")
                    .font(.headline)
            }
            Text(entry.snapshot.stateText)
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(entry.snapshot.placeholderTitles.prefix(2), id: \.self) { title in
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}
#endif
