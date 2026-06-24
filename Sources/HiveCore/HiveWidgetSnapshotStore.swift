import Foundation

public struct HiveWidgetSnapshotPayload: Codable, Hashable, Sendable {
    public var stateText: String
    public var memoryCount: Int
    public var claimTitles: [String]
    public var updatedAt: Date

    public init(
        stateText: String,
        memoryCount: Int,
        claimTitles: [String],
        updatedAt: Date = Date()
    ) {
        self.stateText = stateText
        self.memoryCount = memoryCount
        self.claimTitles = claimTitles
        self.updatedAt = updatedAt
    }

    public static var empty: HiveWidgetSnapshotPayload {
        HiveWidgetSnapshotPayload(
            stateText: "Ready to learn",
            memoryCount: 0,
            claimTitles: ["Add sources to Field"]
        )
    }
}

public enum HiveWidgetSnapshotStore {
    public static let fileName = "widget-snapshot.json"

    public static func fileURL(root: URL) -> URL {
        root.appendingPathComponent(fileName)
    }

    public static func save(_ payload: HiveWidgetSnapshotPayload, root: URL) {
        let url = fileURL(root: root)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    public static func load(root: URL) -> HiveWidgetSnapshotPayload {
        let url = fileURL(root: root)
        guard let data = try? Data(contentsOf: url) else { return .empty }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(HiveWidgetSnapshotPayload.self, from: data)) ?? .empty
    }

    public static func makePayload(
        claimCount: Int,
        sourceCount: Int,
        recentClaimTitles: [String]
    ) -> HiveWidgetSnapshotPayload {
        let state: String
        if sourceCount == 0 {
            state = "Add sources to Field"
        } else if claimCount == 0 {
            state = "Processing sources"
        } else {
            state = "\(claimCount) memories"
        }
        let titles = recentClaimTitles.isEmpty ? ["Open Hive to continue"] : recentClaimTitles
        return HiveWidgetSnapshotPayload(
            stateText: state,
            memoryCount: claimCount,
            claimTitles: Array(titles.prefix(3))
        )
    }
}
