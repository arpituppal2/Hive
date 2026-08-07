//
//  BoostStore.swift
//  HiveCore
//
//  An actor‑isolated store for Boosts backed by a JSON file on disk.
//  Keeps the full boost list in memory for fast lookup at page‑load time.
//

import Foundation

// MARK: - BoostStore

public actor BoostStore {
    public static let shared = BoostStore()

    // MARK: State

    private var boosts: [Boost] = []
    private var loaded = false

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    /// URL of the boosts.json file in the app support directory.
    private var storeURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask).first!
        let hiveDir = appSupport.appendingPathComponent("Hive", isDirectory: true)
        return hiveDir.appendingPathComponent("boosts.json")
    }

    private init() {}

    // MARK: Public API

    /// Load boosts from disk (idempotent — safe to call multiple times).
    public func load() {
        guard !loaded else { return }
        defer { loaded = true }
        let url = storeURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let collection = try decoder.decode(BoostCollection.self, from: data)
            boosts = collection.boosts
        } catch {
            // If the file is corrupt, start fresh.
            boosts = []
        }
    }

    /// Persist the current boost list to disk.
    private func save() {
        let url = storeURL
        do {
            let dir = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try encoder.encode(BoostCollection(boosts: boosts))
            try data.write(to: url, options: .atomic)
        } catch {
            // Silently fail on write errors — next save will retry.
        }
    }

    // MARK: CRUD

    /// All boosts (reads from the in‑memory cache).
    public func allBoosts() -> [Boost] {
        load()
        return boosts
    }

    /// Boosts whose `urlPattern` matches the given URL.
    public func boosts(for url: URL) -> [Boost] {
        load()
        return boosts.filter { $0.isEnabled && $0.matches(url) }
    }

    /// Whether any enabled boost matches the given URL.
    public func hasBoost(for url: URL) -> Bool {
        load()
        return boosts.contains(where: { $0.isEnabled && $0.matches(url) })
    }

    /// Create a new boost and persist.
    @discardableResult
    public func create(_ boost: Boost) -> Boost {
        load()
        boosts.append(boost)
        save()
        return boost
    }

    /// Update an existing boost (matched by `id`).
    public func update(_ boost: Boost) {
        load()
        guard let idx = boosts.firstIndex(where: { $0.id == boost.id }) else { return }
        boosts[idx] = boost
        save()
    }

    /// Remove a boost by `id`.
    public func delete(id: String) {
        load()
        boosts.removeAll { $0.id == id }
        save()
    }

    /// Toggle a boost on/off.
    public func toggle(id: String) {
        load()
        guard let idx = boosts.firstIndex(where: { $0.id == id }) else { return }
        boosts[idx].isEnabled.toggle()
        boosts[idx].updatedAt = Date()
        save()
    }

    /// Remove all boosts.
    public func deleteAll() {
        boosts = []
        save()
    }
}
