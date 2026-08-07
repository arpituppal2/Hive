import Foundation

/// Resolves model weight repos to on-disk paths and verifies presence.
/// Downloading multi-GB weights is delegated to an external downloader so
/// HiveCore stays dependency-light and testable without network.
public actor ModelStore {

    public static let shared = ModelStore()

    /// Root of all model caches.
    /// Default: ~/Library/Application Support/Hive/Models
    private let rootDir: URL
    private let fm = FileManager.default

    public init(rootDir: URL? = nil) {
        if let rootDir {
            self.rootDir = rootDir
        } else {
            let supp = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.rootDir = supp.appendingPathComponent("Hive/Models",
                                                       isDirectory: true)
        }
    }

    // MARK: - Presence

    /// Has this weight repo been downloaded and unpacked locally?
    public func isPresent(hfRepo: String) -> Bool {
        fm.fileExists(atPath: localDirectory(for: hfRepo).path)
            && fm.fileExists(atPath: localDirectory(for: hfRepo)
                                .appendingPathComponent("config.json").path)
            && (fm.fileExists(atPath: localDirectory(for: hfRepo)
                                .appendingPathComponent("model.safetensors.json").path)
             || fm.fileExists(atPath: localDirectory(for: hfRepo)
                                .appendingPathComponent("weights.npz").path)
             || fm.fileExists(atPath: localDirectory(for: hfRepo)
                                .appendingPathComponent("model.safetensors").path))
    }

    /// Local directory holding a downloaded repo.
    public func localDirectory(for hfRepo: String) -> URL {
        // "mlx-community/Qwen3-0.6B-Instruct-4bit" → "mlx-community__Qwen3-0.6B-Instruct-4bit"
        let safe = hfRepo.replacingOccurrences(of: "/", with: "__")
        return rootDir.appendingPathComponent(safe, isDirectory: true)
    }

    /// Every repo currently present.
    public func presentRepos() -> [String] {
        guard let entries = try? fm.contentsOfDirectory(at: rootDir,
                                                         includingPropertiesForKeys: nil) else {
            return []
        }
        return entries.compactMap { url in
            let name = url.lastPathComponent
            return name.contains("__") ? name.replacingOccurrences(of: "__", with: "/") : nil
        }
    }

    // MARK: - LoRA adapter resolution

    /// Resolves a trained LoRA adapter key (e.g. "urgency_detector") to the
    /// on-disk directory holding `adapter_model.safetensors` + `adapter_config.json`,
    /// as exported by the hive-train pipeline. Resolution order:
    ///   1. The app bundle's `Swarm_Adapters/` resource (adapters shipped WITH
    ///      the app — `.copy("Resources/Swarm_Adapters")` on the Hive target).
    ///      Gives instant offline AI on first launch, no download. Use this for
    ///      the small VERIFIED T0 adapters (intent/spam/urgency, ~35MB each).
    ///   2. The download cache `~/Library/Application Support/Hive/Models/Adapters/<key>/`
    ///      (adapters fetched on first use, same pattern as the base weight repos).
    ///   3. nil — the MLXRuntime then serves the off-the-shelf base honestly
    ///      (labelled `.mlx`, not Mock) rather than failing.
    ///
    /// Pure function (no await) so it can be called from a non-actor context.
    public static func adapterDirectory(for key: String, rootDir: URL? = nil) -> String? {
        let fm = FileManager.default
        // 1. Bundled with the app (works in HiveCore because Bundle.main is the
        //    host executable's bundle — where Resources/Swarm_Adapters lands).
        if let bundled = Bundle.main.url(forResource: key,
                                         withExtension: nil,
                                         subdirectory: "Swarm_Adapters"),
           fm.fileExists(atPath: bundled.path) {
            return bundled.path
        }
        // 2. Download cache (same root as the base weight repos).
        let supp = fm.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let root = (rootDir ?? supp.appendingPathComponent("Hive/Models", isDirectory: true))
            .appendingPathComponent("Adapters", isDirectory: true)
            .appendingPathComponent(key, isDirectory: true)
        return fm.fileExists(atPath: root.path) ? root.path : nil
    }

    // MARK: - Download

    /// Triggers a download. The closure is meant to call an external downloader
    /// (e.g. `huggingface-cli download` or an MLX downloader) — HiveCore does
    /// not itself depend on a network/HTTP client. Returns once present.
    public func ensureDownloaded(
        hfRepo: String,
        using downloader: (String, URL) async throws -> Void
    ) async throws {
        if isPresent(hfRepo: hfRepo) { return }
        try fm.createDirectory(at: localDirectory(for: hfRepo),
                               withIntermediateDirectories: true)
        try await downloader(hfRepo, localDirectory(for: hfRepo))
        guard isPresent(hfRepo: hfRepo) else {
            throw InferenceError.weightsNotDownloaded(hfRepo: hfRepo)
        }
    }

    // MARK: - Resolve role → entry → presence

    /// Returns the runtime-relevant entry for a role, plus whether weights exist.
    public func resolve(_ role: ModelRole) -> (entry: ManifestEntry, present: Bool) {
        guard let entry = ModelManifest.entries[role] else {
            // ruleBased / appleFMF / byok have no hfRepo or are handled specially.
            return (ManifestEntry(role: role, hfRepo: nil, baseModel: "—",
                                  quantizedSizeMB: 0, license: "—",
                                  servingStrategy: .ruleBased, maxOutputTokens: 0,
                                  latencyTargetMS: 0), present: true)
        }
        guard let repo = entry.hfRepo else { return (entry, present: true) }
        return (entry, isPresent(hfRepo: repo))
    }
}
