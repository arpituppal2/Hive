import Foundation

public struct WikiAttachmentDownloadResult: Sendable, Hashable {
    public var markdown: String
    public var downloadedFiles: [URL]

    public init(markdown: String, downloadedFiles: [URL]) {
        self.markdown = markdown
        self.downloadedFiles = downloadedFiles
    }
}

public struct WikiAttachmentDownloader: Sendable {
    public typealias DataLoader = @Sendable (URL) throws -> Data

    public init() {}

    public func downloadAttachments(
        in markdown: String,
        assetsDirectory: URL,
        relativePrefix: String = "flower-field/assets",
        dataLoader: DataLoader = { try Data(contentsOf: $0) }
    ) throws -> WikiAttachmentDownloadResult {
        try FileManager.default.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)
        let pattern = #"!\[([^\]]*)\]\((https?://[^)\s]+|file://[^)\s]+)\)"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let nsMarkdown = markdown as NSString
        var rewritten = markdown
        var downloaded: [URL] = []

        for match in regex.matches(in: markdown, range: NSRange(location: 0, length: nsMarkdown.length)).reversed() {
            let alt = nsMarkdown.substring(with: match.range(at: 1))
            let rawURL = nsMarkdown.substring(with: match.range(at: 2))
            guard let url = URL(string: rawURL) else { continue }
            let data = try dataLoader(url)
            let fileName = localFileName(for: url, data: data)
            let target = assetsDirectory.appendingPathComponent(fileName)
            if !FileManager.default.fileExists(atPath: target.path) {
                try data.write(to: target, options: [.atomic])
            }
            downloaded.append(target)
            let replacement = "![\(alt)](\(relativePrefix)/\(fileName))"
            if let range = Range(match.range, in: rewritten) {
                rewritten.replaceSubrange(range, with: replacement)
            }
        }

        return WikiAttachmentDownloadResult(markdown: rewritten, downloadedFiles: downloaded.reversed())
    }

    private func localFileName(for url: URL, data: Data) -> String {
        let ext = preferredExtension(for: url)
        let base = url.deletingPathExtension().lastPathComponent
        let safeBase = WikiVaultManager.safeFileName(base.isEmpty ? "image" : base)
        let digest = Hashing.sha256(data: data).prefix(12)
        return "\(safeBase)-\(digest).\(ext)"
    }

    private func preferredExtension(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "gif", "webp", "heic"].contains(ext) {
            return ext
        }
        return "png"
    }
}
