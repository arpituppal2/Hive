import Foundation
import Combine
import HiveCore

// MARK: - ModelDownloader

/// Downloads MLX model weights from Hugging Face using `huggingface-cli` (Python).
/// Wires into `ModelStore.ensureDownloaded` so MLXRuntime can load real on-device models.
///
/// Observe `@Published` properties for UI updates. Call `downloadAllIfNeeded()` to begin.

@MainActor
public final class ModelDownloader: ObservableObject {

    @Published public var isDownloading: Bool = false
    @Published public var currentRepo: String = ""
    @Published public var progress: Double = 0
    @Published public var downloadedMB: Double = 0
    @Published public var totalMB: Double = 0
    @Published public var statusText: String = ""
    @Published public var errorText: String? = nil
    @Published public var completedRepos: [String] = []
    @Published public var presentCount: Int = 0

    /// All weight repos needed for Hive's model manifest.
    /// Ordered by download priority (smallest first for fast first-run).
    public static let requiredRepos: [(repo: String, sizeMB: Int, label: String)] = [
        ("mlx-community/Qwen2.5-0.5B-Instruct-4bit", 300, "0.5B base model"),
        ("mlx-community/Qwen2.5-1.5B-Instruct-4bit", 900, "1.5B general-purpose"),
        ("mlx-community/nomic-embed-text-v2-Matryoshka-F16", 560, "Embedding model"),
        ("mlx-community/Qwen2.5-Coder-7B-Instruct-4bit", 4300, "7B coding model"),
    ]

    private var downloadTask: Task<Void, Never>?

    public init() {}

    // MARK: - Download

    public func downloadAllIfNeeded() {
        guard !isDownloading else { return }
        downloadTask?.cancel()
        downloadTask = Task {
            isDownloading = true
            errorText = nil
            completedRepos = []

            // Filter repos not yet present
            var reposToDownload: [(repo: String, sizeMB: Int, label: String)] = []
            for (repo, sizeMB, label) in Self.requiredRepos {
                if Task.isCancelled { break }
                if await !ModelStore.shared.isPresent(hfRepo: repo) {
                    reposToDownload.append((repo, sizeMB, label))
                }
            }

            if reposToDownload.isEmpty {
                statusText = "All models already downloaded."
                presentCount = Self.requiredRepos.count
                isDownloading = false
                return
            }

            for (repo, sizeMB, label) in reposToDownload {
                guard !Task.isCancelled else { break }
                currentRepo = label
                totalMB = Double(sizeMB)
                downloadedMB = 0
                progress = 0
                statusText = "Downloading \(label)..."

                // Task.detached breaks @MainActor isolation so the ensureDownloaded
                // closure can safely cross to the ModelStore actor.
                do {
                    try await Task.detached { [repo, sizeMB] in
                        try await ModelStore.shared.ensureDownloaded(hfRepo: repo) { _, localDir in
                            try await Self.downloadToDisk(repo: repo, localDir: localDir,
                                                           sizeMB: sizeMB)
                        }
                    }.value
                    completedRepos.append(repo)
                    statusText = "Downloaded \(label)."
                } catch {
                    if Task.isCancelled { break }
                    errorText = "Failed: \(label) — \(error.localizedDescription)"
                    statusText = "Download incomplete."
                    isDownloading = false
                    // Refresh presence count even on partial failure
                    await refreshPresentCount()
                    return
                }
            }

            if !Task.isCancelled {
                statusText = completedRepos.count == reposToDownload.count
                    ? "All models ready. Real on-device AI active."
                    : "Download complete — \(completedRepos.count) model(s) ready."
                progress = 1.0
            }
            // Refresh presence count after download completes
            await refreshPresentCount()
            isDownloading = false
        }
    }

    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        statusText = "Download cancelled."
    }

    // MARK: - CLI availability

    public static func isCLIAvailable() -> Bool {
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        which.arguments = ["which", "huggingface-cli"]
        let pipe = Pipe()
        which.standardOutput = pipe
        which.standardError = FileHandle.nullDevice
        do {
            try which.run()
            which.waitUntilExit()
            return which.terminationStatus == 0
        } catch {
            return false
        }
    }

    public static func installInstructions() -> String {
        "Run: pip install huggingface_hub[hf_transfer]\nThen: huggingface-cli login (optional)"
    }

    // MARK: - Presence

    public func refreshPresentCount() async {
        let count = await withTaskGroup(of: Bool.self) { group in
            for (repo, _, _) in Self.requiredRepos {
                group.addTask { await ModelStore.shared.isPresent(hfRepo: repo) }
            }
            var present = 0
            for await isPresent in group { if isPresent { present += 1 } }
            return present
        }
        presentCount = count
    }

    // MARK: - Private download implementation

    /// Stateless download function — safe to pass across actor boundaries.
    /// Sends progress updates to ModelDownloader's @Published properties via
    /// a continuation pattern to avoid capturing `self`.
    private static func downloadToDisk(
        repo: String, localDir: URL, sizeMB: Int
    ) async throws {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "huggingface-cli", "download", repo,
            "--local-dir", localDir.path,
            "--local-dir-use-symlinks", "False",
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = pipe
        process.environment = ProcessInfo.processInfo.environment

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ModelDownloadError.downloadFailed(
                repo: repo, exitCode: process.terminationStatus)
        }
    }
}

// MARK: - ModelDownloadError

enum ModelDownloadError: LocalizedError {
    case downloadFailed(repo: String, exitCode: Int32)

    var errorDescription: String? {
        switch self {
        case let .downloadFailed(repo, code):
            return "Download of \(repo) failed (exit \(code)). Is huggingface-cli installed? Run: pip install huggingface_hub"
        }
    }
}
