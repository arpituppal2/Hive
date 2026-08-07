import Foundation
import HiveCore
import Testing

@Suite("Download Filename Policy")
struct DownloadFilenamePolicyTests {
    @Test func sanitizesTraversalAndControlCharacters() {
        let result = DownloadFilenamePolicy.sanitizedFilename("../secret/evil\n.zip")
        #expect(!result.contains("/"))
        #expect(!result.contains("\\"))
        #expect(!result.contains("\n"))
        #expect(!result.hasPrefix("."))
    }

    @Test func usesFallbackForBlankOrDotOnlyNames() {
        #expect(DownloadFilenamePolicy.sanitizedFilename("   ") == "download")
        #expect(DownloadFilenamePolicy.sanitizedFilename("...") == "download")
    }

    @Test func preservesExtensionWhenResolvingCollision() {
        let names: Set<String> = ["report.pdf", "report (1).pdf"]
        #expect(DownloadFilenamePolicy.uniqueFilename("report.pdf", existingNames: names) == "report (2).pdf")
    }

    @Test func leavesUniqueNameUntouched() {
        #expect(DownloadFilenamePolicy.uniqueFilename("image.png", existingNames: ["other.png"]) == "image.png")
    }

    @Test func resumableFailureMetadataRoundTrips() throws {
        let original = BrowserDownload(
            url: URL(string: "https://example.com/archive.zip")!,
            filename: "archive.zip",
            state: .failed,
            errorDescription: "Connection lost",
            resumeData: Data([1, 2, 3])
        )
        let decoded = try JSONDecoder().decode(
            BrowserDownload.self,
            from: JSONEncoder().encode(original)
        )
        #expect(decoded.state == .failed)
        #expect(decoded.resumeData == Data([1, 2, 3]))
    }
}
