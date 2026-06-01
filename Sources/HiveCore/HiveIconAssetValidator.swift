import Foundation

public struct HiveIconValidationReport: Codable, Hashable, Sendable {
    public var isValid: Bool
    public var problems: [String]
    public var groupCount: Int
    public var layerCount: Int
    public var assetCount: Int

    public init(
        isValid: Bool,
        problems: [String],
        groupCount: Int,
        layerCount: Int,
        assetCount: Int
    ) {
        self.isValid = isValid
        self.problems = problems
        self.groupCount = groupCount
        self.layerCount = layerCount
        self.assetCount = assetCount
    }
}

public enum HiveIconAssetValidator {
    public static let requiredPreviewFilenames: [String] = [
        "Preview-normal.png",
        "Preview-dark.png",
        "Preview-light-tinted.png",
        "Preview-dark-tinted.png",
        "Preview-light-clear.png",
        "Preview-dark-clear.png"
    ]

    public static let bannedLegacyTerms: [String] = [
        "Memory Bloom",
        "capsule",
        "blob-only",
        "frosted-lens",
        "hexPath",
        "roundedDiamondPath",
        "strokePath",
        "addLine",
        "inner-refraction",
        "hex-outline",
        "outline",
        "ring",
        "stripe",
        "wire",
        "hatching"
    ]

    public static let requiredGroupNames: [String] = [
        "small-glass-hex",
        "medium-glass-hex",
        "large-glass-hex"
    ]

    public static func validate(appIconRoot: URL, fileManager: FileManager = .default) -> HiveIconValidationReport {
        let iconDocument = appIconRoot.appendingPathComponent("Hive.icon", isDirectory: true)
        let iconJSONURL = iconDocument.appendingPathComponent("icon.json")
        let assetsURL = iconDocument.appendingPathComponent("Assets", isDirectory: true)
        let previewRoot = appIconRoot.appendingPathComponent("IconComposerPreviews", isDirectory: true)
        var problems: [String] = []
        var groupCount = 0
        var layerCount = 0
        var referencedAssets: [String] = []

        guard fileManager.fileExists(atPath: iconJSONURL.path),
              let data = try? Data(contentsOf: iconJSONURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return HiveIconValidationReport(
                isValid: false,
                problems: ["Hive.icon/icon.json is missing or invalid JSON."],
                groupCount: 0,
                layerCount: 0,
                assetCount: 0
            )
        }

        if let raw = String(data: data, encoding: .utf8) {
            for term in bannedLegacyTerms where raw.localizedCaseInsensitiveContains(term) {
                problems.append("Icon document contains legacy artifact term: \(term).")
            }
        }

        guard let groups = json["groups"] as? [[String: Any]], !groups.isEmpty else {
            problems.append("Icon Composer document has no groups.")
            return HiveIconValidationReport(isValid: false, problems: problems, groupCount: 0, layerCount: 0, assetCount: 0)
        }

        groupCount = groups.count
        if groupCount != requiredGroupNames.count {
            problems.append("Icon Composer document has \(groupCount) visible groups; expected exactly \(requiredGroupNames.count).")
        }
        let actualGroupNames = groups.compactMap { $0["name"] as? String }
        if Set(actualGroupNames) != Set(requiredGroupNames) {
            problems.append("Icon Composer groups are \(actualGroupNames); expected \(requiredGroupNames).")
        }
        for (index, group) in groups.enumerated() {
            guard let layers = group["layers"] as? [[String: Any]], !layers.isEmpty else {
                problems.append("Icon Composer group \(index + 1) has zero layers.")
                continue
            }
            if layers.count != 1 {
                problems.append("Icon Composer group \(index + 1) has \(layers.count) layers; expected exactly one centered hex layer.")
            }
            if group["shadow"] as? [String: Any] != nil {
                problems.append("Icon Composer group \(index + 1) includes shadow metadata; the simple hex stack icon forbids shadows.")
            }
            if group["translucency"] as? [String: Any] == nil {
                problems.append("Icon Composer group \(index + 1) is missing its attached translucency metadata.")
            }
            layerCount += layers.count
            for layer in layers {
                guard let imageName = layer["image-name"] as? String, !imageName.isEmpty else {
                    problems.append("A layer in group \(index + 1) has no image-name.")
                    continue
                }
                if imageName.localizedCaseInsensitiveContains("shadow") || imageName.localizedCaseInsensitiveContains("reflection") {
                    problems.append("Icon Composer asset \(imageName) is a standalone effect layer; shadows/reflections must be owned by a hex group.")
                }
                referencedAssets.append(imageName)
                if !fileManager.fileExists(atPath: assetsURL.appendingPathComponent(imageName).path) {
                    problems.append("Missing Icon Composer asset: \(imageName).")
                }
            }
        }

        if layerCount == 0 {
            problems.append("Icon Composer document has zero foreground/background image layers.")
        }
        for filename in requiredPreviewFilenames {
            if !fileManager.fileExists(atPath: previewRoot.appendingPathComponent(filename).path) {
                problems.append("Missing icon preview: \(filename).")
            }
        }
        if !fileManager.fileExists(atPath: appIconRoot.appendingPathComponent("Hive.icns").path) {
            problems.append("Missing Hive.icns fallback.")
        }
        if !fileManager.fileExists(atPath: appIconRoot.appendingPathComponent("Hive.iconset/icon_512x512@2x.png").path) {
            problems.append("Missing 1024px iconset fallback.")
        }

        return HiveIconValidationReport(
            isValid: problems.isEmpty,
            problems: problems,
            groupCount: groupCount,
            layerCount: layerCount,
            assetCount: Set(referencedAssets).count
        )
    }
}
