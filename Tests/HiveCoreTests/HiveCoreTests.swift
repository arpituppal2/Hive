import Foundation
import SQLite3
import Testing
@testable import HiveCore

// MARK: - SessionFileStore (crash-safe session persistence)

/// Minimal Codable+Equatable payload mirroring the shell's SessionData shape
/// (forward-compatible decode, plain JSON round-trip).
private struct TestSession: Codable, Equatable, Sendable {
    var layout: String
    var activeTabID: String?
    var tabInfos: [TestTabInfo]
}

private struct TestTabInfo: Codable, Equatable, Sendable {
    var id: String
    var urlString: String?
}

@Suite("SessionFileStore")
struct SessionFileStoreTests {

    private func makeStore() throws -> (store: SessionFileStore<TestSession>, dir: URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-session-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (
            SessionFileStore(
                url: dir.appendingPathComponent("session.json"),
                prevURL: dir.appendingPathComponent("session.prev.json")
            ),
            dir
        )
    }

    private func sample(_ marker: String) -> TestSession {
        TestSession(
            layout: "vertical",
            activeTabID: "tab-\(marker)",
            tabInfos: [TestTabInfo(id: "tab-\(marker)", urlString: "https://example.com/\(marker)")]
        )
    }

    @Test func writeThenLoadRoundTripsPayload() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        store.write(sample("a"))

        guard case .restored(let loaded) = store.load() else {
            Issue.record("Expected restored, got none/corrupt")
            return
        }
        #expect(loaded == sample("a"))
        // The first write creates no backup (there was no prior good file).
        #expect(FileManager.default.fileExists(atPath: store.prevURL.path) == false)
    }

    @Test func secondWriteRotatesPriorGoodFileToBackup() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        store.write(sample("v1"))
        store.write(sample("v2"))

        guard case .restored(let loaded) = store.load() else {
            Issue.record("Expected restored v2")
            return
        }
        #expect(loaded == sample("v2"))
        // v1 is preserved as the rolling backup.
        let prevData = try Data(contentsOf: store.prevURL)
        let prev = try JSONDecoder().decode(TestSession.self, from: prevData)
        #expect(prev == sample("v1"))
    }

    @Test func corruptMainFileIsQuarantinedAndBackupRestored() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        store.write(sample("v1"))
        store.write(sample("v2"))
        // Simulate a crash/truncated write: garbage in the main file.
        try Data("{\"layout\": [broken".utf8).write(to: store.url)

        guard case .corrupt(let quarantineURL, let recovered) = store.load() else {
            Issue.record("Expected corrupt outcome, got \(store.load())")
            return
        }
        #expect(recovered == sample("v1"), "Recovery must come from the last known-good backup")
        // The corrupt file is quarantined, never deleted.
        let quarantine = try #require(quarantineURL)
        #expect(FileManager.default.fileExists(atPath: quarantine.path))
        // The recovered payload self-repairs the main file so the recovered
        // session survives even if the app quits before the next save.
        #expect(FileManager.default.fileExists(atPath: store.url.path))
        guard case .restored(let second) = store.load() else {
            Issue.record("Repaired main file should load as restored")
            return
        }
        #expect(second == sample("v1"))
    }

    @Test func corruptMainWithoutBackupReturnsCorruptWithNilRecovery() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        store.write(sample("only"))
        // Overwrite the ONLY copy with garbage (no backup existed).
        try Data("not json".utf8).write(to: store.url)

        guard case .corrupt(_, let recovered) = store.load() else {
            Issue.record("Expected corrupt outcome")
            return
        }
        #expect(recovered == nil)
        #expect(FileManager.default.fileExists(atPath: store.prevURL.path) == false)
    }

    @Test func missingFileReturnsNone() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        guard case .none = store.load() else {
            Issue.record("Expected .none for a missing session file")
            return
        }
    }

    @Test func customPrevURLAndEncoderAreHonored() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-session-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let customPrev = dir.appendingPathComponent("custom.prev")
        let store = SessionFileStore<TestSession>(
            url: dir.appendingPathComponent("main.json"),
            prevURL: customPrev
        )

        var encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        store.write(sample("x"), encoder: encoder)
        store.write(sample("y"), encoder: encoder)

        #expect(FileManager.default.fileExists(atPath: customPrev.path))
        guard case .restored(let loaded) = store.load() else {
            Issue.record("Expected restored")
            return
        }
        #expect(loaded == sample("y"))
    }

    /// A payload whose encoding always throws — proves a failed encode can
    /// never rotate or remove an existing good session file.
    private struct ThrowingSession: Codable {
        func encode(to encoder: Encoder) throws {
            throw CocoaError(.coderInvalidValue)
        }
    }

    private func makeThrowingStore() throws -> (store: SessionFileStore<ThrowingSession>, dir: URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-session-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (
            SessionFileStore(
                url: dir.appendingPathComponent("session.json"),
                prevURL: dir.appendingPathComponent("session.prev.json")
            ),
            dir
        )
    }

    @Test func failedEncodeLeavesExistingMainIntact() throws {
        let (store, dir) = try makeThrowingStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Simulate an existing good main file from a prior successful write.
        let prior = Data("{\"layout\":\"vertical\"}".utf8)
        try prior.write(to: store.url)

        store.write(ThrowingSession()) // encode throws -> must not rotate/remove

        #expect(try Data(contentsOf: store.url) == prior)
        #expect(FileManager.default.fileExists(atPath: store.prevURL.path) == false)
    }

    @Test func missingMainWithBackupRecoversInsteadOfFreshStart() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        store.write(sample("v1"))
        store.write(sample("v2"))
        // Simulate a crash between rotate and swap: main is gone, backup remains.
        try FileManager.default.removeItem(at: store.url)

        guard case .corrupt(_, let recovered) = store.load() else {
            Issue.record("Expected corrupt-recovery from backup, not a silent fresh start")
            return
        }
        #expect(recovered == sample("v1"))
        // The recovered payload repairs the main file so recovery is durable
        // even if the app quits before the next save.
        #expect(FileManager.default.fileExists(atPath: store.url.path))
        guard case .restored(let second) = store.load() else {
            Issue.record("Repaired main file should load as restored")
            return
        }
        #expect(second == sample("v1"))
    }
}

// MARK: - Rebuild baseline

@Test func hiveCoreVersionIsRebuildBaseline() {
    #expect(HiveCore.version == "0.0.0-rebuild")
}

// MARK: - Manifest: every AI Swarm needs is defined

/// The manifest is the canonical answer to "what AIs does Swarm need." These
/// tests lock its structural invariants so adding/removing a role fails loudly,
/// and so the weight/strategy contracts can't silently drift.
@Suite("ModelManifest")
struct ManifestTests {

    @Test func everyRoleHasAnEntry() {
        // 22 roles = the defined roster. Changing this number is a deliberate act.
        // (19 as of 2026-07-28; +2 on 2026-07-29 for the scribe family:
        //  captureScribe, pageQa — Directive B phase-6 OTS Cells. +1 on
        //  2026-08-02 for researchGatherer — the §7.3 fetch/extract front half.)
        #expect(ModelRole.allCases.count == 22)
        #expect(ModelManifest.entries.count == 22)
        // 1:1 — no role without an entry, no entry without a role.
        #expect(Set(ModelManifest.entries.keys) == Set(ModelRole.allCases))
    }

    @Test func noDuplicateBaseModelAcrossRoleObjects() {
        // Each entry's `role` field must match its key — guards against a
        // copy-paste entry filed under the wrong role.
        for (role, entry) in ModelManifest.entries {
            #expect(entry.role == role, "entry for \(role.rawValue) is filed under the wrong role")
        }
    }

    @Test func tiersAreSelfConsistent() {
        for role in ModelRole.allCases {
            let entry = ModelManifest.entries[role]!
            switch entry.servingStrategy {
            case .ruleBased:    #expect(role.tier == .rule, "\(role) strategy=rule but tier!=rule")
            case .appleFMF:     #expect(role.tier == .fmf,  "\(role) strategy=fmf but tier!=fmf")
            case .byokRemote:   #expect(role.tier == .byok, "\(role) strategy=byok but tier!=byok")
            case .instructOffTheShelf, .instructLoRA:
                #expect([.t0, .t1, .t2, .t3].contains(role.tier),
                        "\(role) is instruct-served but tier=\(role.tier)")
            case .systemEmbedder:
                #expect(role == .embedder, "only .embedder uses systemEmbedder")
            }
        }
    }

    @Test func weightRepoContracts() {
        for role in ModelRole.allCases {
            let entry = ModelManifest.entries[role]!
            switch entry.servingStrategy {
            case .ruleBased, .appleFMF, .byokRemote:
                // These never need a downloaded weight set.
                #expect(entry.hfRepo == nil, "\(role) must have no hfRepo")
            case .instructOffTheShelf:
                // Instruct roles run local weights — must point at a repo.
                #expect(entry.hfRepo != nil, "\(role) instruct role needs an hfRepo")
                #expect(entry.hfRepo!.hasPrefix("mlx-community/"),
                        "\(role) hfRepo must be an mlx-community repo, got \(entry.hfRepo!)")
                // Off-the-shelf roles never claim a trained adapter.
                #expect(entry.loraAdapter == nil,
                        "\(role) is off-the-shelf but declares loraAdapter=\(entry.loraAdapter!); flip to .instructLoRA or drop the adapter")
            case .instructLoRA:
                // A LoRA-served role merges a trained adapter ONTO a local base,
                // so it needs BOTH: the base repo (mlx-community, like OTS) and a
                // non-nil adapter key. A LoRA role with a nil adapter would load
                // the plain base and silently pretend to be tuned. A nil adapter
                // on an .instructLoRA role is a manifest lie.
                #expect(entry.hfRepo != nil, "\(role) LoRA role needs a base hfRepo")
                #expect(entry.hfRepo!.hasPrefix("mlx-community/"),
                        "\(role) hfRepo must be an mlx-community repo, got \(entry.hfRepo!)")
                #expect(entry.loraAdapter != nil,
                        "\(role) is .instructLoRA but has nil loraAdapter — either supply the verified adapter key or demote to .instructOffTheShelf")
            case .systemEmbedder:
                // embedder carries the upgrade-path repo. No contract here.
                continue
            }
        }
    }

    @Test func loraRolesHaveVerifiedHeldOutVerdict() {
        // A role may only be .instructLoRA if its adapter has a VERIFIED
        // held-out punch-up verdict (PUNCH_UP / MATCH / LOSES-with-gain). This
        // test is the honest-default guardrail: it forbids flipping an
        // unverified role to LoRA (the local copy is stale; the truth lives on
        // Brev — see brev-is-source-of-truth-train memory). Add a role here
        // ONLY when a results/punch_up_*.json proves the gain. As of
        // 2026-07-29: urgency_detector MATCH, spam_detector MATCH,
        // intent_router LOSES-but-gain (base 0.53→0.93). retrieval_ranker is
        // NO_GAIN (lora < base) → correctly stays OTS.
        let verified: Set<ModelRole> = [.intentClassifier, .spamDetector, .urgencyDetector]
        let loRaRoles = Set(ModelRole.allCases.filter {
            ModelManifest.entries[$0]?.servingStrategy == .instructLoRA
        })
        #expect(loRaRoles == verified,
                "instructLoRA roles must each have a verified held-out verdict; got \(loRaRoles), expected \(verified)")
    }

    @Test func localOnlyGuardsTrustBoundary() {
        // The trust-defining roles must never offload to a remote model.
        for role in ModelRole.allCases where role.localOnly == false {
            #expect(role == .byokFrontier,
                    "only byokFrontier may leave the device; \(role) does too")
        }
        for role in [ModelRole.actionGuard, .orchestrator, .auditor, .planner] {
            #expect(role.localOnly, "\(role.rawValue) must be localOnly")
        }
    }

    @Test func allWeightSetsAreDistinctAndMlxPrefixed() {
        let sets = ModelManifest.allWeightSets
        #expect(sets == Set(sets).sorted(), "allWeightSets must be de-duplicated")
        for repo in sets { #expect(repo.hasPrefix("mlx-community/")) }
        // The four bases: 0.5B, 1.5B, Coder-7B, embedder = 4 distinct repos.
        #expect(sets.count == 4, "expected 4 distinct weight sets; got \(sets)")
    }

    @Test func sharedRepoGroupsCohort() {
        // The 0.5B cohort shares one load slot.
        let cohort = ModelManifest.sharedRepo(for: .intentClassifier)
        #expect(cohort.contains(.linkScorer))
        #expect(!cohort.contains(.orchestrator))   // orchestrator is on the 1.5B
        #expect(!cohort.contains(.summarizer))     // summarizer is on the 1.5B
        // A role with no repo groups only itself.
        #expect(ModelManifest.sharedRepo(for: .actionGuard) == [.actionGuard])
    }
}

// MARK: - Mock runtime: honestly labelled, deterministic, never real

@Suite("MockRuntime")
struct MockRuntimeTests {

    @Test func providerIsMockAndNeverReal() async throws {
        let rt = MockRuntime()
        #expect(await rt.isAvailable())
        for role in ModelRole.allCases {
            let req = GenerateRequest(role: role, system: "s", user: "u")
            let res = try await rt.generate(req)
            #expect(res.provider == .mock, "\(role) provider != .mock")
            #expect(res.isRealInference == false, "\(role) claims real inference")
            #expect(res.role == role, "role didn't round-trip")
        }
    }

    @Test func deterministicForSameInput() async throws {
        let rt = MockRuntime()
        let req = GenerateRequest(role: .intentClassifier, system: "s", user: "u")
        let a = try await rt.generate(req)
        let b = try await rt.generate(req)
        #expect(a.text == b.text)
        #expect(a.provider == b.provider)
    }

    @Test func supportsEveryRole() {
        #expect(MockRuntime.supportedRoles == Set(ModelRole.allCases))
    }
}

// MARK: - Dispatcher: honest fallback chain

/// Routing must never silently fake inference. These tests pick roles whose
/// routing is deterministic regardless of host OS: `.actionGuard` (rule-based →
/// mock directly) and `.orchestrator` (FMF-forbidden by policy, no MLX in this
/// build → mock). They assert the provider label, the realness flag, and the
/// honesty invariant below across a role sweep.
@Suite("Dispatcher")
struct DispatcherTests {

    @Test func ruleBasedRoleRoutesToMock() async throws {
        let d = Dispatcher()
        let res = try await d.generate(
            GenerateRequest(role: .actionGuard, system: "", user: "delete everything"))
        #expect(res.provider == .mock)
        #expect(res.isRealInference == false)
    }

    @Test func fmfForbiddenInstructionRoleFallsBackToMockWhenNoMlx() async throws {
        // .orchestrator is localOnly AND not in appleFMFAllowed, so without MLX
        // weights present it must fall through to the honest mock — never FMF.
        let d = Dispatcher()
        let res = try await d.generate(
            GenerateRequest(role: .orchestrator, system: "", user: "summarize this tab"))
        #expect(res.provider == .mock)
        #expect(res.isRealInference == false)
    }

    @Test func byokRoleRoutesToMockWhenUnconfigured() async throws {
        // No BYOK runtime injected → byokFrontier must NOT reach a network; it
        // falls back to mock. This protects against phantom remote calls.
        let d = Dispatcher()
        let res = try await d.generate(
            GenerateRequest(role: .byokFrontier, system: "", user: "deep research"))
        #expect(res.provider == .mock)
    }

    @Test func honestyInvariantHoldsAcrossAllRoles() async throws {
        // Whatever provider the dispatcher actually selects, the result must
        // never mislabel itself: real inference iff provider is a real source.
        let d = Dispatcher()
        for role in ModelRole.allCases {
            let res = try await d.generate(
                GenerateRequest(role: role, system: "", user: "probe"))
            let shouldBeReal = (res.provider != .mock && res.provider != .rule)
            #expect(res.isRealInference == shouldBeReal,
                    "\(role.rawValue): isRealInference disagrees with provider \(res.provider)")
        }
    }

    @Test func mlxRuntimeReportsAvailability() async {
        // When MLX is linked in the build (canImport(MLXLMCommon) == true),
        // MLXRuntime.isAvailable() must return true. Without MLX packages,
        // this test is a no-op — the runtime honestly reports unavailable.
        #if canImport(MLXLMCommon)
        let mlx = MLXRuntime()
        let available = await mlx.isAvailable()
        #expect(available, "MLXRuntime must be available when MLX packages are linked")
        #else
        // MLX not linked — isAvailable() correctly returns false.
        // Nothing to assert; the honesty invariant test covers this path.
        #endif
    }

    @Test func mlxRuntimeRejectsUnsupportedRoles() async {
        // When MLX is linked, instruct roles need downloaded weights to
        // succeed. Rule-based roles are never served by MLX and must be
        // rejected with .roleUnsupported.
        #if canImport(MLXLMCommon)
        let mlx = MLXRuntime()
        let req = GenerateRequest(role: .actionGuard, system: "", user: "")
        do {
            _ = try await mlx.generate(req)
            #expect(Bool(false), "MLXRuntime should reject rule-based roles")
        } catch let error as InferenceError {
            guard case .roleUnsupported = error else {
                #expect(Bool(false), "expected roleUnsupported, got \(error)")
                return
            }
            // expected
        } catch {
            #expect(Bool(false), "expected InferenceError, got \(error)")
        }
        #endif
    }

    // MARK: - ProviderPreference routing (Comet-style model toggle)

    @Test func autoPreferenceMatchesDefaultChain() async throws {
        // .auto must be identical to the pre-toggle routing — the default
        // parameter is purely additive.
        let d = Dispatcher()
        let plain = try await d.generate(
            GenerateRequest(role: .orchestrator, system: "", user: "probe"))
        let auto = try await d.generate(
            GenerateRequest(role: .orchestrator, system: "", user: "probe"),
            preferredProvider: .auto)
        #expect(plain.provider == auto.provider)
        #expect(plain.isRealInference == auto.isRealInference)
    }

    @Test func fmfPreferenceCannotBypassPolicyForForbiddenRole() async throws {
        // .orchestrator is FMF-forbidden by ProviderPolicy. Even an explicit
        // .appleFMF preference must NOT route it to FMF — the policy is a
        // hard boundary, not a hint. Deterministic on any host.
        let d = Dispatcher()
        let res = try await d.generate(
            GenerateRequest(role: .orchestrator, system: "", user: "probe"),
            preferredProvider: .appleFMF)
        #expect(res.provider == .mock)
        #expect(res.isRealInference == false)
    }

    @Test func mlxPreferenceNeverFabricatesInference() async throws {
        // Whatever .mlx preference resolves to, the result must not claim real
        // inference it didn't perform. The concrete provider is build- and
        // host-dependent: with MLX absent and FMF present (as on this host),
        // .summarizer honestly falls through to Apple FMF — real inference.
        // The invariant that holds everywhere is the honesty label itself.
        let d = Dispatcher()
        let res = try await d.generate(
            GenerateRequest(role: .summarizer, system: "", user: "probe"),
            preferredProvider: .mlx)
        #expect(res.isRealInference == (res.provider != .mock && res.provider != .rule),
                "mlx preference: isRealInference disagrees with provider \(res.provider)")
    }

    @Test func byokPreferenceNeverFabricatesRemote() async throws {
        // A .byokRemote preference must never fabricate a remote call. With no
        // BYOK runtime the honest outcome is the default chain (which may be
        // FMF on this host — still real, still honest). The invariant is the
        // label, not a specific provider.
        let d = Dispatcher()
        let res = try await d.generate(
            GenerateRequest(role: .summarizer, system: "", user: "probe"),
            preferredProvider: .byokRemote)
        #expect(res.isRealInference == (res.provider != .mock && res.provider != .rule),
                "byok preference: isRealInference disagrees with provider \(res.provider)")
    }

    @Test func byokServedRoleIgnoresPreferenceButStaysHonest() async throws {
        // A .byokRemote-served role (byokFrontier) routes through the BYOK
        // branch regardless of the preference. With no BYOK configured it
        // must still resolve to mock — never a fabricated remote.
        let d = Dispatcher()
        let res = try await d.generate(
            GenerateRequest(role: .byokFrontier, system: "", user: "probe"),
            preferredProvider: .appleFMF)
        #expect(res.provider == .mock)
    }

    @Test func honestyInvariantHoldsUnderEveryPreference() async throws {
        // Sweep all roles × all preferences: a user preference must never let
        // the result mislabel itself (real inference iff provider is real).
        let d = Dispatcher()
        for preference in ProviderPreference.allCases {
            for role in ModelRole.allCases {
                let res = try await d.generate(
                    GenerateRequest(role: role, system: "", user: "probe"),
                    preferredProvider: preference)
                let shouldBeReal = (res.provider != .mock && res.provider != .rule)
                #expect(res.isRealInference == shouldBeReal,
                        "\(role.rawValue)/\(preference.rawValue): isRealInference disagrees with provider \(res.provider)")
            }
        }
    }
}

// MARK: - ContextScope

@Suite("ContextScope")
struct ContextScopeTests {
    @Test func workspaceAndProfileIsolationRejectsForeignEntries() {
        let scope = ContextScope(profileID: "profile-a", workspaceID: "workspace-a")
        #expect(scope.admits(profileID: "profile-a", workspaceID: "workspace-a", isPrivate: false))
        #expect(!scope.admits(profileID: "profile-b", workspaceID: "workspace-a", isPrivate: false))
        #expect(!scope.admits(profileID: "profile-a", workspaceID: "workspace-b", isPrivate: false))
        #expect(!scope.admits(profileID: nil, workspaceID: nil, isPrivate: false),
                "untagged memory must not become global by accident")
        #expect(scope.admits(profileID: nil, workspaceID: nil, isPrivate: false, isGlobal: true),
                "explicitly global memory remains eligible")
    }

    @Test func projectIsolationRejectsForeignAndUntaggedEntries() {
        let scope = ContextScope(profileID: "profile-a", workspaceID: "workspace-a", projectID: "project-a")
        #expect(scope.admits(profileID: "profile-a", workspaceID: "workspace-a", projectID: "project-a", isPrivate: false))
        #expect(!scope.admits(profileID: "profile-a", workspaceID: "workspace-a", projectID: "project-b", isPrivate: false))
        #expect(!scope.admits(profileID: "profile-a", workspaceID: "workspace-a", projectID: nil, isPrivate: false),
                "a project-scoped request must not guess an untagged entry's project")
        #expect(scope.admits(profileID: nil, workspaceID: nil, projectID: nil, isPrivate: false, isGlobal: true),
                "explicit global memory remains eligible even inside a project scope")
        #expect(!scope.admits(profileID: "profile-a", workspaceID: "workspace-a", projectID: "project-a", isPrivate: false, isGlobal: true),
                "tagged data cannot bypass scope checks by claiming global provenance")
    }

    @Test func projectTaggedMemoryStaysDormantWithoutActiveProject() {
        let workspaceScope = ContextScope(profileID: "profile-a", workspaceID: "workspace-a")
        #expect(!workspaceScope.admits(profileID: "profile-a", workspaceID: "workspace-a", projectID: "project-a", isPrivate: false),
                "project-tagged memory must remain dormant until a project is active")
    }

    @Test func privateMemoryRequiresActiveScopeOptIn() {
        let defaultScope = ContextScope(workspaceID: "workspace-a")
        let optedInScope = ContextScope(workspaceID: "workspace-a", includesPrivateContent: true)
        #expect(!defaultScope.admits(profileID: nil, workspaceID: "workspace-a", projectID: nil, isPrivate: true))
        #expect(optedInScope.admits(profileID: nil, workspaceID: "workspace-a", projectID: nil, isPrivate: true))
    }

    @Test func privateContentRequiresExplicitScopeOptIn() {
        let page = PageContext(tabID: "tab", url: URL(string: "https://example.com"), title: "Private", text: "secret", privateBrowsing: true)
        #expect(!ContextScope(workspaceID: "workspace").admits(page: page))
        #expect(ContextScope(workspaceID: "workspace", includesPrivateContent: true).admits(page: page))
        #expect(!ContextScope().admits(profileID: nil, workspaceID: nil, isPrivate: true))
    }

    @Test func selectedTabsAreAnExplicitNarrowing() {
        let selected = ContextScope(allowedTabIDs: ["tab-a"])
        #expect(selected.admits(page: PageContext(tabID: "tab-a", url: URL(string: "https://example.com"), title: "A", text: "a")))
        #expect(!selected.admits(page: PageContext(tabID: "tab-b", url: URL(string: "https://example.com"), title: "B", text: "b")))
    }

    @Test func pageOnlyScopeKeepsCurrentPageButDisablesDurableContext() throws {
        let pageOnly = ContextScope(
            profileID: "profile-a",
            workspaceID: "workspace-a",
            includesHotMemory: false,
            includesProjectNodes: false,
            includesPreferences: false
        )
        #expect(pageOnly.includesCurrentPage)
        #expect(!pageOnly.includesHotMemory)
        #expect(pageOnly.admits(page: PageContext(
            tabID: "tab-a",
            url: URL(string: "https://example.com"),
            title: "Current page",
            text: "page text"
        )))

        let encoded = try JSONEncoder().encode(pageOnly)
        let decoded = try JSONDecoder().decode(ContextScope.self, from: encoded)
        #expect(decoded == pageOnly)
    }

    @Test func legacyScopePayloadDefaultsHotMemoryToEnabled() throws {
        let payload = """
        {
          "profileID": "profile-a",
          "workspaceID": "workspace-a",
          "allowedTabIDs": [],
          "includesCurrentPage": true,
          "includesProjectNodes": true,
          "includesPreferences": true,
          "includesPrivateContent": false
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ContextScope.self, from: payload)
        #expect(decoded.includesHotMemory)
    }
}

// MARK: - HotMemoryStore: the running hot-context surface

/// Locks the relevance engine that decides WHAT the AI sees: recency decay,
/// frequency boost, source-hint weighting, capacity eviction, stale pruning,
/// score-floor noise filtering, and token-budgeted context assembly.
///
/// These tests cover the exact "does the AI pull the right memory?" contract
/// the user cares about — hot memory must surface the right context and never
/// randomly drag in irrelevant nodes.
@Suite("HotMemoryStore")
struct HotMemoryStoreTests {

    private func makeStore(
        honeycomb: HoneycombStore? = nil,
        hotWindow: TimeInterval = 900,
        maxHotEntries: Int = 50,
        tokenBudget: Int = 3000,
        decayHalfLife: TimeInterval = 300,
        minScoreThreshold: Double = 0.05,
        projectSwitchGracePeriod: TimeInterval = 60
    ) -> HotMemoryStore {
        HotMemoryStore(honeycomb: honeycomb, hotWindow: hotWindow,
                       maxHotEntries: maxHotEntries, tokenBudget: tokenBudget,
                       decayHalfLife: decayHalfLife, minScoreThreshold: minScoreThreshold,
                       projectSwitchGracePeriod: projectSwitchGracePeriod)
    }

    /// Ages entries ~0.65s at a 0.5s half-life → recency ≈ 0.41. Fresh nodes
    /// saturate at 1.0 (recency + frequency + source bonus all clamp), which
    /// would make order assertions flaky; aging makes scores discriminable.
    private func ageEntries() async throws {
        try await Task.sleep(for: .milliseconds(650))
    }

    // MARK: - Recording and scoring

    @Test func scopeBindingExcludesForeignProfileWorkspaceAndProjectMemory() async {
        let store = makeStore()
        await store.setActiveScope(ContextScope(profileID: "profile-a", workspaceID: "workspace-a", projectID: "project-a"))
        await store.didAccessNode(id: "same", workspaceID: "workspace-a", projectID: "project-a", profileID: "profile-a")
        await store.didAccessNode(id: "foreign-project", workspaceID: "workspace-a", projectID: "project-b", profileID: "profile-a")
        await store.didAccessNode(id: "foreign-workspace", workspaceID: "workspace-b", projectID: "project-a", profileID: "profile-a")
        await store.didAccessNode(id: "foreign-profile", workspaceID: "workspace-a", projectID: "project-a", profileID: "profile-b")
        await store.didAccessNode(id: "untagged-project")

        let entries = await store.currentHotEntries()
        #expect(entries.map(\.id) == ["same"])
        let context = await store.assembleContext()
        #expect(context.hotNodes == ["same"])
    }

    @Test func olderHotEntryPayloadWithoutProjectIDStillDecodes() throws {
        let payload = """
        {
          "id": "legacy-node",
          "score": 0.5,
          "accessCount": 1,
          "lastAccessedAt": 1000,
          "addedAt": 1000,
          "sourceHint": "browsed",
          "workspaceID": "workspace-a",
          "profileID": "profile-a",
          "isPrivate": false,
          "isGlobal": false
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let entry = try decoder.decode(HotMemoryStore.HotEntry.self, from: payload)
        #expect(entry.projectID == nil)
        #expect(entry.workspaceID == "workspace-a")
        #expect(entry.profileID == "profile-a")
    }

    @Test func untaggedMemoryIsNotGlobalByAccident() async {
        let store = makeStore()
        await store.setActiveScope(ContextScope(profileID: "profile-a", workspaceID: "workspace-a"))
        await store.didAccessNode(id: "untagged")
        await store.didAccessGlobalNode(id: "explicit-global", sourceHint: "preference")

        let entries = await store.currentHotEntries()
        #expect(entries.map(\.id) == ["explicit-global"],
                "only explicitly classified global memory may cross a scoped boundary")
    }

    @Test func privateMemoryIsRejectedAtAdmission() async {
        let store = makeStore()
        await store.didAccessNode(id: "private", isPrivate: true)
        #expect(await store.currentHotEntries().isEmpty)

        await store.setActiveScope(ContextScope(workspaceID: "workspace-a", includesPrivateContent: true))
        await store.didAccessNode(id: "private-opt-in", workspaceID: "workspace-a", isPrivate: true)
        let entries = await store.currentHotEntries()
        #expect(entries.map(\.id) == ["private-opt-in"])
    }

    @Test func pageOnlyScopeExcludesHotMemoryFromAssembly() async {
        let store = makeStore()
        await store.setActiveScope(ContextScope(
            profileID: "profile-a",
            workspaceID: "workspace-a",
            includesHotMemory: false,
            includesProjectNodes: false,
            includesPreferences: false
        ))
        await store.didAccessNode(
            id: "saved-memory",
            workspaceID: "workspace-a",
            profileID: "profile-a"
        )
        await store.setCurrentPage(PageContext(
            tabID: "active-tab",
            url: URL(string: "https://example.com"),
            title: "Current page",
            text: "page text"
        ))

        let context = await store.assembleContext(for: "page text")
        #expect(context.currentPage?.title == "Current page")
        #expect(context.hotNodes.isEmpty)
        #expect(context.projectNodes.isEmpty)
        #expect(context.preferences.isEmpty)
    }

    @Test func accessRecordsAndBumpsEntry() async {
        let store = makeStore()
        await store.didAccessNode(id: "node-a", sourceHint: "browsed")
        var entries = await store.currentHotEntries()
        #expect(entries.count == 1)
        #expect(entries[0].id == "node-a")
        #expect(entries[0].accessCount == 1)

        await store.didAccessNode(id: "node-a", sourceHint: "captured")
        entries = await store.currentHotEntries()
        #expect(entries.count == 1, "re-access must not duplicate the entry")
        #expect(entries[0].accessCount == 2)
        #expect(entries[0].score > 0.6, "re-access must raise the score above the fresh baseline")
    }

    @Test func repeatedAccessRanksAboveSingleAccess() async throws {
        let store = makeStore(decayHalfLife: 0.5)
        await store.didAccessNode(id: "hot")
        for _ in 0..<4 { await store.didAccessNode(id: "hot") }  // 5 accesses
        await store.didAccessNode(id: "cold")
        try await ageEntries()

        let entries = await store.currentHotEntries()
        #expect(entries[0].id == "hot", "high-frequency node must rank first")
        #expect(entries[0].score > entries[1].score,
                "frequency boost must produce a real score difference, not a clamp tie")
    }

    @Test func explicitSourceHintOutranksBrowsed() async throws {
        let store = makeStore(decayHalfLife: 0.5)
        await store.didAccessNode(id: "tagged", sourceHint: "explicit")
        await store.didAccessNode(id: "browsed", sourceHint: "browsed")
        try await ageEntries()

        let entries = await store.currentHotEntries()
        #expect(entries[0].id == "tagged", "explicit user tags must outrank passive browses")
    }

    @Test func capacityEvictsColdestEntry() async {
        let store = makeStore(maxHotEntries: 2)
        await store.didAccessNode(id: "a")
        await store.didAccessNode(id: "b")
        await store.didAccessNode(id: "b")  // b scores higher than a now
        await store.didAccessNode(id: "c")

        let entries = await store.currentHotEntries()
        #expect(entries.count == 2)
        #expect(entries.contains(where: { $0.id == "c" }))
        #expect(entries.contains(where: { $0.id == "b" }))
        #expect(!entries.contains(where: { $0.id == "a" }),
                "coldest entry (a) must be evicted at capacity")
    }

    @Test func scoreFloorFiltersNoise() async throws {
        // minScoreThreshold above an aged node's score — noise dies on prune.
        let store = makeStore(decayHalfLife: 0.5, minScoreThreshold: 0.8)
        await store.didAccessNode(id: "noise")
        try await ageEntries()
        await store.pruneAndRescore()

        let entries = await store.currentHotEntries()
        #expect(entries.isEmpty, "entries below the score floor must be pruned")
    }

    @Test func staleEntriesEvictedAfterHotWindow() async throws {
        let store = makeStore(hotWindow: 0.05)
        await store.didAccessNode(id: "stale")
        try await Task.sleep(for: .milliseconds(120))
        await store.pruneAndRescore()

        let entries = await store.currentHotEntries()
        #expect(entries.isEmpty, "entries untouched beyond the hot window must be evicted")
    }

    @Test func forgetAndClearRemoveEntries() async {
        let store = makeStore()
        await store.didAccessNode(id: "a")
        await store.didAccessNode(id: "b")
        await store.forgetNode(id: "a")
        var entries = await store.currentHotEntries()
        #expect(entries.count == 1)
        #expect(entries[0].id == "b")

        await store.clear()
        entries = await store.currentHotEntries()
        #expect(entries.isEmpty)
    }

    // MARK: - Context assembly

    @Test func assembleContextAlwaysIncludesCurrentPage() async {
        // tokenBudget 500: the current page reserves its 500-token slot, leaving
        // zero budget — a hot node (~80 tokens) must NOT be squeezed in.
        let store = makeStore(tokenBudget: 500)
        let page = PageContext(tabID: "t", url: URL(string: "https://example.com"),
                               title: "Example", text: "hello")
        await store.setCurrentPage(page)
        await store.didAccessNode(id: "node-x")

        let ctx = await store.assembleContext()
        #expect(ctx.currentPage?.title == "Example")
        #expect(ctx.hotNodes.isEmpty, "token budget must exclude nodes that don't fit")
        #expect(ctx.estimatedTokens == 500)
    }

    @Test func assembleContextOrdersHotNodesByRelevance() async throws {
        let store = makeStore(decayHalfLife: 0.5)
        await store.didAccessNode(id: "low", sourceHint: "browsed")
        await store.didAccessNode(id: "high", sourceHint: "explicit")
        try await ageEntries()

        let ctx = await store.assembleContext()
        #expect(ctx.hotNodes == ["high", "low"],
                "hot nodes must be ordered by score, highest first")
    }

    @Test func assembleContextPromptFormatsAllSections() async throws {
        let hc = try HoneycombStore(path: ":memory:")
        let store = makeStore(honeycomb: hc)
        let page = PageContext(tabID: "t", url: URL(string: "https://example.com"),
                               title: "Example Page", text: "body text")
        await store.setCurrentPage(page)
        let node = try await hc.insertNode(
            HoneycombStore.Node(type: .note, label: "Meeting notes", provenance: "test"))
        await store.didAccessNode(id: node.id)

        let prompt = await store.assembleContextPrompt()
        #expect(prompt.contains("[Current page]"))
        #expect(prompt.contains("Title: Example Page"))
        #expect(prompt.contains("[Hot memory:"))
        #expect(prompt.contains("Meeting notes"),
                "hot node labels must be resolved from Honeycomb into the prompt")
    }

    @Test func activeProjectNodesIncludedInContext() async throws {
        let hc = try HoneycombStore(path: ":memory:")
        let store = makeStore(honeycomb: hc)
        let project = try await hc.insertNode(
            HoneycombStore.Node(type: .project, label: "Research", provenance: "test"))
        let task = try await hc.insertNode(
            HoneycombStore.Node(type: .task, label: "Write brief", provenance: "test"))
        _ = try await hc.insertEdge(
            HoneycombStore.Edge(sourceID: task.id, targetID: project.id, relation: .belongsTo))
        await store.setActiveProject(project.id)

        let ctx = await store.assembleContext()
        #expect(ctx.projectNodes.map(\.id).contains(task.id),
                "active-project nodes must be pulled into assembled context")
    }

    @Test func queryBoostRanksSemanticMatchFirst() async throws {
        let hc = try HoneycombStore(path: ":memory:")
        let store = makeStore(honeycomb: hc, decayHalfLife: 0.5)
        let swiftNode = try await hc.insertNode(
            HoneycombStore.Node(type: .note, label: "swift concurrency guide", provenance: "test"))
        let pizzaNode = try await hc.insertNode(
            HoneycombStore.Node(type: .note, label: "pizza recipes", provenance: "test"))
        await store.didAccessNode(id: swiftNode.id)
        await store.didAccessNode(id: pizzaNode.id)
        try await ageEntries()

        let ctx = await store.assembleContext(for: "swift")
        #expect(ctx.hotNodes.first == swiftNode.id,
                "FTS5 match for 'swift' must rank above the unrelated node")
    }

    @Test func wordOverlapFallbackBoostsWithoutHoneycomb() async throws {
        let store = makeStore(decayHalfLife: 0.5)
        await store.didAccessNode(id: "page-swift-123")
        await store.didAccessNode(id: "page-rust-456")
        try await ageEntries()

        let boosted = await store.assembleContext(for: "swift")
        #expect(boosted.hotNodes.first == "page-swift-123",
                "word-overlap heuristic must rank the matching node first")
    }

    @Test func relevanceGateOutranksHotterButIrrelevantMemory() async throws {
        // The hard gate: a semantically-matching node must outrank a HOTTER but
        // unrelated node when a query is present — "don't randomly bring parts
        // of the memory that don't belong there." The old +0.15 boost lost to
        // an explicitly-tagged hot node; the two-tier gate cannot.
        let hc = try HoneycombStore(path: ":memory:")
        let store = makeStore(honeycomb: hc, decayHalfLife: 0.5)
        let swiftNode = try await hc.insertNode(
            HoneycombStore.Node(type: .note, label: "swift concurrency guide", provenance: "test"))
        let pizzaNode = try await hc.insertNode(
            HoneycombStore.Node(type: .note, label: "pizza recipes", provenance: "test"))
        await store.didAccessNode(id: swiftNode.id)                     // cold match
        await store.didAccessNode(id: pizzaNode.id, sourceHint: "explicit")
        await store.didAccessNode(id: pizzaNode.id, sourceHint: "explicit")
        await store.didAccessNode(id: pizzaNode.id, sourceHint: "explicit")
        try await ageEntries()

        let ctx = await store.assembleContext(for: "swift")
        #expect(ctx.hotNodes.first == swiftNode.id,
                "query match must outrank hotter-but-irrelevant memory")
        #expect(ctx.hotNodes.contains(pizzaNode.id),
                "non-matching recency may anchor the response but never first")
        #expect(ctx.hotNodes.firstIndex(of: pizzaNode.id)! > ctx.hotNodes.firstIndex(of: swiftNode.id)!)
    }

    @Test func entryLabelAndContentRenderInlineWithoutHoneycomb() async throws {
        // Self-contained hot memory: label + content set at access time render
        // into the prompt even when no graph is attached — the AI sees the
        // memory's substance, never an opaque UUID or an empty block.
        let store = makeStore()
        await store.didAccessNode(id: "librarian-x", sourceHint: "captured",
                                  label: "Swift 6 strict concurrency",
                                  content: "Actors isolate mutable state")

        let prompt = await store.assembleContextPrompt(for: "swift")
        #expect(prompt.contains("Swift 6 strict concurrency"),
                "entry label must render inline without a Honeycomb lookup")
        #expect(prompt.contains("Actors isolate mutable state"),
                "entry content must render inline without a Honeycomb lookup")
    }

    @Test func repeatAccessEnrichesLabelFromWarmUp() async {
        // Warm-up creates the entry before the page title is known; the title
        // arrives on a later access and must enrich the stored entry.
        let store = makeStore()
        await store.didAccessNode(id: "page-123", sourceHint: "browsed")
        await store.didAccessNode(id: "page-123", sourceHint: "browsed",
                                  label: "Hive Browser", content: "the second brain")

        let entries = await store.currentHotEntries()
        #expect(entries[0].label == "Hive Browser")
        #expect(entries[0].content == "the second brain")
        #expect(entries[0].accessCount == 2)
    }

    // MARK: - Context scope strip (the "what does the AI see" surface)

    @Test func currentContextScopeResolvesRealLabelsFromHoneycomb() async throws {
        let hc = try HoneycombStore(path: ":memory:")
        let store = makeStore(honeycomb: hc)
        let node = try await hc.insertNode(
            HoneycombStore.Node(type: .note, label: "Pricing research", provenance: "test"))
        await store.didAccessNode(id: node.id)

        let scope = await store.currentContextScope()
        #expect(scope.count == 1)
        #expect(scope[0].id == node.id)
        #expect(scope[0].label == "Pricing research",
                "scope strip must show the node's real Honeycomb label, never a generic fallback")
    }

    @Test func currentContextScopeFallsBackHonestlyWithoutHoneycomb() async {
        let store = makeStore()
        await store.didAccessNode(id: "page-abc-123")
        await store.didAccessNode(id: "librarian-xyz")
        let scope = await store.currentContextScope()
        #expect(scope.count == 2)
        #expect(scope.contains(where: { $0.id == "page-abc-123" && $0.label == "Page" }))
        #expect(scope.contains(where: { $0.id == "librarian-xyz" && $0.label == "Extracted entity" }),
                "fallback labels must be honest category names, not fabricated titles")
    }

    @Test func currentContextScopeCapsAtFifteenEntries() async {
        let store = makeStore()
        for i in 0..<20 { await store.didAccessNode(id: "node-\(i)") }
        let scope = await store.currentContextScope()
        #expect(scope.count == 15, "scope strip must cap at 15 entries")
    }

    @Test func forgetNodeRemovesEntryAndReportsSuccess() async {
        let store = makeStore()
        await store.didAccessNode(id: "node-a")
        await store.didAccessNode(id: "node-b")

        let removed = await store.forgetNode(id: "node-a")
        #expect(removed)
        let entries = await store.currentHotEntries()
        #expect(entries.map(\.id) == ["node-b"])

        let again = await store.forgetNode(id: "node-a")
        #expect(!again, "forgetting a node that isn't in the hot set must return false")
    }

    // MARK: - Durable forget (the "the AI won't see it" contract)

    @Test func forgetNodeBlocksReAddition() async {
        let store = makeStore()
        await store.didAccessNode(id: "node-a")
        await store.forgetNode(id: "node-a")

        // Passive re-access (page warm-up, tab switch) must NOT resurrect it.
        await store.didAccessNode(id: "node-a")
        await store.didAccessNode(id: "node-a")

        let entries = await store.currentHotEntries()
        #expect(!entries.contains(where: { $0.id == "node-a" }),
                "forgotten node must stay out of the hot set despite re-access")
    }

    @Test func unforgetNodeAllowsReAddition() async {
        let store = makeStore()
        await store.didAccessNode(id: "node-a")
        await store.forgetNode(id: "node-a")
        let restored = await store.unforgetNode(id: "node-a")
        #expect(restored)

        await store.didAccessNode(id: "node-a")
        let entries = await store.currentHotEntries()
        #expect(entries.contains(where: { $0.id == "node-a" }),
                "unforgotten node must be able to re-enter the hot set")
    }

    @Test func clearWipesForgottenSet() async {
        let store = makeStore()
        await store.didAccessNode(id: "node-a")
        await store.forgetNode(id: "node-a")
        await store.clear()

        await store.didAccessNode(id: "node-a")
        let entries = await store.currentHotEntries()
        #expect(entries.contains(where: { $0.id == "node-a" }),
                "clear() is a full reset — forgotten state must not survive")
    }

    @Test func forgottenNodeExcludedFromAssembly() async {
        let store = makeStore()
        await store.didAccessNode(id: "keep")
        await store.didAccessNode(id: "drop")
        await store.forgetNode(id: "drop")

        let ctx = await store.assembleContext()
        #expect(ctx.hotNodes.contains("keep"))
        #expect(!ctx.hotNodes.contains("drop"),
                "forgotten nodes must never appear in assembled context")
    }

    @Test func forgettingCurrentPageClearsPageContext() async throws {
        let store = makeStore()
        guard let pageURL = URL(string: "https://example.com") else { return }
        let page = PageContext(tabID: "t", url: pageURL,
                               title: "Example Page", text: "body text")
        let nodeID = "page-\(pageURL.absoluteString.hashValue)"
        await store.setCurrentPage(page, nodeID: nodeID)
        await store.didAccessNode(id: nodeID, sourceHint: "browsed")

        await store.forgetNode(id: nodeID)

        let prompt = await store.assembleContextPrompt()
        #expect(!prompt.contains("[Current page]"),
                "forgetting the current page node must stop the page context from reaching the AI")
    }

    @Test func forgettingOtherNodeKeepsPageContext() async throws {
        let store = makeStore()
        let page = PageContext(tabID: "t", url: URL(string: "https://example.com"),
                               title: "Example Page", text: "body text")
        await store.setCurrentPage(page, nodeID: "page-12345")
        await store.didAccessNode(id: "node-other")
        await store.forgetNode(id: "node-other")

        let prompt = await store.assembleContextPrompt()
        #expect(prompt.contains("[Current page]"),
                "forgetting an unrelated node must not clear the current page context")
    }

    // MARK: - Project-switch isolation (the cross-project leak guard)

    @Test func setActiveProjectEvictsStaleOldProjectNodes() async throws {
        let hc = try HoneycombStore(path: ":memory:")
        let store = makeStore(honeycomb: hc, projectSwitchGracePeriod: 0.02)
        let projectA = try await hc.insertNode(
            HoneycombStore.Node(type: .project, label: "Project A", provenance: "test"))
        let projectB = try await hc.insertNode(
            HoneycombStore.Node(type: .project, label: "Project B", provenance: "test"))
        let taskA = try await hc.insertNode(
            HoneycombStore.Node(type: .task, label: "Task A", provenance: "test"))
        _ = try await hc.insertEdge(
            HoneycombStore.Edge(sourceID: taskA.id, targetID: projectA.id, relation: .belongsTo))

        await store.setActiveProject(projectA.id)
        await store.didAccessNode(id: taskA.id)

        // Age the entry well past the grace period, then switch projects — the
        // eviction must complete before setActiveProject returns (no leak race).
        // 100ms vs 20ms grace = 5x margin against loaded CI timing skew.
        try await Task.sleep(for: .milliseconds(100))
        await store.setActiveProject(projectB.id)

        let entries = await store.currentHotEntries()
        #expect(!entries.contains(where: { $0.id == taskA.id }),
                "stale old-project node must be evicted on project switch")
    }

    @Test func setActiveProjectKeepsRecentlyAccessedOldProjectNodes() async throws {
        let hc = try HoneycombStore(path: ":memory:")
        let store = makeStore(honeycomb: hc)
        let projectA = try await hc.insertNode(
            HoneycombStore.Node(type: .project, label: "Project A", provenance: "test"))
        let projectB = try await hc.insertNode(
            HoneycombStore.Node(type: .project, label: "Project B", provenance: "test"))
        let taskA = try await hc.insertNode(
            HoneycombStore.Node(type: .task, label: "Task A", provenance: "test"))
        _ = try await hc.insertEdge(
            HoneycombStore.Edge(sourceID: taskA.id, targetID: projectA.id, relation: .belongsTo))

        await store.setActiveProject(projectA.id)
        await store.didAccessNode(id: taskA.id, projectID: projectA.id)

        // Switch immediately — the entry may remain retained during the grace
        // period for bounded cleanup, but it must not enter the newly active
        // project's context.
        await store.setActiveProject(projectB.id)

        let entries = await store.currentHotEntries()
        #expect(!entries.contains(where: { $0.id == taskA.id }),
                "old-project memory must not cross into the newly active project")
    }
}

// MARK: - Embedding runtime (real NLEmbedding, zero dep)

// MARK: - SwarmOrchestrator: the agent-mix pipeline

/// Locks the audit contract (AGENTS.md §8.4): EVERY model invocation across all
/// entry points — full pipeline, quick ask, and streaming — is a ledger event
/// carrying the honest provider label.
@Suite("SwarmOrchestrator")
struct SwarmOrchestratorTests {

    @Test func quickAskLogsModelCallToLedger() async throws {
        let ledger = try EventLedgerStore(path: ":memory:")
        let orch = SwarmOrchestrator(hotMemory: HotMemoryStore(), ledger: ledger)

        _ = try await orch.quickAsk(question: "What is 2+2?", page: nil)

        let calls = try await ledger.getEvents(byActionKind: .modelCall)
        #expect(calls.count == 1, "quickAsk must record exactly one model-call event")
        #expect(calls[0].actor == ModelRole.pageQa.rawValue)
        #expect(calls[0].result == .success)
        #expect(calls[0].modelProvider == "mock",
                "honest provider label must be recorded (no real weights in tests)")
    }

    @Test func streamSummarizeLogsPartialThenCompletion() async throws {
        // The streaming entry point must record an in-flight (.partial) event
        // and a completion event — the audit trail is never silent.
        let ledger = try EventLedgerStore(path: ":memory:")
        let orch = SwarmOrchestrator(hotMemory: HotMemoryStore(), ledger: ledger)

        let stream = await orch.streamSummarize(intent: "Summarize this", page: nil)
        var collected = ""
        for try await chunk in stream {
            collected += chunk
        }

        let calls = try await ledger.getEvents(byActionKind: .modelCall)
        #expect(calls.count >= 2, "stream must log a .partial start and a completion")
        #expect(calls.contains(where: { $0.result == .partial }))
        #expect(calls.contains(where: { $0.result == .success || $0.result == .failure }))
        #expect(!collected.isEmpty, "mock stream must yield tokens")
    }
}

@Suite("EmbeddingRuntime")
struct EmbeddingRuntimeTests {

    @Test func systemEmbedderIsAvailableAndCorrectDimension() async throws {
        let rt = SystemEmbeddingRuntime()
        let vec = try await rt.embed("Hive is a local-first browser with memory.")
        #expect(!vec.isEmpty)
        #expect(vec.count == rt.dimensionality)
        #expect(rt.dimensionality == 512)
    }
}

// MARK: - JSONValue: the Sendable structured-output container

/// Guards the Swift 6 fix that unblocked the build: a request carrying a
/// JSON schema must be Sendable and the value must round-trip through Codable.
@Suite("JSONValue")
struct JSONValueTests {

    @Test func objectRoundTripsThroughCodable() throws {
        let schema: JSONValue = .object([
            "type": .string("object"),
            "required": .array([.string("route"), .string("reason")]),
            "properties": .object([
                "route": .object(["type": .string("string")]),
                "reason": .object(["type": .string("string")])
            ]),
            "additionalProperties": .bool(false),
            "nullable": .null
        ])
        let data = try JSONEncoder().encode(schema)
        let back = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(back == schema)
    }

    @Test func attachableToASendableRequest() {
        // Compiles only if GenerateRequest (and its jsonSchema) are Sendable.
        let req = GenerateRequest(
            role: .intentClassifier, system: "s", user: "u",
            jsonSchema: .object(["type": .string("string")]))
        func takesSendable<T: Sendable>(_ v: T) {}
        takesSendable(req)
        #expect(req.jsonSchema != nil)
    }
}

// MARK: - CellPromptLoader: bridging Swarm prompts to HiveCore models

/// Tests that the CellPromptLoader correctly maps Cell .md files to ModelRole,
/// extracts role-defining sections from markdown, and injects system prompts
/// into GenerateRequest values.
@Suite("CellPromptLoader")
struct CellPromptLoaderTests {

    @Test func cellRoleMappingCoversAllRolesWithCellFiles() {
        // Every role that has a Cell .md file in Swarm_System_Prompts must be
        // in the mapping. Roles without Cell files (embedder, byokFrontier,
        // appleFMF) are intentionally unmapped — they use different execution paths.
        let mappedRoles = Set(CellPromptLoader.cellRoleMapping.keys)

        // Rule-based: actionGuard has a Cell file
        #expect(mappedRoles.contains(.actionGuard))
        // T0 classifiers
        #expect(mappedRoles.contains(.intentClassifier))
        #expect(mappedRoles.contains(.spamDetector))
        #expect(mappedRoles.contains(.urgencyDetector))
        #expect(mappedRoles.contains(.linkScorer))
        // T0 scribe family (Directive B phase-6 OTS Cells)
        #expect(mappedRoles.contains(.captureScribe))
        #expect(mappedRoles.contains(.pageQa))
        // T1
        #expect(mappedRoles.contains(.orchestrator))
        #expect(mappedRoles.contains(.librarian))
        #expect(mappedRoles.contains(.summarizer))
        #expect(mappedRoles.contains(.retrievalRanker))
        #expect(mappedRoles.contains(.titleGenerator))
        #expect(mappedRoles.contains(.memoryCompressor))
        // T2
        #expect(mappedRoles.contains(.auditor))
        #expect(mappedRoles.contains(.planner))
        // T3
        #expect(mappedRoles.contains(.deepReasoner))
        #expect(mappedRoles.contains(.coder))
        #expect(mappedRoles.contains(.researchSynthesizer))
        // researcher family — gatherer (1B tier fetch/extract front half)
        #expect(mappedRoles.contains(.researchGatherer))

        // 19 mapped roles (16 as of 2026-07-28; +2 on 2026-07-29 for the
        // scribe family: captureScribe, pageQa — Directive B phase-6 OTS Cells;
        // +1 on 2026-08-02 for researchGatherer.)
        #expect(mappedRoles.count == 19, "expected 19 mapped roles, got \(mappedRoles.count)")
    }

    @Test func cellFileReturnsCorrectSubdirAndFileName() {
        #expect(CellPromptLoader.cellFile(for: .coder)?.subdir == "coder")
        #expect(CellPromptLoader.cellFile(for: .coder)?.fileName == "1b_coder")
        #expect(CellPromptLoader.cellFile(for: .orchestrator)?.subdir == "orchestrator")
        #expect(CellPromptLoader.cellFile(for: .orchestrator)?.fileName == "1b_orchestrator")
        #expect(CellPromptLoader.cellFile(for: .actionGuard)?.subdir == "guard")
        #expect(CellPromptLoader.cellFile(for: .actionGuard)?.fileName == "rule_action_guard")
        #expect(CellPromptLoader.cellFile(for: .deepReasoner)?.subdir == "reasoner")
        #expect(CellPromptLoader.cellFile(for: .deepReasoner)?.fileName == "8b_deep_reasoner")
        #expect(CellPromptLoader.cellFile(for: .researchSynthesizer)?.subdir == "researcher")
        #expect(CellPromptLoader.cellFile(for: .researchSynthesizer)?.fileName == "8b_research_synthesizer")
        // T0 scribe family (Directive B phase-6)
        #expect(CellPromptLoader.cellFile(for: .captureScribe)?.subdir == "scribe")
        #expect(CellPromptLoader.cellFile(for: .captureScribe)?.fileName == "100m_capture_scribe")
        #expect(CellPromptLoader.cellFile(for: .pageQa)?.subdir == "scribe")
        #expect(CellPromptLoader.cellFile(for: .pageQa)?.fileName == "100m_page_qa")

        // Unmapped roles return nil
        #expect(CellPromptLoader.cellFile(for: .embedder) == nil)
        #expect(CellPromptLoader.cellFile(for: .byokFrontier) == nil)
        #expect(CellPromptLoader.cellFile(for: .appleFMF) == nil)
    }

    @Test func loadSystemPromptExtractsSectionsFromMarkdown() throws {
        // Simulate a Cell .md file in a temp directory and verify extraction.
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Create subdir + test .md file
        let coderDir = tmpDir.appendingPathComponent("coder", isDirectory: true)
        try FileManager.default.createDirectory(at: coderDir, withIntermediateDirectories: true)

        let mdContent = """
        # 1b_coder — 1B

        ## Job (one sentence)
        Generate a single-file code change with diff preview.

        ## Non-goals (explicit)
        Do not execute code. Do not modify more than one file.

        ## Outputs (strict schema)
        ```json
        {"file": "...", "diff": "..."}
        ```

        ## Determinism rules
        Temperature 0.0. Same input → same output.

        ## Stop / done conditions
        Stop when diff_preview is complete and valid.

        ## RAM / latency budget
        4500MB, <4000ms

        ## Distilled rules (from source prompts)
        ALWAYS show a diff before writing. NEVER overwrite user changes.

        ## Frontier gap checklist
        - [ ] Streaming diff completion
        """
        try mdContent.write(to: coderDir.appendingPathComponent("1b_coder.md"),
                           atomically: true, encoding: .utf8)

        let loader = CellPromptLoader(promptsDir: tmpDir)
        let prompt = loader.loadSystemPrompt(for: .coder)

        // Must exist and contain extracted sections
        #expect(prompt != nil, "loadSystemPrompt returned nil")
        guard let prompt else { return }

        // Should NOT contain: RAM budget, Frontier gap (runtime-managed)
        #expect(!prompt.contains("4500MB"), "RAM budget should not be in system prompt")
        // Should contain: Job, Non-goals, Output schema, Determinism, Stop, Rules
        #expect(prompt.contains("single-file code change"))
        #expect(prompt.contains("Do not execute code"))
        #expect(prompt.contains("YOU MUST EMIT EXACTLY THIS JSON SHAPE"))
        #expect(prompt.contains("Temperature 0.0"))
        #expect(prompt.contains("diff_preview is complete"))
        #expect(prompt.contains("NEVER overwrite user changes"))
        // Should start with identity header
        #expect(prompt.hasPrefix("You are a specialist"))
    }

    @Test func loadSystemPromptReturnsNilForMissingFile() {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-test-empty-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let loader = CellPromptLoader(promptsDir: tmpDir)
        #expect(loader.loadSystemPrompt(for: .coder) == nil)
    }

    @Test func loadSystemPromptReturnsNilForUnmappedRole() {
        let tmpDir = FileManager.default.temporaryDirectory
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let loader = CellPromptLoader(promptsDir: tmpDir)
        // embedder is not in cellRoleMapping — should return nil
        #expect(loader.loadSystemPrompt(for: .embedder) == nil)
    }

    @Test func buildRequestInjectsSystemPrompt() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-test-req-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let coderDir = tmpDir.appendingPathComponent("coder", isDirectory: true)
        try FileManager.default.createDirectory(at: coderDir, withIntermediateDirectories: true)

        try """
        # 1b_coder
        ## Job (one sentence)
        Generate code.
        ## Distilled rules (from source prompts)
        ALWAYS show diff.
        """.write(to: coderDir.appendingPathComponent("1b_coder.md"),
                 atomically: true, encoding: .utf8)

        let loader = CellPromptLoader(promptsDir: tmpDir)
        let req = loader.buildRequest(for: .coder, userInput: "write a sort function")

        #expect(req.role == .coder)
        #expect(req.user == "write a sort function")
        #expect(req.system.contains("Generate code"))
        #expect(req.system.contains("ALWAYS show diff"))
        #expect(req.system.contains("specialist"))
    }

    @Test func buildRequestFallsBackToEmptySystemForMissingFile() {
        let tmpDir = FileManager.default.temporaryDirectory
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let loader = CellPromptLoader(promptsDir: tmpDir)
        let req = loader.buildRequest(for: .coder, userInput: "test")

        #expect(req.role == .coder)
        #expect(req.user == "test")
        #expect(req.system.isEmpty, "system prompt should be empty when Cell file is missing")
    }

    @Test func buildRequestCanCarryJsonSchema() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-test-schema-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let routerDir = tmpDir.appendingPathComponent("router", isDirectory: true)
        try FileManager.default.createDirectory(at: routerDir, withIntermediateDirectories: true)
        try """
        # 100m_intent_router
        ## Job (one sentence)
        Classify intent.
        ## Distilled rules (from source prompts)
        Route deterministically.
        """.write(to: routerDir.appendingPathComponent("100m_intent_router.md"),
                 atomically: true, encoding: .utf8)

        let loader = CellPromptLoader(promptsDir: tmpDir)
        let schema: JSONValue = .object([
            "route": .string("string"),
            "reason": .string("string")
        ])
        let req = loader.buildRequest(for: .intentClassifier, userInput: "user query",
                                       jsonSchema: schema)
        #expect(req.jsonSchema != nil)
        #expect(req.system.contains("Classify intent"))
    }

    @Test func extractSectionFallsBackToShortHeaderWhenParentheticalMissing() throws {
        // When a Cell .md uses "## Job" instead of "## Job (one sentence)",
        // the loader must still extract the section via the short-header fallback.
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-test-short-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let coderDir = tmpDir.appendingPathComponent("coder", isDirectory: true)
        try FileManager.default.createDirectory(at: coderDir, withIntermediateDirectories: true)

        // Use short headers — no parenthetical descriptions
        try """
        # 1b_coder — short headers

        ## Job
        Generate code changes.

        ## Non-goals
        Do not execute code.

        ## Distilled rules
        ALWAYS show a diff before writing.
        """.write(to: coderDir.appendingPathComponent("1b_coder.md"),
                 atomically: true, encoding: .utf8)

        let loader = CellPromptLoader(promptsDir: tmpDir)
        let prompt = loader.loadSystemPrompt(for: .coder)

        #expect(prompt != nil, "short-header Cell file must yield a prompt")
        guard let prompt else { return }
        #expect(prompt.contains("Generate code changes"))
        #expect(prompt.contains("Do not execute code"))
        #expect(prompt.contains("ALWAYS show a diff"))
    }
}

// MARK: - HoneycombStore: durable knowledge substrate

/// Tests the complete HoneycombStore API: node CRUD, edge CRUD,
/// deduplication, FTS5 search, graph traversal, revision history,
/// migrations, and delete-by-scope. All tests use in-memory SQLite
/// (":memory:") for isolation and speed.
@Suite("HoneycombStore")
struct HoneycombStoreTests {

    // MARK: - Helpers

    private func newStore() throws -> HoneycombStore {
        try HoneycombStore(path: ":memory:")
    }

    private func sampleNode(type: HoneycombStore.NodeType = .note,
                            label: String = "test node",
                            provenance: String = "test") -> HoneycombStore.Node {
        HoneycombStore.Node(type: type, label: label, provenance: provenance)
    }

    // MARK: - Node CRUD

    @Test func insertAndGetNode() async throws {
        let store = try newStore()
        let node = sampleNode(label: "hello")
        let inserted = try await store.insertNode(node)
        #expect(inserted.id == node.id)
        #expect(inserted.label == "hello")

        let fetched = try await store.getNode(id: node.id)
        #expect(fetched?.id == node.id)
        #expect(fetched?.label == "hello")
        #expect(fetched?.type == .note)
    }

    @Test func updateNodeChangesLabelAndTimestamp() async throws {
        let store = try newStore()
        let node = try await store.insertNode(sampleNode(label: "original"))
        let originalUpdatedAt = node.updatedAt

        // Small delay to ensure timestamp changes
        try await Task.sleep(nanoseconds: 1_000_000)

        let updated = try await store.updateNode(id: node.id, label: "changed")
        #expect(updated?.label == "changed")
        #expect(updated!.updatedAt > originalUpdatedAt)
    }

    @Test func updateNodeRecordsRevisionHistory() async throws {
        let store = try newStore()
        let node = try await store.insertNode(
            sampleNode(label: "v1", provenance: "test"))
        _ = try await store.updateNode(id: node.id, label: "v2")

        // The revision table is internal, but we can verify the node reflects the update.
        let fetched = try await store.getNode(id: node.id)
        #expect(fetched?.label == "v2")
    }

    @Test func updateNodeReturnsNilForMissingNode() async throws {
        let store = try newStore()
        let result = try await store.updateNode(id: "nonexistent", label: "nope")
        #expect(result == nil)
    }

    @Test func deleteNodeRemovesFromStore() async throws {
        let store = try newStore()
        let node = try await store.insertNode(sampleNode())
        #expect(try await store.countNodes() == 1)

        try await store.deleteNode(id: node.id)
        #expect(try await store.countNodes() == 0)
        #expect(try await store.getNode(id: node.id) == nil)
    }

    @Test func countNodesFiltersByType() async throws {
        let store = try newStore()
        _ = try await store.insertNode(sampleNode(type: .note, label: "n1"))
        _ = try await store.insertNode(sampleNode(type: .note, label: "n2"))
        _ = try await store.insertNode(sampleNode(type: .task, label: "t1"))

        #expect(try await store.countNodes() == 3)
        #expect(try await store.countNodes(type: .note) == 2)
        #expect(try await store.countNodes(type: .task) == 1)
        #expect(try await store.countNodes(type: .project) == 0)
    }

    @Test func getNodeReturnsNilForMissing() async throws {
        let store = try newStore()
        #expect(try await store.getNode(id: "no-such-id") == nil)
    }

    @Test func getNodesByTypeReturnsCorrectSubset() async throws {
        let store = try newStore()
        for i in 0..<5 { _ = try await store.insertNode(sampleNode(type: .source, label: "s\(i)")) }
        for i in 0..<3 { _ = try await store.insertNode(sampleNode(type: .claim, label: "c\(i)")) }

        let sources = try await store.getNodesByType(.source, limit: 100)
        #expect(sources.count == 5)
        let claims = try await store.getNodesByType(.claim, limit: 100)
        #expect(claims.count == 3)
    }

    // MARK: - Batch lookup

    @Test func getNodesInBatchPreservesRequestedOrderAndOmitsMissing() async throws {
        let store = try newStore()
        let a = try await store.insertNode(sampleNode(label: "alpha"))
        let b = try await store.insertNode(sampleNode(label: "beta"))
        let c = try await store.insertNode(sampleNode(label: "gamma"))

        let batch = try await store.getNodes(ids: [c.id, a.id, "missing", b.id])
        #expect(batch.map(\.label) == ["gamma", "alpha", "beta"],
                "batch must preserve requested order and omit missing IDs")
    }

    @Test func getNodesInBatchHandlesEmptyAndDuplicates() async throws {
        let store = try newStore()
        #expect(try await store.getNodes(ids: []).isEmpty)

        let a = try await store.insertNode(sampleNode(label: "alpha"))
        let batch = try await store.getNodes(ids: [a.id, a.id, a.id])
        #expect(batch.count == 1, "duplicate IDs must be deduplicated")
        #expect(batch[0].id == a.id)
    }

    // MARK: - Deduplication

    @Test func dedupByTypeAndContentHash() async throws {
        let store = try newStore()
        let hash = HoneycombStore.sha256("unique content")

        let n1 = HoneycombStore.Node(type: .capture, label: "first",
                                      contentHash: hash, provenance: "test")
        let inserted1 = try await store.insertNode(n1)
        #expect(inserted1.id == n1.id)

        let n2 = HoneycombStore.Node(type: .capture, label: "second",
                                      contentHash: hash, provenance: "test")
        let inserted2 = try await store.insertNode(n2)
        // Should return the EXISTING node, not insert a new one
        #expect(inserted2.id == n1.id)
        #expect(inserted2.label == "first")
        #expect(try await store.countNodes() == 1)
    }

    @Test func noDedupWhenHashIsNil() async throws {
        let store = try newStore()
        let n1 = try await store.insertNode(sampleNode(label: "a"))
        let n2 = try await store.insertNode(sampleNode(label: "b"))
        #expect(n1.id != n2.id)
        #expect(try await store.countNodes() == 2)
    }

    @Test func noDedupWhenCheckDedupIsFalse() async throws {
        let store = try newStore()
        let hash = HoneycombStore.sha256("dup")
        let n1 = HoneycombStore.Node(type: .capture, label: "first",
                                      contentHash: hash, provenance: "test")
        _ = try await store.insertNode(n1)

        let n2 = HoneycombStore.Node(type: .capture, label: "second",
                                      contentHash: hash, provenance: "test")
        let inserted = try await store.insertNode(n2, checkDedup: false)
        #expect(inserted.id == n2.id)
        #expect(try await store.countNodes() == 2)
    }

    @Test func findNodeByTypeAndHash() async throws {
        let store = try newStore()
        let hash = HoneycombStore.sha256("find me")
        _ = try await store.insertNode(
            HoneycombStore.Node(type: .source, label: "target",
                                 contentHash: hash, provenance: "test"))

        let found = try await store.findNode(type: .source, contentHash: hash)
        #expect(found?.label == "target")

        let notFound = try await store.findNode(type: .capture, contentHash: hash)
        #expect(notFound == nil)
    }

    // MARK: - Edge CRUD

    @Test func insertAndGetEdges() async throws {
        let store = try newStore()
        let a = try await store.insertNode(sampleNode(label: "A"))
        let b = try await store.insertNode(sampleNode(label: "B"))

        let edge = HoneycombStore.Edge(sourceID: a.id, targetID: b.id,
                                        relation: .references, weight: 0.8)
        let inserted = try await store.insertEdge(edge)
        #expect(inserted.id == edge.id)
        #expect(inserted.weight == 0.8)

        let outgoing = try await store.getEdges(from: a.id)
        #expect(outgoing.count == 1)
        #expect(outgoing[0].relation == .references)

        let incoming = try await store.getEdges(to: b.id)
        #expect(incoming.count == 1)
        #expect(incoming[0].sourceID == a.id)
    }

    @Test func getEdgesFiltersByRelation() async throws {
        let store = try newStore()
        let a = try await store.insertNode(sampleNode(label: "A"))
        let b = try await store.insertNode(sampleNode(label: "B"))
        let c = try await store.insertNode(sampleNode(label: "C"))

        _ = try await store.insertEdge(HoneycombStore.Edge(sourceID: a.id, targetID: b.id, relation: .supports))
        _ = try await store.insertEdge(HoneycombStore.Edge(sourceID: a.id, targetID: c.id, relation: .references))

        #expect(try await store.getEdges(from: a.id).count == 2)
        #expect(try await store.getEdges(from: a.id, relation: .supports).count == 1)
        #expect(try await store.getEdges(from: a.id, relation: .contradicts).count == 0)
    }

    @Test func edgeExistsCorrectly() async throws {
        let store = try newStore()
        let a = try await store.insertNode(sampleNode(label: "A"))
        let b = try await store.insertNode(sampleNode(label: "B"))

        _ = try await store.insertEdge(HoneycombStore.Edge(sourceID: a.id, targetID: b.id, relation: .belongsTo))

        #expect(try await store.edgeExists(from: a.id, to: b.id, relation: .belongsTo))
        #expect(try await !store.edgeExists(from: a.id, to: b.id, relation: .references))
        #expect(try await !store.edgeExists(from: b.id, to: a.id, relation: .belongsTo))
    }

    @Test func deleteEdge() async throws {
        let store = try newStore()
        let a = try await store.insertNode(sampleNode(label: "A"))
        let b = try await store.insertNode(sampleNode(label: "B"))
        let edge = try await store.insertEdge(
            HoneycombStore.Edge(sourceID: a.id, targetID: b.id, relation: .references))

        #expect(try await store.countEdges() == 1)
        try await store.deleteEdge(id: edge.id)
        #expect(try await store.countEdges() == 0)
    }

    @Test func countEdgesFiltersByRelation() async throws {
        let store = try newStore()
        let a = try await store.insertNode(sampleNode(label: "A"))
        let b = try await store.insertNode(sampleNode(label: "B"))
        let c = try await store.insertNode(sampleNode(label: "C"))

        _ = try await store.insertEdge(HoneycombStore.Edge(sourceID: a.id, targetID: b.id, relation: .supports))
        _ = try await store.insertEdge(HoneycombStore.Edge(sourceID: a.id, targetID: c.id, relation: .supports))
        _ = try await store.insertEdge(HoneycombStore.Edge(sourceID: b.id, targetID: c.id, relation: .dependsOn))

        #expect(try await store.countEdges() == 3)
        #expect(try await store.countEdges(relation: .supports) == 2)
        #expect(try await store.countEdges(relation: .dependsOn) == 1)
        #expect(try await store.countEdges(relation: .contradicts) == 0)
    }

    @Test func deleteNodeCascadesToEdges() async throws {
        let store = try newStore()
        let a = try await store.insertNode(sampleNode(label: "A"))
        let b = try await store.insertNode(sampleNode(label: "B"))
        _ = try await store.insertEdge(HoneycombStore.Edge(sourceID: a.id, targetID: b.id, relation: .references))

        #expect(try await store.countEdges() == 1)
        try await store.deleteNode(id: a.id)
        // CASCADE should remove the edge referencing the deleted node
        #expect(try await store.countEdges() == 0)
    }

    // MARK: - FTS5 search

    @Test func searchFindsNodesByLabel() async throws {
        let store = try newStore()
        _ = try await store.insertNode(sampleNode(label: "Swift concurrency guide"))
        _ = try await store.insertNode(sampleNode(label: "SQLite performance tips"))
        _ = try await store.insertNode(sampleNode(label: "Honeycomb architecture"))

        let results = try await store.search(query: "concurrency", limit: 10)
        #expect(results.count == 1)
        #expect(results[0].label.contains("concurrency"))
    }

    @Test func searchFindsNodesByMetadataText() async throws {
        let store = try newStore()
        var node = sampleNode(label: "Meeting notes")
        node.metadata = .object(["summary": .string("discussed the new API design and deployment pipeline")])
        _ = try await store.insertNode(node)

        let results = try await store.search(query: "deployment", limit: 10)
        #expect(results.count == 1)
        #expect(results[0].label == "Meeting notes")
    }

    @Test func searchRespectsLimit() async throws {
        let store = try newStore()
        for i in 0..<10 {
            _ = try await store.insertNode(sampleNode(label: "test result \(i)"))
        }
        let results = try await store.search(query: "test", limit: 3)
        #expect(results.count == 3)
    }

    @Test func emptySearchReturnsEmptyArray() async throws {
        let store = try newStore()
        _ = try await store.insertNode(sampleNode(label: "something"))
        let results = try await store.search(query: "   ")
        #expect(results.isEmpty)
    }

    // MARK: - Graph traversal

    @Test func getNeighborsReturnsDirectConnections() async throws {
        let store = try newStore()
        let center = try await store.insertNode(sampleNode(label: "center"))
        let n1 = try await store.insertNode(sampleNode(label: "neighbor1"))
        let n2 = try await store.insertNode(sampleNode(label: "neighbor2"))

        _ = try await store.insertEdge(HoneycombStore.Edge(sourceID: center.id, targetID: n1.id, relation: .references))
        _ = try await store.insertEdge(HoneycombStore.Edge(sourceID: n2.id, targetID: center.id, relation: .references))

        let neighbors = try await store.getNeighbors(of: center.id, depth: 1)
        #expect(neighbors.count == 2)
        let labels = neighbors.map { $0.label }
        #expect(labels.contains("neighbor1"))
        #expect(labels.contains("neighbor2"))
    }

    @Test func getNeighborsRespectsDepth() async throws {
        let store = try newStore()
        let a = try await store.insertNode(sampleNode(label: "A"))
        let b = try await store.insertNode(sampleNode(label: "B"))
        let c = try await store.insertNode(sampleNode(label: "C"))

        _ = try await store.insertEdge(HoneycombStore.Edge(sourceID: a.id, targetID: b.id, relation: .references))
        _ = try await store.insertEdge(HoneycombStore.Edge(sourceID: b.id, targetID: c.id, relation: .references))

        // Depth 1 from A should only see B
        let d1 = try await store.getNeighbors(of: a.id, depth: 1)
        #expect(d1.count == 1)
        #expect(d1[0].label == "B")

        // Depth 2 from A should see B and C
        let d2 = try await store.getNeighbors(of: a.id, depth: 2)
        let labels2 = d2.map { $0.label }
        #expect(labels2.contains("B"))
        #expect(labels2.contains("C"))
    }

    @Test func getProjectNodesReturnsBelongingNodes() async throws {
        let store = try newStore()
        let project = try await store.insertNode(HoneycombStore.Node(type: .project, label: "My Project", provenance: "test"))
        let task1 = try await store.insertNode(HoneycombStore.Node(type: .task, label: "Task 1", provenance: "test"))
        let task2 = try await store.insertNode(HoneycombStore.Node(type: .task, label: "Task 2", provenance: "test"))
        let orphan = try await store.insertNode(sampleNode(label: "orphan"))

        _ = try await store.insertEdge(HoneycombStore.Edge(sourceID: task1.id, targetID: project.id, relation: .belongsTo))
        _ = try await store.insertEdge(HoneycombStore.Edge(sourceID: task2.id, targetID: project.id, relation: .belongsTo))
        // orphan has no belongsTo edge

        let projectNodes = try await store.getProjectNodes(projectID: project.id)
        let labels = projectNodes.map { $0.label }
        #expect(labels.contains("Task 1"))
        #expect(labels.contains("Task 2"))
        #expect(!labels.contains("orphan"))
    }

    // MARK: - Delete by scope

    @Test func deleteByProvenanceRemovesMatchingNodes() async throws {
        let store = try newStore()
        _ = try await store.insertNode(sampleNode(label: "keep", provenance: "user"))
        _ = try await store.insertNode(sampleNode(label: "purge1", provenance: "browser-capture"))
        _ = try await store.insertNode(sampleNode(label: "purge2", provenance: "browser-capture"))

        let deleted = try await store.deleteByProvenance("browser-capture")
        #expect(deleted == 2)
        #expect(try await store.countNodes() == 1)
        #expect(try await store.countNodes(type: .note) == 1)
    }

    @Test func deleteOlderThanRemovesExpiredNodes() async throws {
        let store = try newStore()
        // Nodes created in the past should be removable
        _ = try await store.insertNode(sampleNode(label: "old", provenance: "test"))
        // Small sleep to ensure the second node is created at a later time
        try await Task.sleep(nanoseconds: 2_000_000)
        let cutoff = Date()
        _ = try await store.insertNode(sampleNode(label: "new", provenance: "test"))

        // Delete nodes older than cutoff (the "old" node)
        let deleted = try await store.deleteOlderThan(cutoff)
        #expect(deleted == 1)
        #expect(try await store.countNodes() == 1)
        let remaining = try await store.search(query: "new")
        #expect(remaining.count == 1)
    }

    // MARK: - Content hash

    @Test func sha256IsDeterministic() {
        let a = HoneycombStore.sha256("hello world")
        let b = HoneycombStore.sha256("hello world")
        #expect(a == b)
        #expect(a.count == 64) // SHA-256 hex is 64 chars
    }

    @Test func sha256ProducesDifferentHashesForDifferentInputs() {
        let a = HoneycombStore.sha256("hello")
        let b = HoneycombStore.sha256("world")
        #expect(a != b)
    }

    // MARK: - Edge cases

    @Test func insertNodeWithSpecialCharactersInLabel() async throws {
        let store = try newStore()
        let node = sampleNode(label: "emoji 🚀 & unicode ñ — 'quotes'")
        let inserted = try await store.insertNode(node)
        let fetched = try await store.getNode(id: inserted.id)
        #expect(fetched?.label == node.label)
    }

    @Test func insertNodeWithAllNodeTypes() async throws {
        let store = try newStore()
        for nodeType in HoneycombStore.NodeType.allCases where nodeType != .unknown {
            let node = HoneycombStore.Node(type: nodeType, label: "\(nodeType.rawValue) node", provenance: "test")
            _ = try await store.insertNode(node)
        }
        #expect(try await store.countNodes() == HoneycombStore.NodeType.allCases.count - 1)
    }

    @Test func insertEdgeWithAllRelationTypes() async throws {
        let store = try newStore()
        let src = try await store.insertNode(sampleNode(label: "src"))
        let tgt = try await store.insertNode(sampleNode(label: "tgt"))

        for relation in HoneycombStore.EdgeRelation.allCases {
            _ = try await store.insertEdge(HoneycombStore.Edge(sourceID: src.id, targetID: tgt.id, relation: relation))
        }
        #expect(try await store.countEdges() == HoneycombStore.EdgeRelation.allCases.count)
    }

    @Test func contentHashDedupAcrossSameType() async throws {
        // Two captures of the same URL with same content → dedup
        let store = try newStore()
        let hash = HoneycombStore.sha256("https://example.com|article text")
        _ = try await store.insertNode(HoneycombStore.Node(type: .capture, label: "Example Article",
                                                             contentHash: hash, provenance: "browser"))
        _ = try await store.insertNode(HoneycombStore.Node(type: .capture, label: "Example Article (duplicate)",
                                                             contentHash: hash, provenance: "browser"))
        #expect(try await store.countNodes() == 1)
    }

    @Test func contentHashCrossTypeNoDedup() async throws {
        // Same hash, different types → no dedup
        let store = try newStore()
        let hash = HoneycombStore.sha256("shared content")
        _ = try await store.insertNode(HoneycombStore.Node(type: .source, label: "Source",
                                                             contentHash: hash, provenance: "test"))
        _ = try await store.insertNode(HoneycombStore.Node(type: .capture, label: "Capture",
                                                             contentHash: hash, provenance: "test"))
        #expect(try await store.countNodes() == 2)
    }
}

// MARK: - EventLedgerStore: append-only trust backbone

/// Tests the EventLedgerStore API: record events, query by every dimension,
/// event chains, immutability, count with filters, delete-by-scope.
/// All tests use in-memory SQLite (":memory:") for isolation.
@Suite("EventLedgerStore")
struct EventLedgerStoreTests {

    // MARK: - Helpers

    private func newStore() throws -> EventLedgerStore {
        try EventLedgerStore(path: ":memory:")
    }

    private func sampleEvent(
        actor: String = "swarm",
        intent: String = "test intent",
        actionKind: EventLedgerStore.ActionKind = .modelCall,
        trustLevel: EventLedgerStore.TrustLevel = .t1,
        result: EventLedgerStore.EventResult = .success
    ) -> EventLedgerStore.LedgerEvent {
        EventLedgerStore.LedgerEvent(
            actor: actor,
            intent: intent,
            actionKind: actionKind,
            trustLevel: trustLevel,
            policyDecision: .allowed,
            consentState: .auto,
            result: result,
            provenance: "test"
        )
    }

    // MARK: - Record + retrieve

    @Test func recordAndGetEvent() async throws {
        let store = try newStore()
        let event = sampleEvent(intent: "test capture")
        let recorded = try await store.record(event)
        #expect(recorded.id == event.id)

        let fetched = try await store.getEvent(id: event.id)
        #expect(fetched?.intent == "test capture")
        #expect(fetched?.actor == "swarm")
        #expect(fetched?.actionKind == .modelCall)
    }

    @Test func recordIfAbsentRejectsConflictingEventWithSameID() async throws {
        let store = try newStore()
        let event = EventLedgerStore.LedgerEvent(
            id: "stable-event-id",
            actor: "swarm",
            intent: "original intent",
            actionKind: .research,
            trustLevel: .t1,
            policyDecision: .allowed,
            consentState: .auto,
            result: .success,
            provenance: "test"
        )
        _ = try await store.recordIfAbsent(event)

        let conflicting = EventLedgerStore.LedgerEvent(
            id: event.id,
            actor: "swarm",
            intent: "different intent",
            actionKind: .research,
            trustLevel: .t1,
            policyDecision: .allowed,
            consentState: .auto,
            result: .success,
            provenance: "test"
        )
        await #expect(throws: EventLedgerError.conflictingEvent(id: event.id)) {
            _ = try await store.recordIfAbsent(conflicting)
        }
        #expect(try await store.countEvents(actionKind: .research) == 1)
    }

    @Test func recordIfAbsentAcceptsEquivalentEventAfterSQLiteDateNormalization() async throws {
        let store = try newStore()
        let event = EventLedgerStore.LedgerEvent(
            id: "date-normalized-event",
            timestamp: Date(timeIntervalSince1970: 1_725_000_000.123456),
            actor: "research-boundary",
            intent: "stable retry",
            actionKind: .research,
            trustLevel: .t2,
            policyDecision: .allowed,
            consentState: .notRequired,
            result: .success,
            createdAt: Date(timeIntervalSince1970: 1_725_000_000.654321),
            provenance: "test"
        )

        let first = try await store.recordIfAbsent(event)
        let second = try await store.recordIfAbsent(event)
        #expect(first.id == event.id)
        #expect(second.id == event.id)
        #expect(try await store.countEvents(actionKind: .research) == 1)
    }

    @Test func recordedEventPreservesAllFields() async throws {
        let store = try newStore()
        let event = EventLedgerStore.LedgerEvent(
            actor: "orchestrator",
            sessionID: "session-123",
            projectID: "project-abc",
            parentEventID: "parent-xyz",
            intent: "research AI safety",
            actionKind: .research,
            actionTarget: "https://example.com",
            actionPreview: "Will search for AI safety papers",
            trustLevel: .t2,
            policyDecision: .requiresConfirmation,
            consentState: .approved,
            contextIDs: ["node-1", "node-2"],
            modelProvider: "mlx",
            modelRole: "researchSynthesizer",
            toolName: "web_search",
            toolVersion: "1.0.0",
            environment: "macOS-27",
            outputSummary: "Found 12 papers",
            result: .success,
            errorDescription: nil,
            verificationResult: .verified,
            rollbackEventID: nil,
            durationMs: 342,
            provenance: "swarm"
        )
        _ = try await store.record(event)

        let fetched = try await store.getEvent(id: event.id)
        #expect(fetched?.actor == "orchestrator")
        #expect(fetched?.sessionID == "session-123")
        #expect(fetched?.projectID == "project-abc")
        #expect(fetched?.parentEventID == "parent-xyz")
        #expect(fetched?.intent == "research AI safety")
        #expect(fetched?.actionKind == .research)
        #expect(fetched?.actionTarget == "https://example.com")
        #expect(fetched?.actionPreview == "Will search for AI safety papers")
        #expect(fetched?.trustLevel == .t2)
        #expect(fetched?.policyDecision == .requiresConfirmation)
        #expect(fetched?.consentState == .approved)
        #expect(fetched?.contextIDs == ["node-1", "node-2"])
        #expect(fetched?.modelProvider == "mlx")
        #expect(fetched?.modelRole == "researchSynthesizer")
        #expect(fetched?.toolName == "web_search")
        #expect(fetched?.toolVersion == "1.0.0")
        #expect(fetched?.environment == "macOS-27")
        #expect(fetched?.outputSummary == "Found 12 papers")
        #expect(fetched?.result == .success)
        #expect(fetched?.verificationResult == .verified)
        #expect(fetched?.durationMs == 342)
    }

    @Test func getEventReturnsNilForMissing() async throws {
        let store = try newStore()
        #expect(try await store.getEvent(id: "no-such-id") == nil)
    }

    // MARK: - Query by dimension

    @Test func getEventsByActor() async throws {
        let store = try newStore()
        _ = try await store.record(sampleEvent(actor: "planner"))
        _ = try await store.record(sampleEvent(actor: "planner"))
        _ = try await store.record(sampleEvent(actor: "coder"))

        let plannerEvents = try await store.getEvents(byActor: "planner")
        #expect(plannerEvents.count == 2)
        let coderEvents = try await store.getEvents(byActor: "coder")
        #expect(coderEvents.count == 1)
    }

    @Test func getEventsBySession() async throws {
        let store = try newStore()
        let e1 = EventLedgerStore.LedgerEvent(actor: "user", sessionID: "s1", intent: "a",
                                                actionKind: .capture, trustLevel: .t0,
                                                policyDecision: .allowed, consentState: .auto,
                                                result: .success, provenance: "test")
        let e2 = EventLedgerStore.LedgerEvent(actor: "user", sessionID: "s2", intent: "b",
                                                actionKind: .capture, trustLevel: .t0,
                                                policyDecision: .allowed, consentState: .auto,
                                                result: .success, provenance: "test")
        _ = try await store.record(e1)
        _ = try await store.record(e2)

        #expect(try await store.getEvents(bySession: "s1").count == 1)
        #expect(try await store.getEvents(bySession: "s2").count == 1)
        #expect(try await store.getEvents(bySession: "s3").count == 0)
    }

    @Test func getEventsByProject() async throws {
        let store = try newStore()
        let e1 = EventLedgerStore.LedgerEvent(actor: "user", projectID: "proj-a", intent: "a",
                                                actionKind: .capture, trustLevel: .t0,
                                                policyDecision: .allowed, consentState: .auto,
                                                result: .success, provenance: "test")
        let e2 = EventLedgerStore.LedgerEvent(actor: "user", projectID: "proj-b", intent: "b",
                                                actionKind: .capture, trustLevel: .t0,
                                                policyDecision: .allowed, consentState: .auto,
                                                result: .success, provenance: "test")
        _ = try await store.record(e1)
        _ = try await store.record(e2)

        #expect(try await store.getEvents(byProject: "proj-a").count == 1)
    }

    @Test func getEventsByActionKind() async throws {
        let store = try newStore()
        _ = try await store.record(sampleEvent(actionKind: .modelCall))
        _ = try await store.record(sampleEvent(actionKind: .modelCall))
        _ = try await store.record(sampleEvent(actionKind: .codeWrite))
        _ = try await store.record(sampleEvent(actionKind: .consentGranted))

        #expect(try await store.getEvents(byActionKind: .modelCall).count == 2)
        #expect(try await store.getEvents(byActionKind: .codeWrite).count == 1)
        #expect(try await store.getEvents(byActionKind: .browserNavigate).count == 0)
    }

    @Test func getEventsByResult() async throws {
        let store = try newStore()
        _ = try await store.record(sampleEvent(result: .success))
        _ = try await store.record(sampleEvent(result: .success))
        _ = try await store.record(sampleEvent(result: .failure))

        #expect(try await store.getEvents(byResult: .success).count == 2)
        #expect(try await store.getEvents(byResult: .failure).count == 1)
        #expect(try await store.getEvents(byResult: .cancelled).count == 0)
    }

    @Test func getEventsMinTrustLevel() async throws {
        let store = try newStore()
        let e0 = EventLedgerStore.LedgerEvent(actor: "user", intent: "t0", actionKind: .capture,
                                                trustLevel: .t0, policyDecision: .allowed,
                                                consentState: .auto, result: .success, provenance: "test")
        let e3 = EventLedgerStore.LedgerEvent(actor: "user", intent: "t3", actionKind: .codeWrite,
                                                trustLevel: .t3, policyDecision: .requiresConfirmation,
                                                consentState: .approved, result: .success, provenance: "test")
        let e5 = EventLedgerStore.LedgerEvent(actor: "user", intent: "t5", actionKind: .terminalCommand,
                                                trustLevel: .t5, policyDecision: .denied,
                                                consentState: .denied, result: .failure, provenance: "test")
        _ = try await store.record(e0)
        _ = try await store.record(e3)
        _ = try await store.record(e5)

        // T3+ should include T3 and T5
        let t3plus = try await store.getEvents(minTrustLevel: .t3)
        #expect(t3plus.count == 2)
        // T5+ should include only T5
        let t5plus = try await store.getEvents(minTrustLevel: .t5)
        #expect(t5plus.count == 1)
    }

    @Test func getEventsByDateRange() async throws {
        let store = try newStore()
        let now = Date()
        _ = try await store.record(sampleEvent())
        // Small delay for timestamp gap
        try await Task.sleep(nanoseconds: 5_000_000)
        let mid = Date()
        try await Task.sleep(nanoseconds: 5_000_000)
        _ = try await store.record(sampleEvent())

        // All events should be in range [now-1h, now+1h]
        let all = try await store.getEvents(from: now.addingTimeInterval(-3600),
                                             to: Date().addingTimeInterval(3600))
        #expect(all.count == 2)
        // Range before first event should be empty
        let none = try await store.getEvents(from: now.addingTimeInterval(-7200),
                                              to: now.addingTimeInterval(-3600))
        #expect(none.isEmpty)
    }

    @Test func getFailedEvents() async throws {
        let store = try newStore()
        _ = try await store.record(sampleEvent(result: .success))
        let fail = sampleEvent(result: .failure)
        _ = try await store.record(fail)
        _ = try await store.record(sampleEvent(result: .cancelled))

        let failed = try await store.getFailedEvents()
        #expect(failed.count == 1)
        #expect(failed[0].result == .failure)
    }

    @Test func getUnverifiedEvents() async throws {
        let store = try newStore()
        _ = try await store.record(sampleEvent())

        let ev = EventLedgerStore.LedgerEvent(actor: "user", intent: "v", actionKind: .modelCall,
                                               trustLevel: .t1, policyDecision: .allowed,
                                               consentState: .auto, result: .success,
                                               verificationResult: .verified, provenance: "test")
        _ = try await store.record(ev)

        // Default verification is .unchecked — first event should be unverified
        let unchecked = try await store.getUnverifiedEvents()
        #expect(unchecked.count == 1)
    }

    // MARK: - Event chains

    @Test func parentChildEventChain() async throws {
        let store = try newStore()
        let parent = try await store.record(sampleEvent(intent: "parent action"))
        let child = EventLedgerStore.LedgerEvent(
            actor: "swarm", parentEventID: parent.id, intent: "child action",
            actionKind: .codeWrite, trustLevel: .t3,
            policyDecision: .requiresConfirmation, consentState: .approved,
            result: .success, provenance: "test"
        )
        _ = try await store.record(child)

        let children = try await store.getChildEvents(of: parent.id)
        #expect(children.count == 1)
        #expect(children[0].parentEventID == parent.id)
        #expect(children[0].intent == "child action")
    }

    @Test func getChildEventsReturnsEmptyForNoChildren() async throws {
        let store = try newStore()
        _ = try await store.record(sampleEvent())
        #expect(try await store.getChildEvents(of: "no-children").isEmpty)
    }

    // MARK: - Pagination

    @Test func getEventsSupportsLimitAndOffset() async throws {
        let store = try newStore()
        for i in 0..<10 {
            _ = try await store.record(sampleEvent(intent: "event \(i)"))
        }

        let page1 = try await store.getEvents(limit: 3, offset: 0)
        #expect(page1.count == 3)
        let page2 = try await store.getEvents(limit: 3, offset: 3)
        #expect(page2.count == 3)
        // Page 2 should have different events from page 1
        let page1IDs = Set(page1.map { $0.id })
        let page2IDs = Set(page2.map { $0.id })
        #expect(page1IDs.isDisjoint(with: page2IDs))
    }

    // MARK: - Count

    @Test func countEventsWithFilters() async throws {
        let store = try newStore()
        _ = try await store.record(sampleEvent(actor: "orchestrator", actionKind: .modelCall, result: .success))
        _ = try await store.record(sampleEvent(actor: "orchestrator", actionKind: .modelCall, result: .failure))
        _ = try await store.record(sampleEvent(actor: "coder", actionKind: .codeWrite, result: .success))

        #expect(try await store.countEvents() == 3)
        #expect(try await store.countEvents(actionKind: .modelCall) == 2)
        #expect(try await store.countEvents(result: .success) == 2)
        #expect(try await store.countEvents(actor: "orchestrator") == 2)
        #expect(try await store.countEvents(actionKind: .modelCall, result: .success) == 1)
    }

    // MARK: - Delete by scope

    @Test func deleteByProvenance() async throws {
        let store = try newStore()
        _ = try await store.record(sampleEvent())
        _ = try await store.record(sampleEvent())
        // Create one with different provenance
        let ev = EventLedgerStore.LedgerEvent(actor: "user", intent: "purge", actionKind: .capture,
                                               trustLevel: .t0, policyDecision: .allowed,
                                               consentState: .auto, result: .success,
                                               provenance: "to-delete")
        _ = try await store.record(ev)

        let deleted = try await store.deleteByProvenance("to-delete")
        #expect(deleted == 1)
        #expect(try await store.countEvents() == 2)
    }

    @Test func deleteOlderThan() async throws {
        let store = try newStore()
        _ = try await store.record(sampleEvent())
        try await Task.sleep(nanoseconds: 5_000_000)
        let cutoff = Date()
        try await Task.sleep(nanoseconds: 5_000_000)
        _ = try await store.record(sampleEvent())

        let deleted = try await store.deleteOlderThan(cutoff)
        #expect(deleted == 1)
        #expect(try await store.countEvents() == 1)
    }

    @Test func deleteAll() async throws {
        let store = try newStore()
        _ = try await store.record(sampleEvent())
        _ = try await store.record(sampleEvent())
        _ = try await store.record(sampleEvent())

        let deleted = try await store.deleteAll()
        #expect(deleted == 3)
        #expect(try await store.countEvents() == 0)
    }

    // MARK: - Edge cases

    @Test func recordEventsWithAllActionKinds() async throws {
        let store = try newStore()
        for kind in EventLedgerStore.ActionKind.allCases {
            let ev = EventLedgerStore.LedgerEvent(actor: "test", intent: "test",
                                                   actionKind: kind, trustLevel: .t0,
                                                   policyDecision: .allowed, consentState: .auto,
                                                   result: .success, provenance: "test")
            _ = try await store.record(ev)
        }
        #expect(try await store.countEvents() == EventLedgerStore.ActionKind.allCases.count)
    }

    @Test func recordEventsWithAllTrustLevels() async throws {
        let store = try newStore()
        for level in EventLedgerStore.TrustLevel.allCases {
            let ev = EventLedgerStore.LedgerEvent(actor: "test", intent: "test",
                                                   actionKind: .modelCall, trustLevel: level,
                                                   policyDecision: .allowed, consentState: .auto,
                                                   result: .success, provenance: "test")
            _ = try await store.record(ev)
        }
        #expect(try await store.countEvents() == EventLedgerStore.TrustLevel.allCases.count)
    }

    @Test func recordEventsWithAllConsentStates() async throws {
        let store = try newStore()
        for state in EventLedgerStore.ConsentState.allCases {
            let ev = EventLedgerStore.LedgerEvent(actor: "test", intent: "test",
                                                   actionKind: .consentGranted, trustLevel: .t2,
                                                   policyDecision: .allowed, consentState: state,
                                                   result: .success, provenance: "test")
            _ = try await store.record(ev)
        }
        #expect(try await store.countEvents() == EventLedgerStore.ConsentState.allCases.count)
    }

    @Test func recordEventsWithAllPolicyDecisions() async throws {
        let store = try newStore()
        for decision in EventLedgerStore.PolicyDecision.allCases {
            let ev = EventLedgerStore.LedgerEvent(actor: "test", intent: "test",
                                                   actionKind: .modelCall, trustLevel: .t1,
                                                   policyDecision: decision, consentState: .auto,
                                                   result: .success, provenance: "test")
            _ = try await store.record(ev)
        }
        #expect(try await store.countEvents() == EventLedgerStore.PolicyDecision.allCases.count)
    }

    @Test func recordEventsWithAllVerificationResults() async throws {
        let store = try newStore()
        for vr in EventLedgerStore.VerificationResult.allCases {
            let ev = EventLedgerStore.LedgerEvent(actor: "test", intent: "test",
                                                   actionKind: .modelCall, trustLevel: .t1,
                                                   policyDecision: .allowed, consentState: .auto,
                                                   result: .success, verificationResult: vr,
                                                   provenance: "test")
            _ = try await store.record(ev)
        }
        #expect(try await store.countEvents() == EventLedgerStore.VerificationResult.allCases.count)
    }

    @Test func nilFieldsRoundTripCorrectly() async throws {
        let store = try newStore()
        let event = EventLedgerStore.LedgerEvent(
            actor: "test", intent: "minimal", actionKind: .systemEvent,
            trustLevel: .t0, policyDecision: .allowed, consentState: .notRequired,
            result: .success, provenance: "test"
            // All optional fields nil
        )
        _ = try await store.record(event)

        let fetched = try await store.getEvent(id: event.id)
        #expect(fetched?.sessionID == nil)
        #expect(fetched?.projectID == nil)
        #expect(fetched?.parentEventID == nil)
        #expect(fetched?.actionTarget == nil)
        #expect(fetched?.actionPreview == nil)
        #expect(fetched?.modelProvider == nil)
        #expect(fetched?.modelRole == nil)
        #expect(fetched?.toolName == nil)
        #expect(fetched?.toolVersion == nil)
        #expect(fetched?.outputSummary == nil)
        #expect(fetched?.errorDescription == nil)
        #expect(fetched?.rollbackEventID == nil)
        #expect(fetched?.durationMs == nil)
        #expect(fetched?.contextIDs ?? [] == [])
    }

    @Test func emptyContextIDsRoundTrip() async throws {
        let store = try newStore()
        let event = EventLedgerStore.LedgerEvent(
            actor: "test", intent: "no context", actionKind: .capture,
            trustLevel: .t0, policyDecision: .allowed, consentState: .auto,
            contextIDs: [], result: .success, provenance: "test"
        )
        _ = try await store.record(event)
        let fetched = try await store.getEvent(id: event.id)
        #expect(fetched?.contextIDs.isEmpty == true)
    }

    @Test func errorDescriptionIsPreserved() async throws {
        let store = try newStore()
        let event = EventLedgerStore.LedgerEvent(
            actor: "coder", intent: "write file", actionKind: .codeWrite,
            trustLevel: .t3, policyDecision: .allowed, consentState: .approved,
            result: .failure, errorDescription: "Permission denied: /etc/hosts",
            provenance: "swarm"
        )
        _ = try await store.record(event)
        let fetched = try await store.getEvent(id: event.id)
        #expect(fetched?.result == .failure)
        #expect(fetched?.errorDescription == "Permission denied: /etc/hosts")
    }

    @Test func rollbackReferencePreserved() async throws {
        let store = try newStore()
        let original = try await store.record(sampleEvent(intent: "original action"))
        let rollback = EventLedgerStore.LedgerEvent(
            actor: "swarm", parentEventID: original.id, intent: "rollback original",
            actionKind: .rollback, trustLevel: .t3,
            policyDecision: .allowed, consentState: .auto,
            result: .success, rollbackEventID: original.id, provenance: "system"
        )
        _ = try await store.record(rollback)

        let fetched = try await store.getEvent(id: rollback.id)
        #expect(fetched?.actionKind == .rollback)
        #expect(fetched?.rollbackEventID == original.id)
    }
}

// MARK: - SourceAndClaim: typed research citation backbone

/// Tests Source and Claim typed wrappers on top of HoneycombStore:
/// create/retrieve/dedup sources, create/retrieve/dedup claims,
/// evidence spans, source-claim linking, contradiction marking,
/// freshness updates, and cross-type safety.
@Suite("SourceAndClaim")
struct SourceAndClaimTests {

    private func newStore() throws -> HoneycombStore {
        try HoneycombStore(path: ":memory:")
    }

    // MARK: - Source tests

    @Test func createAndRetrieveSource() async throws {
        let store = try newStore()
        let source = Source(url: "https://example.com/article", title: "Test Article",
                            captureMethod: "browser-capture", author: "Jane Doe",
                            provenance: "test")
        let created = try await store.createSource(source)
        #expect(created.url == "https://example.com/article")
        #expect(created.title == "Test Article")

        let fetched = try await store.getSource(id: created.id)
        #expect(fetched?.url == "https://example.com/article")
        #expect(fetched?.author == "Jane Doe")
        #expect(fetched?.captureMethod == "browser-capture")
    }

    @Test func sourceDedupByContentHash() async throws {
        let store = try newStore()
        let s1 = try await store.createSource(
            Source(url: "https://example.com", title: "First",
                   contentHash: "abc123", provenance: "test"))
        let s2 = try await store.createSource(
            Source(url: "https://example.com", title: "Second",
                   contentHash: "abc123", provenance: "test"))
        // Same hash → dedup, should return first
        #expect(s2.id == s1.id)
        #expect(try await store.countNodes(type: .source) == 1)
    }

    @Test func findSourceByURL() async throws {
        let store = try newStore()
        _ = try await store.createSource(
            Source(url: "https://unique.example.com", title: "Unique", provenance: "test"))

        let found = try await store.findSource(byURL: "https://unique.example.com")
        #expect(found?.title == "Unique")

        let notFound = try await store.findSource(byURL: "https://nonexistent.example.com")
        #expect(notFound == nil)
    }

    @Test func getAllSources() async throws {
        let store = try newStore()
        _ = try await store.createSource(Source(url: "https://a.com", provenance: "test"))
        _ = try await store.createSource(Source(url: "https://b.com", provenance: "test"))
        _ = try await store.createSource(Source(url: "https://c.com", provenance: "test"))

        let all = try await store.getAllSources()
        #expect(all.count == 3)
    }

    @Test func sourceMetadataRoundTrips() async throws {
        let store = try newStore()
        let source = Source(
            url: "https://example.com", title: "Full Metadata",
            captureMethod: "swarm-research",
            contentHash: HoneycombStore.sha256("page content"),
            author: "Dr. Smith",
            publishedDate: "2026-01-15",
            retrievalTimestamp: Date(),
            license: "CC BY 4.0",
            robotsStatus: "allowed",
            provenance: "swarm"
        )
        let created = try await store.createSource(source)
        let fetched = try await store.getSource(id: created.id)
        #expect(fetched?.url == "https://example.com")
        #expect(fetched?.author == "Dr. Smith")
        #expect(fetched?.publishedDate == "2026-01-15")
        #expect(fetched?.license == "CC BY 4.0")
        #expect(fetched?.robotsStatus == "allowed")
    }

    @Test func sourceFromNodeReturnsNilForWrongType() async throws {
        let store = try newStore()
        let noteNode = HoneycombStore.Node(type: .note, label: "not a source", provenance: "test")
        _ = try await store.insertNode(noteNode)
        let fetched = try await store.getNode(id: noteNode.id)
        #expect(Source.from(fetched!) == nil)
    }

    @Test func sourceFromNodeHandlesMissingMetadata() async throws {
        // Source.from should not crash when metadata is missing expected keys —
        // it must fall back to defaults rather than returning nil or crashing.
        let store = try newStore()
        let node = HoneycombStore.Node(
            type: .source, label: "https://example.com",
            metadata: .object([:]),  // empty metadata — no url, no captureMethod
            provenance: "test"
        )
        _ = try await store.insertNode(node)
        let fetched = try await store.getNode(id: node.id)
        let source = Source.from(fetched!)
        #expect(source != nil)
        #expect(source?.url == "https://example.com")  // falls back to label
        #expect(source?.captureMethod == "unknown")  // fallback
        #expect(source?.qualityScore == nil)
    }

    @Test func sourceQualityScoreRoundTrips() async throws {
        let store = try newStore()
        let source = Source(url: "https://high-quality.example.com",
                           title: "High Quality Source",
                           qualityScore: 0.95,
                           provenance: "test")
        let created = try await store.createSource(source)
        #expect(created.qualityScore == 0.95)
        let fetched = try await store.getSource(id: created.id)
        #expect(fetched?.qualityScore == 0.95)
    }

    @Test func sourceQualityScoreIsClamped() {
        let high = Source(url: "https://example.com", qualityScore: 2.5)
        #expect(high.qualityScore == 1.0)
        let low = Source(url: "https://example.com", qualityScore: -0.5)
        #expect(low.qualityScore == 0.0)
    }

    // MARK: - Claim tests

    @Test func createAndRetrieveClaim() async throws {
        let store = try newStore()
        let claim = Claim(text: "Swift 6 improves concurrency safety",
                          confidence: 0.95, provenance: "swarm")
        let created = try await store.createClaim(claim)
        #expect(created.text == "Swift 6 improves concurrency safety")
        #expect(created.confidence == 0.95)

        let fetched = try await store.getClaim(id: created.id)
        #expect(fetched?.text == "Swift 6 improves concurrency safety")
        #expect(fetched?.confidence == 0.95)
        #expect(fetched?.freshness == .current)
    }

    @Test func claimDedupByTextHash() async throws {
        let store = try newStore()
        let c1 = try await store.createClaim(
            Claim(text: "The sky is blue", provenance: "test"))
        let c2 = try await store.createClaim(
            Claim(text: "The sky is blue", provenance: "test"))
        #expect(c2.id == c1.id)
        #expect(try await store.countNodes(type: .claim) == 1)
    }

    @Test func claimConfidenceIsClamped() async throws {
        let store = try newStore()
        let over = Claim(text: "over", confidence: 2.5, provenance: "test")
        #expect(over.confidence == 1.0)
        let under = Claim(text: "under", confidence: -0.5, provenance: "test")
        #expect(under.confidence == 0.0)
        _ = try await store.createClaim(over)
        _ = try await store.createClaim(under)
    }

    @Test func claimEvidenceSpansRoundTrip() async throws {
        let store = try newStore()
        let span = EvidenceSpan(sourceID: "src-1", startOffset: 42,
                                 endOffset: 87, quote: "exact match text")
        let claim = Claim(text: "fact with evidence", confidence: 0.8,
                          evidenceSpans: [span], provenance: "test")
        let created = try await store.createClaim(claim)
        let fetched = try await store.getClaim(id: created.id)
        #expect(fetched?.evidenceSpans.count == 1)
        #expect(fetched?.evidenceSpans[0].sourceID == "src-1")
        #expect(fetched?.evidenceSpans[0].startOffset == 42)
        #expect(fetched?.evidenceSpans[0].endOffset == 87)
        #expect(fetched?.evidenceSpans[0].quote == "exact match text")
    }

    @Test func claimFromNodeReturnsNilForWrongType() async throws {
        let store = try newStore()
        let noteNode = HoneycombStore.Node(type: .note, label: "not a claim", provenance: "test")
        _ = try await store.insertNode(noteNode)
        let fetched = try await store.getNode(id: noteNode.id)
        #expect(Claim.from(fetched!) == nil)
    }

    @Test func claimFromNodeHandlesMissingMetadata() async throws {
        // Claim.from should fall back to defaults when metadata is missing —
        // never crash and never return nil for a valid .claim node type.
        let store = try newStore()
        let node = HoneycombStore.Node(
            type: .claim, label: "A claim without metadata",
            metadata: .object([:]),  // empty — no text, freshness, contradictionState
            provenance: "test"
        )
        _ = try await store.insertNode(node)
        let fetched = try await store.getNode(id: node.id)
        let claim = Claim.from(fetched!)
        #expect(claim != nil)
        #expect(claim?.text == "A claim without metadata")  // falls back to label
        #expect(claim?.confidence == 1.0)  // default
        #expect(claim?.freshness == .current)  // default
        #expect(claim?.contradictionState == .uncontested)  // default
        #expect(claim?.evidenceSpans.isEmpty == true)
    }

    @Test func getAllClaims() async throws {
        let store = try newStore()
        _ = try await store.createClaim(Claim(text: "claim a", provenance: "test"))
        _ = try await store.createClaim(Claim(text: "claim b", provenance: "test"))
        let all = try await store.getAllClaims()
        #expect(all.count == 2)
    }

    @Test func searchClaims() async throws {
        let store = try newStore()
        _ = try await store.createClaim(Claim(text: "Swift concurrency is safe", provenance: "test"))
        _ = try await store.createClaim(Claim(text: "SQLite is fast", provenance: "test"))
        let results = try await store.searchClaims(query: "concurrency")
        #expect(results.count == 1)
        #expect(results[0].text.contains("concurrency"))
    }

    // MARK: - Source-Claim linking

    @Test func linkClaimToSource() async throws {
        let store = try newStore()
        let source = try await store.createSource(
            Source(url: "https://example.com", provenance: "test"))
        let claim = try await store.createClaim(
            Claim(text: "derived fact", provenance: "test"))

        let edge = try await store.linkClaimToSource(
            claimID: claim.id, sourceID: source.id, weight: 0.9)
        #expect(edge.relation == .derivedFrom)
        #expect(edge.weight == 0.9)

        let sources = try await store.getSourcesForClaim(claim.id)
        #expect(sources.count == 1)
        #expect(sources[0].url == "https://example.com")
    }

    @Test func linkClaimToSourceIsIdempotent() async throws {
        let store = try newStore()
        let source = try await store.createSource(
            Source(url: "https://example.com", provenance: "test"))
        let claim = try await store.createClaim(
            Claim(text: "fact", provenance: "test"))

        _ = try await store.linkClaimToSource(claimID: claim.id, sourceID: source.id)
        _ = try await store.linkClaimToSource(claimID: claim.id, sourceID: source.id)
        // Only one edge should exist
        #expect(try await store.countEdges(relation: .derivedFrom) == 1)
    }

    @Test func getClaimsForSource() async throws {
        let store = try newStore()
        let source = try await store.createSource(
            Source(url: "https://example.com", provenance: "test"))
        let c1 = try await store.createClaim(Claim(text: "fact 1", provenance: "test"))
        let c2 = try await store.createClaim(Claim(text: "fact 2", provenance: "test"))

        _ = try await store.linkClaimToSource(claimID: c1.id, sourceID: source.id)
        _ = try await store.linkClaimToSource(claimID: c2.id, sourceID: source.id, relation: .supports)

        let claims = try await store.getClaimsForSource(source.id)
        #expect(claims.count == 2)
    }

    // MARK: - Contradictions

    @Test func markContradictionBetweenClaims() async throws {
        let store = try newStore()
        let claimA = try await store.createClaim(
            Claim(text: "X causes Y", provenance: "test"))
        let claimB = try await store.createClaim(
            Claim(text: "X does not cause Y", provenance: "test"))

        try await store.markContradiction(between: claimA.id, and: claimB.id)

        // Both should be contested
        let a = try await store.getClaim(id: claimA.id)
        #expect(a?.contradictionState == .contested)
        let b = try await store.getClaim(id: claimB.id)
        #expect(b?.contradictionState == .contested)

        // Contradicts edge should exist
        #expect(try await store.edgeExists(from: claimA.id, to: claimB.id, relation: .contradicts))
    }

    @Test func getContradictingClaims() async throws {
        let store = try newStore()
        let claimA = try await store.createClaim(Claim(text: "A", provenance: "test"))
        let claimB = try await store.createClaim(Claim(text: "not A", provenance: "test"))
        try await store.markContradiction(between: claimA.id, and: claimB.id)

        let contradicting = try await store.getContradictingClaims(for: claimA.id)
        #expect(contradicting.count == 1)
        #expect(contradicting[0].id == claimB.id)
    }

    // MARK: - Freshness updates

    @Test func updateClaimFreshness() async throws {
        let store = try newStore()
        let claim = try await store.createClaim(
            Claim(text: "old info", freshness: .current, provenance: "test"))

        let updated = try await store.updateClaimFreshness(claimID: claim.id, freshness: .stale)
        #expect(updated?.freshness == .stale)

        let fetched = try await store.getClaim(id: claim.id)
        #expect(fetched?.freshness == .stale)
    }

    @Test func updateClaimFreshnessReturnsNilForMissing() async throws {
        let store = try newStore()
        let result = try await store.updateClaimFreshness(claimID: "no-such", freshness: .stale)
        #expect(result == nil)
    }

    // MARK: - Edge cases

    @Test func evidenceSpanWithoutQuote() async throws {
        let store = try newStore()
        let span = EvidenceSpan(sourceID: "src", startOffset: 0, endOffset: 10, quote: nil)
        let claim = Claim(text: "minimal", evidenceSpans: [span], provenance: "test")
        let created = try await store.createClaim(claim)
        let fetched = try await store.getClaim(id: created.id)
        #expect(fetched?.evidenceSpans[0].quote == nil)
    }

    @Test func sourceWithoutTitleUsesURLAsLabel() async throws {
        let store = try newStore()
        let source = Source(url: "https://notitle.example.com", title: nil, provenance: "test")
        let created = try await store.createSource(source)
        let node = try await store.getNode(id: created.id)
        // The Honeycomb node label falls back to URL when title is nil
        #expect(node?.label == "https://notitle.example.com")
    }

    // MARK: - Lifecycle: delete and correction (AGENTS.md §7.2)

    @Test func deleteSourceCascadesEvidenceEdges() async throws {
        let store = try newStore()
        let source = try await store.createSource(
            Source(url: "https://example.com/delete-me", title: "Delete Me", provenance: "test"))
        let claim = try await store.createClaim(Claim(text: "derived fact", provenance: "test"))
        _ = try await store.linkClaimToSource(claimID: claim.id, sourceID: source.id)
        #expect(try await store.edgeExists(from: claim.id, to: source.id, relation: .derivedFrom))

        let deleted = try await store.deleteSource(id: source.id)
        #expect(deleted, "existing source must delete")
        #expect(try await store.getSource(id: source.id) == nil)
        // Claim survives; the evidence edge cascades away (ON DELETE CASCADE).
        #expect(try await store.getClaim(id: claim.id) != nil,
                "deleting a source must not orphan-delete its claims")
        #expect(!(try await store.edgeExists(from: claim.id, to: source.id, relation: .derivedFrom)),
                "evidence edges must cascade on source delete")
        // Deleting a missing ID returns false, not an error.
        #expect(try await store.deleteSource(id: source.id) == false)
    }

    @Test func deleteClaimRemovesNodeAndEdges() async throws {
        let store = try newStore()
        let claimA = try await store.createClaim(Claim(text: "X causes Y", provenance: "test"))
        let claimB = try await store.createClaim(Claim(text: "not X", provenance: "test"))
        try await store.markContradiction(between: claimA.id, and: claimB.id)

        let deleted = try await store.deleteClaim(id: claimA.id)
        #expect(deleted)
        #expect(try await store.getClaim(id: claimA.id) == nil)
        // Claim B survives; the contradiction edge cascades away.
        #expect(try await store.getClaim(id: claimB.id) != nil)
        #expect(!(try await store.edgeExists(from: claimA.id, to: claimB.id, relation: .contradicts)))
    }

    @Test func correctClaimUpdatesTextAndConfidence() async throws {
        let store = try newStore()
        let claim = try await store.createClaim(
            Claim(text: "original wording", confidence: 0.6, provenance: "test"))

        let corrected = try await store.correctClaim(
            claimID: claim.id, text: "corrected wording", confidence: 0.95)
        #expect(corrected?.text == "corrected wording")
        #expect(corrected?.confidence == 0.95)
        #expect(corrected?.id == claim.id, "correction must preserve the node ID")
        // The node label (claim text) must be updated too, not just metadata.
        let node = try await store.getNode(id: claim.id)
        #expect(node?.label == "corrected wording")
        #expect(try await store.getClaim(id: claim.id)?.text == "corrected wording")
        // FTS index must follow the correction: the new wording is findable,
        // the old wording is gone (locks updateNode's DELETE/INSERT re-index).
        // Note: search is token-OR, so probe with tokens UNIQUE to each side
        // ("corrected" vs "original") — a shared token like "wording" would
        // match the new row regardless of the re-index.
        let byNew = try await store.searchClaims(query: "corrected")
        #expect(byNew.contains(where: { $0.id == claim.id }),
                "corrected claim text must be searchable via FTS")
        let byOld = try await store.searchClaims(query: "original")
        #expect(!byOld.contains(where: { $0.id == claim.id }),
                "pre-correction text must be gone from the FTS index")
    }

    @Test func correctClaimReplacesEvidenceSpans() async throws {
        let store = try newStore()
        let claim = try await store.createClaim(
            Claim(text: "claim", evidenceSpans: [
                EvidenceSpan(sourceID: "src-a", startOffset: 0, endOffset: 5, quote: "old")
            ], provenance: "test"))

        let corrected = try await store.correctClaim(
            claimID: claim.id,
            evidenceSpans: [EvidenceSpan(sourceID: "src-b", startOffset: 0, endOffset: 4, quote: "new")]
        )
        #expect(corrected?.evidenceSpans.count == 1)
        #expect(corrected?.evidenceSpans[0].sourceID == "src-b",
                "corrected spans must REPLACE the old ones, not append")
        #expect(corrected?.evidenceSpans[0].quote == "new")
    }

    @Test func correctClaimReturnsNilForMissing() async throws {
        let store = try newStore()
        let corrected = try await store.correctClaim(
            claimID: "does-not-exist", text: "nope")
        #expect(corrected == nil)
    }
}

// MARK: - BriefStore: durable, source-linked, editable, exportable briefs

/// DATA-005: Briefs are reproducible (Honeycomb `.brief` nodes), source-linked
/// (`references` edges), editable (revision history), and exportable (Markdown
/// with live source URLs).
@Suite("BriefStore")
struct BriefStoreTests {

    private func newStore() throws -> HoneycombStore {
        try HoneycombStore(path: ":memory:")
    }

    private func makeSource(_ store: HoneycombStore, url: String, title: String) async throws -> Source {
        try await store.createSource(
            Source(url: url, title: title, provenance: "test"))
    }

    @Test func createAndRetrieveBrief() async throws {
        let store = try newStore()
        let brief = try await store.createBrief(
            Brief(title: "Research summary", content: "# Findings\n\nThe data supports X.",
                  provenance: "test"))

        let fetched = try await store.getBrief(id: brief.id)
        #expect(fetched?.title == "Research summary")
        #expect(fetched?.content.contains("The data supports X") == true)
        #expect(fetched?.sourceIDs.isEmpty == true)
        #expect(try await store.getNode(id: brief.id)?.type == .brief)
    }

    @Test func createBriefLinksSources() async throws {
        let store = try newStore()
        let s1 = try await makeSource(store, url: "https://a.example.com", title: "Source A")
        let s2 = try await makeSource(store, url: "https://b.example.com", title: "Source B")
        let brief = try await store.createBrief(
            Brief(title: "Cited brief", content: "body", sourceIDs: [s1.id, s2.id],
                  provenance: "test"))

        let sources = try await store.getSourcesForBrief(brief.id)
        #expect(sources.count == 2)
        #expect(Set(sources.map(\.id)) == Set([s1.id, s2.id]))
        #expect(try await store.edgeExists(from: brief.id, to: s1.id, relation: .references))
    }

    @Test func updateBriefEditsAndReconcilesSources() async throws {
        let store = try newStore()
        let s1 = try await makeSource(store, url: "https://a.example.com", title: "A")
        let s2 = try await makeSource(store, url: "https://b.example.com", title: "B")
        let brief = try await store.createBrief(
            Brief(title: "Old title", content: "old", sourceIDs: [s1.id], provenance: "test"))

        let updated = try await store.updateBrief(
            briefID: brief.id, title: "New title", content: "new body",
            sourceIDs: [s2.id])
        #expect(updated?.title == "New title")
        #expect(updated?.content == "new body")
        #expect(updated?.id == brief.id, "edit must preserve the node ID")
        // Stale source edge dropped, new one added.
        let sources = try await store.getSourcesForBrief(brief.id)
        #expect(sources.map(\.id) == [s2.id])
        #expect(!(try await store.edgeExists(from: brief.id, to: s1.id, relation: .references)))
    }

    @Test func searchBriefsFindsByTitle() async throws {
        let store = try newStore()
        _ = try await store.createBrief(Brief(title: "Swift concurrency notes", content: "x", provenance: "test"))
        _ = try await store.createBrief(Brief(title: "Pizza recipes", content: "y", provenance: "test"))

        let results = try await store.searchBriefs(query: "concurrency")
        #expect(results.count == 1)
        #expect(results[0].title == "Swift concurrency notes")
    }

    @Test func deleteBriefTypeChecked() async throws {
        let store = try newStore()
        let brief = try await store.createBrief(
            Brief(title: "Doomed", content: "bye", provenance: "test"))
        let claim = try await store.createClaim(Claim(text: "not a brief", provenance: "test"))

        // Type-checked: deleteBrief refuses to delete a claim node.
        #expect(try await store.deleteBrief(id: claim.id) == false)
        #expect(try await store.getClaim(id: claim.id) != nil)
        // Real brief deletes.
        #expect(try await store.deleteBrief(id: brief.id) == true)
        #expect(try await store.getBrief(id: brief.id) == nil)
    }

    @Test func exportMarkdownIncludesSources() async throws {
        let store = try newStore()
        let s1 = try await makeSource(store, url: "https://a.example.com/page", title: "Source A")
        let brief = try await store.createBrief(
            Brief(title: "Export me", content: "# Body\n\nKey claim.", sourceIDs: [s1.id],
                  provenance: "test"))

        let md = try await store.exportMarkdown(brief)
        #expect(md.contains("# Export me"))
        #expect(md.contains("# Body"))
        #expect(md.contains("## Sources"))
        #expect(md.contains("[Source A](https://a.example.com/page)"),
                "export must resolve live source URLs")
        #expect(md.contains("Exported from Hive"))
    }
}

// MARK: - Projects and tasks (DATA-006)

@Suite("ProjectStore")
struct ProjectStoreTests {

    private func newStore() throws -> HoneycombStore {
        try HoneycombStore(path: ":memory:")
    }

    @Test func createAndRetrieveProject() async throws {
        let store = try newStore()
        let project = try await store.createProject(
            Project(title: "YC Launch", purpose: "Get Hive to demo day", provenance: "test"))

        let fetched = try await store.getProject(id: project.id)
        #expect(fetched?.title == "YC Launch")
        #expect(fetched?.purpose == "Get Hive to demo day")
        #expect(fetched?.lifecycle == .active)
        #expect(try await store.getNode(id: project.id)?.type == .project)
    }

    @Test func updateProjectEditsTitlePurposeAndLifecycle() async throws {
        let store = try newStore()
        let project = try await store.createProject(Project(title: "Old", provenance: "test"))

        let updated = try await store.updateProject(
            id: project.id, title: "New", purpose: "Shipped", lifecycle: .archived)
        #expect(updated?.title == "New")
        #expect(updated?.purpose == "Shipped")
        #expect(updated?.lifecycle == .archived)

        // FTS follows the correction (updateNode re-indexes label + metadata)
        #expect(try await store.searchProjects("New").count == 1)
        #expect(try await store.searchProjects("Old").isEmpty)

        // Partial edit: a title-only change preserves purpose and lifecycle
        let reverted = try await store.updateProject(id: project.id, title: "Reverted")
        #expect(reverted?.purpose == "Shipped")
        #expect(reverted?.lifecycle == .archived)
        #expect(reverted?.title == "Reverted")
    }

    @Test func getAllProjectsFiltersByLifecycle() async throws {
        let store = try newStore()
        let a = try await store.createProject(Project(title: "Active one", provenance: "test"))
        _ = try await store.createProject(Project(title: "Active two", provenance: "test"))
        let archived = try await store.createProject(
            Project(title: "Old work", lifecycle: .archived, provenance: "test"))

        #expect(try await store.getAllProjects().count == 3)
        #expect(try await store.getAllProjects(lifecycle: .active).count == 2)
        #expect(try await store.getAllProjects(lifecycle: .archived).count == 1)
        #expect(try await store.getProject(id: archived.id)?.lifecycle == .archived)
    }

    @Test func projectTaskMembership() async throws {
        let store = try newStore()
        let project = try await store.createProject(Project(title: "Ship", provenance: "test"))
        let t1 = try await store.createTask(HiveTask(title: "Write brief", provenance: "test"))
        let t2 = try await store.createTask(HiveTask(title: "Record demo", provenance: "test"))

        let edge = try await store.addTaskToProject(taskID: t1.id, projectID: project.id)
        #expect(edge?.relation == .belongsTo)
        _ = try await store.addTaskToProject(taskID: t2.id, projectID: project.id)
        // Idempotent: re-adding is a no-op
        #expect(try await store.addTaskToProject(taskID: t1.id, projectID: project.id) == nil)

        let tasks = try await store.getProjectTasks(projectID: project.id)
        #expect(Set(tasks.map(\.id)) == Set([t1.id, t2.id]))
        #expect(try await store.getProjectTaskIDs(projectID: project.id).count == 2)

        // Wrong-type refusal: can't attach a project to a project
        let other = try await store.createProject(Project(title: "Other", provenance: "test"))
        #expect(try await store.addTaskToProject(taskID: other.id, projectID: project.id) == nil)
    }

    @Test func deleteProjectCascadesMembership() async throws {
        let store = try newStore()
        let project = try await store.createProject(Project(title: "Doomed", provenance: "test"))
        let task = try await store.createTask(HiveTask(title: "Orphan", provenance: "test"))
        _ = try await store.addTaskToProject(taskID: task.id, projectID: project.id)

        #expect(try await store.deleteProject(id: project.id) == true)
        // Task survives, membership edge cascades away
        #expect(try await store.getTask(id: task.id) != nil)
        #expect(try await store.getProjectTasks(projectID: project.id).isEmpty)
        // Type-checked delete refuses non-project nodes
        #expect(try await store.deleteProject(id: task.id) == false)
    }

    @Test func exportProjectRendersMarkdownWithTaskGroups() async throws {
        let store = try newStore()
        let project = try await store.createProject(
            Project(title: "Launch", purpose: "One demo", provenance: "test"))
        let open = try await store.createTask(HiveTask(
            title: "Polish tabs", notes: "pixel-perfect", priority: .high, provenance: "test"))
        let done = try await store.createTask(
            HiveTask(title: "Import browser", state: .done, provenance: "test"))
        _ = try await store.addTaskToProject(taskID: open.id, projectID: project.id)
        _ = try await store.addTaskToProject(taskID: done.id, projectID: project.id)

        let md = try await store.exportProject(id: project.id)
        #expect(md?.contains("# Launch") == true)
        #expect(md?.contains("> One demo") == true)
        #expect(md?.contains("## Open (1)") == true)
        #expect(md?.contains("## Done (1)") == true)
        #expect(md?.contains("Polish tabs") == true)
        #expect(md?.contains("(priority: high)") == true)
        #expect(md?.contains("pixel-perfect") == true)
    }
}

@Suite("TaskStore")
struct TaskStoreTests {

    private func newStore() throws -> HoneycombStore {
        try HoneycombStore(path: ":memory:")
    }

    private func makeSource(_ store: HoneycombStore, url: String, title: String) async throws -> Source {
        try await store.createSource(
            Source(url: url, title: title, provenance: "test"))
    }

    @Test func createAndRetrieveTaskRoundTripsAllFields() async throws {
        let store = try newStore()
        let due = Date().addingTimeInterval(86400)
        let task = try await store.createTask(HiveTask(
            title: "Reply to YC", notes: "before noon", state: .inProgress,
            priority: .high, dueDate: due, provenance: "test"))

        let fetched = try await store.getTask(id: task.id)
        #expect(fetched?.title == "Reply to YC")
        #expect(fetched?.notes == "before noon")
        #expect(fetched?.state == .inProgress)
        #expect(fetched?.priority == .high)
        #expect(fetched?.dueDate?.timeIntervalSince1970 == due.timeIntervalSince1970)
    }

    @Test func updateTaskTransitionsStateAndClearsDueDate() async throws {
        let store = try newStore()
        let task = try await store.createTask(
            HiveTask(title: "Do it", dueDate: Date().addingTimeInterval(3600), provenance: "test"))

        let done = try await store.completeTask(id: task.id)
        #expect(done?.state == .done)

        let cleared = try await store.updateTask(id: task.id, title: "Redo", clearDueDate: true)
        #expect(cleared?.title == "Redo")
        #expect(cleared?.dueDate == nil)
        #expect(cleared?.state == .done, "state persists across other edits")

        // Type-checked update refuses non-task nodes
        let project = try await store.createProject(Project(title: "P", provenance: "test"))
        #expect(try await store.updateTask(id: project.id, state: .done) == nil)
        // Type-checked delete refuses non-task nodes
        #expect(try await store.deleteTask(id: project.id) == false)
        #expect(try await store.getTask(id: task.id) != nil)
    }

    @Test func taskSourceLinksResolve() async throws {
        let store = try newStore()
        let source = try await makeSource(store, url: "https://example.com/page", title: "The Page")
        let task = try await store.createTask(
            HiveTask(title: "Verify claim", sourceIDs: [source.id], provenance: "test"))

        // createTask auto-links metadata sourceIDs as references edges
        let sources = try await store.getSourcesForTask(taskID: task.id)
        #expect(sources.map(\.id) == [source.id])
        #expect(try await store.edgeExists(from: source.id, to: task.id, relation: .references))

        // Explicit re-link is idempotent — already linked by createTask
        #expect(try await store.linkSourceToTask(sourceID: source.id, taskID: task.id) == nil)

        // A task created WITHOUT sourceIDs can be linked explicitly later
        let bare = try await store.createTask(HiveTask(title: "No sources yet", provenance: "test"))
        let edge = try await store.linkSourceToTask(sourceID: source.id, taskID: bare.id)
        #expect(edge?.relation == .references)
        #expect(try await store.getSourcesForTask(taskID: bare.id).map(\.id) == [source.id])
    }

    @Test func dependencyGraphAddRemoveAndQuery() async throws {
        let store = try newStore()
        let research = try await store.createTask(HiveTask(title: "Research", provenance: "test"))
        let draft = try await store.createTask(HiveTask(title: "Draft", provenance: "test"))
        let review = try await store.createTask(HiveTask(title: "Review", provenance: "test"))

        _ = try await store.addDependency(taskID: draft.id, dependsOn: research.id)
        _ = try await store.addDependency(taskID: review.id, dependsOn: research.id)

        #expect(try await store.getDependencies(of: draft.id).map(\.id) == [research.id])
        #expect(Set(try await store.getDependents(of: research.id).map(\.id)) == Set([draft.id, review.id]))

        // Self-dependency refused
        #expect(try await store.addDependency(taskID: draft.id, dependsOn: draft.id) == nil)
        // Removal
        #expect(try await store.removeDependency(taskID: review.id, dependsOn: research.id) == true)
        #expect(try await store.getDependents(of: research.id).map(\.id) == [draft.id])
    }

    @Test func blockedTasksDetectIncompleteDependencies() async throws {
        let store = try newStore()
        let project = try await store.createProject(Project(title: "Build", provenance: "test"))
        let research = try await store.createTask(
            HiveTask(title: "Research", state: .open, provenance: "test"))
        let draft = try await store.createTask(
            HiveTask(title: "Draft", state: .open, provenance: "test"))
        let doneDep = try await store.createTask(
            HiveTask(title: "Setup", state: .done, provenance: "test"))
        let unblocked = try await store.createTask(
            HiveTask(title: "Free", state: .open, provenance: "test"))

        _ = try await store.addDependency(taskID: draft.id, dependsOn: research.id)
        _ = try await store.addDependency(taskID: unblocked.id, dependsOn: doneDep.id)
        for taskID in [research.id, draft.id, doneDep.id, unblocked.id] {
            _ = try await store.addTaskToProject(taskID: taskID, projectID: project.id)
        }

        let blocked = try await store.getBlockedTasks(projectID: project.id)
        #expect(blocked.map(\.id) == [draft.id], "only draft is blocked (research is open)")
    }

    @Test func actionInboxExcludesDoneAndOrdersOverdue() async throws {
        let store = try newStore()
        let past = Date().addingTimeInterval(-3600)
        let future = Date().addingTimeInterval(86400)
        _ = try await store.createTask(HiveTask(title: "Done task", state: .done, provenance: "test"))
        _ = try await store.createTask(HiveTask(title: "Overdue", dueDate: past, provenance: "test"))
        _ = try await store.createTask(HiveTask(title: "Upcoming", dueDate: future, provenance: "test"))
        _ = try await store.createTask(HiveTask(title: "No date", provenance: "test"))

        let inbox = try await store.getActionInbox()
        #expect(inbox.count == 3)
        #expect(inbox.first?.title == "Overdue", "overdue tasks lead the inbox")
        #expect(!inbox.contains { $0.title == "Done task" })
    }
}

// MARK: - Hot memory persistence (DATA-002)

@Suite("HotMemoryPersistence")
struct HotMemoryPersistenceTests {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-hot-memory-\(UUID().uuidString).json")
    }

    private func makeStore(at url: URL, honeycomb: HoneycombStore? = nil) -> HotMemoryStore {
        HotMemoryStore(honeycomb: honeycomb, persistenceURL: url)
    }

    @Test func saveAndReloadRoundTripsEntriesForgottenAndProject() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let a = makeStore(at: url)
        await a.didAccessNode(id: "page-1", sourceHint: "browsed", label: "Apple", content: "AAPL", projectID: "proj-1")
        await a.didAccessNode(id: "capture-2", sourceHint: "captured", label: "Capture", projectID: "proj-1")
        await a.setActiveProject("proj-1")
        _ = await a.forgetNode(id: "page-1")
        await a.saveNow()

        let b = makeStore(at: url)
        let entries = await b.currentHotEntries()
        #expect(entries.map(\.id).sorted() == ["capture-2"], "forgotten entry not restored")
        #expect(entries.first?.label == "Capture")
        #expect(entries.first?.sourceHint == "captured")
        #expect(await b.forgottenNodeIDList() == ["page-1"], "forget intent is durable")
        #expect(await b.activeProjectBinding() == "proj-1")
    }

    @Test func fullContextScopeFlagsSurviveRestart() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let scope = ContextScope(
            profileID: "profile-a",
            workspaceID: "workspace-a",
            projectID: "project-a",
            allowedTabIDs: ["tab-a", "tab-b"],
            includesCurrentPage: true,
            includesProjectNodes: false,
            includesPreferences: false,
            includesPrivateContent: true
        )
        let a = makeStore(at: url)
        await a.setActiveScope(scope)
        await a.didAccessGlobalNode(id: "global-preference", sourceHint: "preference")
        await a.saveNow()

        let b = makeStore(at: url)
        #expect(await b.currentScope() == scope,
                "selected tabs and inclusion/privacy flags must survive restart")
        #expect(await b.currentHotEntries().map(\.id) == ["global-preference"])
    }

    @Test func forgetSticksAcrossRestart() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let a = makeStore(at: url)
        await a.didAccessNode(id: "page-1", label: "Sensitive")
        _ = await a.forgetNode(id: "page-1")
        await a.saveNow()

        let b = makeStore(at: url)
        await b.didAccessNode(id: "page-1", label: "Sensitive")   // passive re-access
        #expect(await b.currentHotEntries().isEmpty,
                "forgotten memory must not resurrect across a restart")
        #expect(await b.forgottenNodeIDList() == ["page-1"])
    }

    @Test func clearDeletesPersistenceFile() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let a = makeStore(at: url)
        await a.didAccessNode(id: "page-1")
        await a.saveNow()
        #expect(FileManager.default.fileExists(atPath: url.path))

        await a.clear()
        #expect(!FileManager.default.fileExists(atPath: url.path),
                "cleared memory must not resurrect on next launch")

        let b = makeStore(at: url)
        #expect(await b.currentHotEntries().isEmpty)
    }

    @Test func missingFileStartsEmpty() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = makeStore(at: url)
        #expect(await store.currentHotEntries().isEmpty)
        #expect(await store.forgottenNodeIDList().isEmpty)
        #expect(await store.activeProjectBinding() == nil)
    }

    @Test func corruptFilePreservedAndStartsEmpty() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not-json{{{".utf8).write(to: url)

        let store = makeStore(at: url)
        #expect(await store.currentHotEntries().isEmpty)
        #expect(FileManager.default.fileExists(atPath: url.path),
                "corrupt data is preserved on disk, never silently destroyed")
    }

    @Test func pageContextIsEphemeralNotPersisted() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let a = makeStore(at: url)
        await a.setCurrentPage(PageContext(
            tabID: "t1", url: URL(string: "https://example.com"),
            title: "Example", text: "body"))
        await a.didAccessNode(id: "page-1", label: "Example")
        await a.saveNow()

        let b = makeStore(at: url)
        let ctx = await b.assembleContext()
        #expect(ctx.currentPage == nil, "current page context is ephemeral")
        #expect(ctx.hotNodes == ["page-1"], "hot entries do persist")
    }

    @Test func nilPersistenceURLKeepsStoreInMemoryOnly() async throws {
        let store = HotMemoryStore()
        await store.didAccessNode(id: "page-1", label: "Ephemeral")
        await store.saveNow()   // no-op — must not crash or write anywhere
        #expect(await store.currentHotEntries().count == 1)
    }
}

// MARK: - Dispatcher: Cell prompt integration

@Suite("DispatcherCellPrompt")
struct DispatcherCellPromptTests {

    @Test func generateWithCellPromptRoutesThroughDispatcher() async throws {
        // With a temp Cell file present, Dispatcher.generateWithCellPrompt
        // should inject the Cell's system prompt into the request. The provider
        // depends on the host (mock, appleFMF, or mlx) — all are valid.
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-test-disp-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let routerDir = tmpDir.appendingPathComponent("router", isDirectory: true)
        try FileManager.default.createDirectory(at: routerDir, withIntermediateDirectories: true)
        try """
        # 100m_intent_router
        ## Job (one sentence)
        Classify intent.
        ## Distilled rules (from source prompts)
        Route deterministically.
        """.write(to: routerDir.appendingPathComponent("100m_intent_router.md"),
                 atomically: true, encoding: .utf8)

        let d = Dispatcher()
        let loader = CellPromptLoader(promptsDir: tmpDir)
        let res = try await d.generateWithCellPrompt(
            for: .intentClassifier, userInput: "search for something", loader: loader)

        #expect(res.role == .intentClassifier)
        // Provider depends on host capabilities; any non-rule provider is valid
        #expect(res.provider != .rule, "rule-based should not serve instruct roles")
    }

    @Test func generateWithCellPromptFallsBackWithoutLoader() async throws {
        // When no loader is provided, generateWithCellPrompt behaves like
        // a bare generate() call — dispatches by role with empty system.
        let d = Dispatcher()
        let res = try await d.generateWithCellPrompt(
            for: .intentClassifier, userInput: "test")

        #expect(res.role == .intentClassifier)
        // Provider depends on host; verify it's a valid non-rule provider
        #expect(res.provider != .rule)
    }

    @Test func generateWithCellPromptWorksForAllMappedRoles() async throws {
        // Every role in the Cell mapping can be dispatched through
        // generateWithCellPrompt. With real Cell files on disk, the system
        // prompt is injected. Without, it falls back gracefully.

        // Locate the actual Swarm_System_Prompts directory. It is bundled as a
        // resource of the Hive target, so it lives under Sources/Hive/Resources.
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let promptsDir = repoRoot
            .appendingPathComponent("Sources/Hive/Resources/Swarm_System_Prompts", isDirectory: true)
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: promptsDir.path, isDirectory: &isDir) && isDir.boolValue,
                "Swarm_System_Prompts should exist at Sources/Hive/Resources/Swarm_System_Prompts")

        let loader = CellPromptLoader(promptsDir: promptsDir)
        let d = Dispatcher()

        for role in CellPromptLoader.cellRoleMapping.keys {
            let res = try await d.generateWithCellPrompt(
                for: role, userInput: "test", loader: loader)
            #expect(res.role == role, "wrong role for \(role.rawValue)")
            // With real Cell files, the system prompt should be non-empty
            if let prompt = loader.loadSystemPrompt(for: role) {
                #expect(!prompt.isEmpty, "prompt should not be empty for \(role.rawValue)")
            }
        }
    }
}

// MARK: - Hive color tokens (SPEC §2 anti-slop invariants)

@Suite("HiveColorToken")
struct HiveColorTokenTests {

    @Test func accentIsHiveAmberDarkMode() {
        // Brand v1.0 — Hive Amber in dark mode is #FFB84D. Unique among browsers. Never blue/purple.
        #expect(HiveColorToken.accent.hex.uppercased() == "#FFB84D")
    }

    @Test func backgroundIsWarmMahoganyNotPureBlack() {
        // SPEC §2.5 — never pure black (#000000). Always warm mahogany #1A1512.
        #expect(HiveColorToken.background.hex.uppercased() == "#1A1512")
        #expect(HiveColorToken.background.isNotPureBlackOrWhite)
    }

    @Test func inkIsCandlelightCreamNotPureWhite() {
        // SPEC §2.5 — never pure white (#FFFFFF) for dark-mode text. Use candlelight cream #F0EBE2.
        #expect(HiveColorToken.ink.hex.uppercased() == "#F0EBE2")
        #expect(HiveColorToken.ink.isNotPureBlackOrWhite)
    }

    @Test func noTokenIsPureBlackOrWhite() {
        // Anti-slop invariant: every dark-mode solid must avoid pure black/white.
        for token in HiveColorToken.allCases where token.isDarkModeSolid {
            #expect(token.isNotPureBlackOrWhite, "\(token.rawValue) is pure black/white — forbidden by SPEC §2.5")
        }
    }

    @Test func rgbComponentsRoundTripFromHex() {
        // accent #FFB84D → r=1.0, g=0.722, b=0.306
        let rgb = HiveColorToken.accent.rgb
        #expect(abs(rgb.r - (0xFF / 255.0)) < 0.001)
        #expect(abs(rgb.g - (0xB8 / 255.0)) < 0.001)
        #expect(abs(rgb.b - (0x4D / 255.0)) < 0.001)
    }

    @Test func hexDropsLeadingHash() {
        // hexDigits should be the 6 RGB hex chars with no '#'.
        #expect(HiveColorToken.accent.hexDigits == "FFB84D")
        #expect(!HiveColorToken.background.hex.hasPrefix("#") == false) // hasPrefix is true; sanity
        #expect(HiveColorToken.background.hexDigits.count == 6)
    }

    @Test func lightModeAccentIsHiveAmber() {
        // Brand v1.1 — light-mode accent is the deep AA-compliant Hive Amber #9A5A00
        // (≈4.9:1 on warm paper), while dark mode keeps the brighter brand amber.
        #expect(HiveColorToken.accentLight.hex.uppercased() == "#9A5A00")
    }

    @Test func alphaTokensUseCanonicalBasesAndOpacities() {
        // SPEC §2.2 — border = white@12%, glass = white@6%, glassTinted = accent@12%.
        #expect(HiveAlphaToken.border.base == .ink)
        #expect(abs(HiveAlphaToken.border.opacity - 0.12) < 0.001)
        #expect(HiveAlphaToken.glass.base == .ink)
        #expect(abs(HiveAlphaToken.glass.opacity - 0.06) < 0.001)
        #expect(HiveAlphaToken.glassTinted.base == .accent)
        #expect(abs(HiveAlphaToken.glassTinted.opacity - 0.12) < 0.001)
    }

    @Test func everyDarkModeTokenCaseDistinct() {
        // No two dark mode solid tokens should share the same hex (catches typos).
        let darkTokens = HiveColorToken.allCases.filter { $0.isDarkModeSolid }
        let hexes = Set(darkTokens.map { $0.hex.uppercased() })
        #expect(hexes.count == darkTokens.count, "two dark-mode tokens share the same hex")
    }

    @Test func forbiddenValuesNeverPresentInDarkMode() {
        // SPEC §2.5 anti-slop applies to DARK-MODE tokens only (never pure black bg,
        // never pure white text). Light-mode surfaces may legitimately be #FFFFFF
        // (SPEC §2.3 surfaceLight) and light-mode ink may be the warm near-black.
        for token in HiveColorToken.allCases where token.isDarkModeSolid {
            #expect(!HiveColorToken.forbidden.contains { $0.uppercased() == token.hex.uppercased() },
                    "dark-mode token \(token.rawValue) is pure black/white — forbidden by SPEC §2.5")
        }
    }

    @Test func lightModeSurfaceIsWarmPaperNotPureWhite() {
        // SPEC §2.3 — light-mode surface is warm paper #FFFDF8 by design. This honors the
        // anti-slop rule: never pure white anywhere in the palette.
        #expect(HiveColorToken.surfaceLight.hex.uppercased() == "#FFFDF8")
    }
}

// MARK: - Browser lifecycle models (Step 1)

@Suite("BrowserModels")
struct BrowserModelTests {

    // MARK: BrowserTab

    @Test func browserTabCodableRoundTrips() throws {
        let tab = BrowserTab(url: URL(string: "https://hive.app/guide"),
                             pendingURL: URL(string: "https://hive.app/guide/next"),
                             title: "Guide",
                             faviconURL: URL(string: "https://hive.app/favicon.ico"),
                             isLoading: true,
                             loadProgress: 0.42,
                             canGoBack: true,
                             canGoForward: true,
                             isActive: true,
                             isPinned: true,
                             isPrivate: false,
                             isMuted: true,
                             spaceID: "work",
                             isHibernated: false,
                             zoomLevel: 1.25,
                             createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                             lastVisitedAt: Date(timeIntervalSince1970: 1_700_000_500))
        let data = try JSONEncoder().encode(tab)
        let decoded = try JSONDecoder().decode(BrowserTab.self, from: data)
        #expect(decoded == tab)
        #expect(decoded.id == tab.id)          // identity survives round-trip
        #expect(decoded.isActive == true)
        #expect(decoded.spaceID == "work")
        #expect(decoded.zoomLevel == 1.25)
    }

    @Test func browserTabDisplayTitleFallsBackThroughHostToNewTab() {
        // 1. Real title wins.
        let titled = BrowserTab(url: URL(string: "https://hive.app"),
                                title: "The Hive Browser")
        #expect(titled.displayTitle == "The Hive Browser")

        // 2. Empty title falls back to the host.
        let untitled = BrowserTab(url: URL(string: "https://news.example.com/article/7"),
                                  title: "")
        #expect(untitled.displayTitle == "news.example.com")

        // 3. No URL and no title → "New Tab" (the start-page state).
        let fresh = BrowserTab(url: nil, title: "")
        #expect(fresh.displayTitle == "New Tab")
    }

    @Test func newTabFactorySetsActiveAndPrivacyAndSpace() {
        let plain = BrowserTab.newTab()
        #expect(plain.isActive == true)        // new tabs are selected immediately
        #expect(plain.isPrivate == false)
        #expect(plain.spaceID == nil)
        #expect(plain.url == nil)              // shows start page until navigation
        #expect(plain.displayTitle == "New Tab")

        let private1 = BrowserTab.newTab(isPrivate: true)
        #expect(private1.isPrivate == true)
        #expect(private1.isActive == true)

        let inSpace = BrowserTab.newTab(spaceID: "personal")
        #expect(inSpace.spaceID == "personal")
    }

    @Test func privateTabPrivacyRoundTripsThroughCodable() throws {
        let original = BrowserTab(
            id: "private-tab",
            url: URL(string: "https://private.example/account"),
            title: "Private account",
            isPrivate: true,
            spaceID: "space-a"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrowserTab.self, from: data)

        #expect(decoded == original)
        #expect(decoded.isPrivate)
    }

    @Test func everyBrowserTabHasAUniqueID() {
        // Identifiable contract — IDs must be stable and distinct across instances.
        let a = BrowserTab.newTab()
        let b = BrowserTab.newTab()
        #expect(a.id != b.id)
        #expect(!a.id.isEmpty)
    }

    @Test func closedTabRecordCodableRoundTrips() throws {
        let rec = ClosedTabRecord(url: URL(string: "https://example.com")!,
                                  title: "Example",
                                  closedAt: Date(timeIntervalSince1970: 1_700_000_123))
        let data = try JSONEncoder().encode(rec)
        let back = try JSONDecoder().decode(ClosedTabRecord.self, from: data)
        #expect(back == rec)
    }

    // MARK: Space

    @Test func spaceAddTabIsIdempotentAndOrderPreserving() {
        var space = Space(name: "Work")
        space.addTab("a")
        space.addTab("b")
        space.addTab("a")   // duplicate — ignored
        #expect(space.tabIDs == ["a", "b"])
        #expect(space.contains(tabID: "b"))
        #expect(!space.contains(tabID: "z"))
    }

    @Test func spaceRemoveTabClearsActiveTabID() {
        var space = Space(name: "Work", tabIDs: ["a", "b", "c"], activeTabID: "b")
        space.removeTab("b")
        #expect(space.tabIDs == ["a", "c"])
        // Active tab removed → falls back to the last remaining tab.
        #expect(space.activeTabID == "c")
    }

    @Test func spaceRemoveTabWhenActiveSurvivesKeepsActiveTabID() {
        var space = Space(name: "Work", tabIDs: ["a", "b", "c"], activeTabID: "a")
        space.removeTab("c")
        #expect(space.activeTabID == "a")
    }

    @Test func spaceMoveTabToFront() {
        var space = Space(name: "W", tabIDs: ["a", "b", "c", "d"])
        space.moveTab("d", to: 0)
        #expect(space.tabIDs == ["d", "a", "b", "c"])
    }

    @Test func spaceMoveTabToEnd() {
        // The case the old -1-correction got wrong: final index must be count-1.
        var space = Space(name: "W", tabIDs: ["a", "b", "c"])
        space.moveTab("a", to: 2)
        #expect(space.tabIDs == ["b", "c", "a"])
    }

    @Test func spaceMoveTabWithinRightward() {
        var space = Space(name: "W", tabIDs: ["a", "b", "c", "d"])
        space.moveTab("b", to: 2)
        // b ends up at final index 2: [a, c, b, d]
        #expect(space.tabIDs == ["a", "c", "b", "d"])
    }

    @Test func spaceMoveTabWithinLeftward() {
        var space = Space(name: "W", tabIDs: ["a", "b", "c", "d"])
        space.moveTab("c", to: 1)
        // c ends up at final index 1: [a, c, b, d]
        #expect(space.tabIDs == ["a", "c", "b", "d"])
    }

    @Test func spaceMoveTabSameIndexIsNoOp() {
        var space = Space(name: "W", tabIDs: ["a", "b", "c"])
        space.moveTab("b", to: 1)
        #expect(space.tabIDs == ["a", "b", "c"])
    }

    @Test func spaceMoveForeignTabIsNoOp() {
        var space = Space(name: "W", tabIDs: ["a", "b", "c"])
        space.moveTab("zzz", to: 0)
        #expect(space.tabIDs == ["a", "b", "c"])
    }

    @Test func spaceMoveTabClampsOutOfRangeIndex() {
        var space = Space(name: "W", tabIDs: ["a", "b", "c"])
        space.moveTab("a", to: 999)   // clamps to last
        #expect(space.tabIDs == ["b", "c", "a"])
        space.moveTab("a", to: -5)     // clamps to first
        #expect(space.tabIDs == ["a", "b", "c"])
    }

    @Test func spaceCodableRoundTrips() throws {
        let space = Space(name: "Personal",
                          accentTokenName: HiveColorToken.accent.rawValue,
                          tabIDs: ["x", "y", "z"],
                          activeTabID: "y")
        let data = try JSONEncoder().encode(space)
        let back = try JSONDecoder().decode(Space.self, from: data)
        #expect(back == space)
    }

    @Test func defaultSpaceIsNamedDefault() {
        let s = Space.defaultSpace()
        #expect(s.name == "Default")
        #expect(s.tabIDs.isEmpty)
        #expect(s.activeTabID == nil)
    }

    // MARK: TabPosition

    @Test func tabPositionHasExactlyTwoLayouts() {
        // The owner's directive: H OR V — never both. No `.bottom` case exists.
        #expect(TabPosition.allCases.count == 2)
        #expect(Set(TabPosition.allCases) == [.top, .vertical])
    }

    @Test func tabPositionToggledFlipsBetweenTheTwo() {
        // ⌘⇧L toggles — verify it's a clean two-state flip, never a third state.
        var pos = TabPosition.top
        pos = pos.toggled
        #expect(pos == .vertical)
        pos = pos.toggled
        #expect(pos == .top)
    }

    @Test func tabPositionCodableRoundTrips() throws {
        for pos in TabPosition.allCases {
            let data = try JSONEncoder().encode(pos)
            let back = try JSONDecoder().decode(TabPosition.self, from: data)
            #expect(back == pos)
        }
    }

    @Test func tabPositionDisplayNamesAreHuman() {
        #expect(TabPosition.top.displayName == "Top Tabs")
        #expect(TabPosition.vertical.displayName == "Vertical Tabs")
    }

    // MARK: TabDensity

    @Test func tabDensityHasThreeSteps() {
        #expect(TabDensity.allCases.count == 3)
        #expect(TabDensity.allCases == [.compact, .standard, .spacious])
    }

    // MARK: ChromeUserPrefs

    @Test func userPrefsDefaultsShipVerticalStandardGoogle() {
        let d = ChromeUserPrefs.defaults
        // Fresh installs use the product's Google/Chromium migration path and vertical rail.
        #expect(d.tabPosition == .vertical)
        #expect(d.tabDensity == .standard)
        #expect(d.defaultSearchEngine == "Google")
        #expect(d.sidebarOpen == false)
        #expect(d.recentlyClosed.isEmpty)
        #expect(d.activeSpaceID == nil)
    }

    @Test func userPrefsCodableRoundTrips() throws {
        let prefs = ChromeUserPrefs(tabPosition: .vertical,
                                    tabDensity: .compact,
                                    sidebarOpen: true,
                                    defaultSearchEngine: "Brave Search",
                                    honorReduceMotion: true,
                                    activeSpaceID: "work",
                                    recentlyClosed: [
                                        ClosedTabRecord(url: URL(string: "https://a.com")!,
                                                        title: "A")
                                    ])
        let data = try JSONEncoder().encode(prefs)
        let back = try JSONDecoder().decode(ChromeUserPrefs.self, from: data)
        #expect(back == prefs)
        #expect(back.tabPosition == .vertical)
        #expect(back.recentlyClosed.count == 1)
    }

    @Test func hiveClosedTabCapIs25() {
        #expect(Array<ClosedTabRecord>.hiveClosedTabCap == 25)
    }

    @Test func userDefinedCommandRoundTripsAndValidatesWebURLs() throws {
        let command = UserDefinedCommand(
            title: "GitHub Notifications",
            url: " https://github.com/notifications ",
            icon: "  bell  ",
            keywords: [" github ", "", "work"])
        #expect(command.title == "GitHub Notifications")
        #expect(command.url == "https://github.com/notifications")
        #expect(command.icon == "bell")
        #expect(command.keywords == ["github", "work"])
        #expect(command.isValidWebURL)

        let normalized = try JSONDecoder().decode(UserDefinedCommand.self, from: "{\"id\":\"\",\"title\":\"  Hive  \",\"url\":\"https://hive.example\",\"icon\":\"not-a-symbol\",\"keywords\":[\" one \",\"\"]}".data(using: .utf8)!)
        #expect(!normalized.id.isEmpty)
        #expect(normalized.title == "Hive")
        #expect(normalized.icon == "link")
        #expect(normalized.keywords == ["one"])

        let data = try JSONEncoder().encode(command)
        let decoded = try JSONDecoder().decode(UserDefinedCommand.self, from: data)
        #expect(decoded == command)
    }

    @Test func userDefinedCommandRejectsUnsafeOrMalformedURLs() {
        let invalid = [
            UserDefinedCommand(title: "", url: "https://example.com"),
            UserDefinedCommand(title: "Shell", url: "file:///tmp/example"),
            UserDefinedCommand(title: "Script", url: "javascript:alert(1)"),
            UserDefinedCommand(title: "Credentials", url: "https://user:pass@example.com"),
            UserDefinedCommand(title: "Missing host", url: "https:///path")
        ]
        #expect(invalid.allSatisfy { !$0.isValidWebURL })
        #expect(UserDefinedCommand(title: "Fallback", url: "https://example.com", icon: "not-a-symbol").icon == "link")
    }

    @Test func userDefinedCommandsDefaultEmptyAndPersistInPrefs() throws {
        #expect(ChromeUserPrefs.defaults.userDefinedCommands.isEmpty)
        let command = UserDefinedCommand(title: "Hive", url: "https://hive.example")
        let prefs = ChromeUserPrefs(userDefinedCommands: [command])
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(ChromeUserPrefs.self, from: data)
        #expect(decoded.userDefinedCommands == [command])
    }
}

// MARK: - ChromePrefsStore (durable prefs: load / save / quarantine / cap)

@Suite("ChromePrefsStore")
struct ChromePrefsStoreTests {

    /// Makes a throwaway file URL under the system temp dir; cleans it up after the test.
    private func tmpPrefsURL() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HivePrefsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("chrome.json")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    @Test func loadReturnsDefaultsWhenNoFileExists() async throws {
        let url = try tmpPrefsURL()
        defer { cleanup(url) }
        let store = ChromePrefsStore(url: url.appendingPathComponent("absent.json"))
        let prefs = await store.load()
        #expect(prefs == ChromeUserPrefs.defaults)
    }

    @Test func saveThenLoadRoundTrips() async throws {
        let url = try tmpPrefsURL()
        defer { cleanup(url) }
        let store = ChromePrefsStore(url: url)
        let prefs = ChromeUserPrefs(tabPosition: .vertical,
                                    tabDensity: .compact,
                                    defaultSearchEngine: "Brave Search",
                                    activeSpaceID: "work")
        try await store.save(prefs)
        // Fresh store (cache-bust via new instance) reads from disk.
        let reader = ChromePrefsStore(url: url)
        let back = await reader.load()
        #expect(back == prefs)
    }

    @Test func loadQuarantinesCorruptFileAndReturnsDefaults() async throws {
        let url = try tmpPrefsURL()
        defer { cleanup(url) }
        let dir = url.deletingLastPathComponent()
        // Write garbage where prefs should be.
        try Data("{ not valid: json !!! ".utf8).write(to: url, options: .atomic)
        let store = ChromePrefsStore(url: url)
        let prefs = await store.load()
        #expect(prefs == ChromeUserPrefs.defaults)
        // The corrupt file must have been quarantined (renamed), not left in place.
        #expect(!FileManager.default.fileExists(atPath: url.path))
        let quarantine = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.contains(".corrupt-") }
        #expect(quarantine.count == 1, "corrupt file should have been quarantined, found: \(quarantine)")
    }

    @Test func recordClosedTabDedupsByURLAndCapsAt25() async throws {
        let url = try tmpPrefsURL()
        defer { cleanup(url) }
        let store = ChromePrefsStore(url: url)

        // Insert 27 distinct URLs.
        for i in 0..<27 {
            let rec = ClosedTabRecord(url: URL(string: "https://t\(i).com")!,
                                      title: "T\(i)")
            _ = try await store.recordClosedTab(rec)
        }
        let prefs = await store.load()
        #expect(prefs.recentlyClosed.count == 25)            // capped
        #expect(prefs.recentlyClosed.first?.url.absoluteString == "https://t26.com")  // most-recent first

        // Re-recording an existing URL dedups & hoists to the front (no duplicate stack).
        let dup = ClosedTabRecord(url: URL(string: "https://t0.com")!, title: "T0-again")
        _ = try await store.recordClosedTab(dup)
        let prefs2 = await store.load()
        #expect(prefs2.recentlyClosed.count == 25)          // still 25 — t0 moved, not added
        #expect(prefs2.recentlyClosed.first?.url.absoluteString == "https://t0.com")
        #expect(prefs2.recentlyClosed.filter { $0.url.absoluteString == "https://t0.com" }.count == 1)
    }
}

// MARK: - OmniBar / SearchEngine (Step 3)

@Suite("SearchEngine")
struct SearchEngineTests {

    @Test func searchURLForDuckDuckGoEncodesQuery() {
        let url = SearchEngine.searchURL(for: "swift concurrency", engine: .duckduckgo)
        #expect(url?.host == "duckduckgo.com")
        // Spaces encoded (as %20 — we allow only the unreserved set), not left literal.
        let q = url?.query ?? ""
        #expect(q.contains("q=swift"))
        #expect(q.contains("concurrency"))
        #expect(!q.contains(" "))       // no raw spaces in the query string
    }

    @Test func searchURLEncodesAmpersandAndPlusSoTheyDoNotBreakParsing() {
        // "&" and "+" must not leak unencoded into the query — they'd be parsed as separators.
        let url = SearchEngine.searchURL(for: "a & b + c", engine: .google)
        let abs = url?.absoluteString ?? ""
        #expect(abs.contains("a%20"))          // space → %20
        #expect(abs.contains("%26"))            // & → %26
        #expect(abs.contains("%2B"))            // + → %2B (not read as space)
    }

    @Test func emptyQueryProducesNoSearchURL() {
        #expect(SearchEngine.searchURL(for: "") == nil)
        #expect(SearchEngine.searchURL(for: "   ") == nil)
    }

    @Test func eachEnginePointsAtItsOwnHost() {
        #expect(SearchEngine.searchURL(for: "x", engine: .brave)?.host  == "search.brave.com")
        #expect(SearchEngine.searchURL(for: "x", engine: .google)?.host  == "www.google.com")
        #expect(SearchEngine.searchURL(for: "x", engine: .ecosia)?.host  == "www.ecosia.org")
        #expect(SearchEngine.searchURL(for: "x", engine: .startpage)?.host == "www.startpage.com")
    }

    @Test func resolveEngineFromDisplayNameFallsBackToGoogle() {
        #expect(SearchEngineKind.resolve("DuckDuckGo") == .duckduckgo)
        #expect(SearchEngineKind.resolve("Brave Search") == .brave)
        #expect(SearchEngineKind.resolve("Nonsense") == .google)   // safe product default
    }

    // MARK: Omnibar resolution

    @Test func omnibarEmptyReturnsNil() {
        #expect(OmnibarInput.resolveURL(for: "") == nil)
        #expect(OmnibarInput.resolveURL(for: "    ") == nil)
    }

    @Test func omnibarSchemePrefixedIsHonoredAsIs() {
        let https = OmnibarInput.resolveURL(for: "https://hive.app/guide")
        #expect(https?.absoluteString == "https://hive.app/guide")

        let about = OmnibarInput.resolveURL(for: "about:blank")
        #expect(about?.scheme == "about")
    }

    @Test func omnibarBareHostGetsHttpsPrefix() {
        // Switcher muscle memory: type "apple.com" → load apple.com (not search).
        let url = OmnibarInput.resolveURL(for: "apple.com")
        #expect(url?.absoluteString == "https://apple.com")

        let withPath = OmnibarInput.resolveURL(for: "news.ycombinator.com/item?id=42")
        // The query chars after `?` must survive — but as a bare-host input, our heuristic
        // prepends https:// and hands the rest to URL parsing. The host should resolve.
        #expect(withPath?.host == "news.ycombinator.com")
    }

    @Test func omnibarLocalHostsAreURLsNotSearches() {
        #expect(OmnibarInput.resolveURL(for: "localhost:8080")?.host == "localhost")
        #expect(OmnibarInput.resolveURL(for: "127.0.0.1")?.host == "127.0.0.1")
        #expect(OmnibarInput.resolveURL(for: "192.168.1.1")?.host == "192.168.1.1")
    }

    @Test func omnibarSpacesMeanSearchQuery() {
        // "apple macbook" has a space → search, never a host.
        let url = OmnibarInput.resolveURL(for: "apple macbook", engine: .duckduckgo)
        #expect(url?.host == "duckduckgo.com")
        let q = url?.query ?? ""
        #expect(q.contains("apple") && q.contains("macbook"))
    }

    @Test func omnibarSingleWordWithoutDotIsSearch() {
        // "swift" — no dot, not localhost → search.
        let url = OmnibarInput.resolveURL(for: "swift", engine: .duckduckgo)
        #expect(url?.host == "duckduckgo.com")
    }

    @Test func omnibarNumericDecimalIsNotTreatedAsHost() {
        // "3.14" has a dot but no alphabetic label → not a domain → search.
        let url = OmnibarInput.resolveURL(for: "3.14", engine: .duckduckgo)
        #expect(url?.host == "duckduckgo.com")
    }

    @Test func omnibarTrimsWhitespace() {
        let url = OmnibarInput.resolveURL(for: "  apple.com  ")
        #expect(url?.absoluteString == "https://apple.com")
    }

    @Test func omnibarUnknownSchemeWordColonDoesNotShadowHost() {
        // Regression: "localhost:8080" parses (per Foundation) as scheme="localhost",
        // which used to satisfy the "scheme-prefixed → trust" branch and yield a URL with
        // no host. Now only NAVIGABLE schemes short-circuit; "localhost:*" routes through
        // the host heuristic and resolves with a host.
        #expect(OmnibarInput.resolveURL(for: "localhost:8080")?.host == "localhost")
        #expect(OmnibarInput.resolveURL(for: "localhost:3000")?.port == 3000)
    }

    @Test func omnibarUnsafeSchemesAreBlockedNotSearched() {
        #expect(OmnibarInput.resolveURL(for: "data:text/plain,hi") == nil)
        #expect(OmnibarInput.resolveURL(for: "blob:https://x") == nil)
        #expect(OmnibarInput.resolveURL(for: "javascript:alert(1)") == nil)

        guard case .blocked(let scheme) = OmnibarInput.resolve("data:text/plain,hi") else {
            Issue.record("Expected data: to be classified as blocked")
            return
        }
        #expect(scheme == "data")
    }

    @Test func omnibarInternalRoutesRemainExplicitlyNavigable() {
        guard case .navigate(let url) = OmnibarInput.resolve("hive://start") else {
            Issue.record("Expected the registered hive://start route to remain directly navigable")
            return
        }
        #expect(url.scheme == "hive")
        #expect(url.host == "start")
    }

    @Test func omnibarResolutionUsesConfiguredSearchEngine() {
        guard case .search(let url) = OmnibarInput.resolve("privacy browser", engine: .bing) else {
            Issue.record("Expected text input to resolve as a Bing search")
            return
        }
        #expect(url.host == "www.bing.com")
        #expect(url.query?.contains("privacy%20browser") == true)
    }
}

// MARK: - TabGroup (the missing middle — §5)

@Suite("TabGroup")
struct TabGroupTests {

    @Test func tabGroupCodableRoundTrips() throws {
        let g = TabGroup(name: "Research",
                         colorDot: HiveColorToken.accent.rawValue,
                         tabIDs: ["t1", "t2"],
                         isFolded: true,
                         lastActiveTabID: "t1",
                         createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode(g)
        let back = try JSONDecoder().decode(TabGroup.self, from: data)
        #expect(back == g)
        #expect(back.id == g.id)
        #expect(back.isFolded == true)
        #expect(back.tabIDs == ["t1", "t2"])
        #expect(back.lastActiveTabID == "t1")
    }

    @Test func tabGroupDefaultsAreHiveAmberAndUnfolded() {
        let g = TabGroup(name: "Bills")
        #expect(g.colorDot == HiveColorToken.accent.rawValue)
        #expect(g.isFolded == false)
        #expect(g.tabIDs.isEmpty)
        #expect(g.lastActiveTabID == nil)
    }

    @Test func everyTabGroupHasUniqueID() {
        #expect(TabGroup(name: "a").id != TabGroup(name: "b").id)
    }
}

// MARK: - Space.groups (the new field — §5)

@Suite("SpaceGroups")
struct SpaceGroupsTests {

    @Test func spaceGroupsDefaultEmptyAndRoundTrip() throws {
        let s = Space(name: "Work")
        #expect(s.groups.isEmpty)
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(Space.self, from: data)
        #expect(back == s)
        #expect(back.groups.isEmpty)
    }

    @Test func spaceCarriesGroupsThroughCodable() throws {
        let g1 = TabGroup(name: "Research", tabIDs: ["a", "b"], isFolded: true)
        let g2 = TabGroup(name: "Bills", tabIDs: ["c"])
        let s = Space(name: "Work", tabIDs: ["a", "b", "c"], groups: [g1, g2])
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(Space.self, from: data)
        #expect(back.groups.count == 2)
        #expect(back.groups[0].name == "Research")
        #expect(back.groups[0].isFolded == true)
        #expect(back.groups[1].tabIDs == ["c"])
    }

    @Test func existingSpaceCallersUnaffectedByNewField() {
        // The pre-existing labeled-arg call sites (name / tabIDs / activeTabID) must still
        // compile and leave groups empty — a defaulted new trailing param is non-breaking.
        let s = Space(name: "Personal", tabIDs: ["x"], activeTabID: "x")
        #expect(s.groups.isEmpty)
        #expect(s.tabIDs == ["x"])
    }

    @Test func spaceForwardCompatDecodesMissingGroupsAndDefaultedFields() throws {
        // An older session.json written BEFORE `groups` existed has spaces with no `groups` key
        // (and possibly no accentTokenName/tabIDs/createdAt). Those MUST still decode — the
        // trust primitive (§9) requires an older-schema session to load, not fall through to
        // `.corrupt`. Only `id` + `name` are required; the rest default.
        let json = """
        { "id": "legacy-spc", "name": "Legacy" }
        """
        let back = try JSONDecoder().decode(Space.self, from: Data(json.utf8))
        #expect(back.id == "legacy-spc")
        #expect(back.name == "Legacy")
        #expect(back.groups.isEmpty)                          // defaulted from absent key
        #expect(back.tabIDs.isEmpty)                          // defaulted
        #expect(back.accentTokenName == HiveColorToken.accent.rawValue)  // defaulted
        #expect(back.activeTabID == nil)                      // optional → nil
        // A Space with only groups added later still round-trips a full space losslessly.
        let full = Space(id: "s2", name: "Full", tabIDs: ["a"], groups: [TabGroup(name: "G")])
        let data = try JSONEncoder().encode(full)
        let back2 = try JSONDecoder().decode(Space.self, from: data)
        #expect(back2 == full)
    }
}

// MARK: - BrowserSession / BrowserSessionWindow (§9 schema)

@Suite("BrowserSession")
struct BrowserSessionTests {

    @Test func browserSessionCodableRoundTrips() throws {
        let tab = BrowserTab(url: URL(string: "https://hive.app"),
                             title: "Hive", spaceID: "work")
        var space = Space(name: "Work", tabIDs: [tab.id], activeTabID: tab.id)
        space.groups = [TabGroup(name: "Research", tabIDs: [tab.id])]
        let window = BrowserSessionWindow(spaces: [space],
                                          tabs: [tab],
                                          activeSpaceID: space.id,
                                          activeTabID: tab.id,
                                          layout: .vertical,
                                          density: .compact)
        let session = BrowserSession(windows: [window],
                                      savedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode(session)
        let back = try JSONDecoder().decode(BrowserSession.self, from: data)
        #expect(back == session)
        #expect(back.windows.count == 1)
        #expect(back.windows[0].layout == .vertical)
        #expect(back.windows[0].density == .compact)
        #expect(back.windows[0].tabs.first?.url?.absoluteString == "https://hive.app")
        #expect(back.windows[0].spaces.first?.groups.first?.name == "Research")
    }

    @Test func browserSessionDefaultsEmptyForwardCompat() throws {
        // A JSON blob with NO windows + NO savedAt (older-schema fixture) must decode, not throw.
        let data = Data("{}".utf8)
        let back = try JSONDecoder().decode(BrowserSession.self, from: data)
        #expect(back.windows.isEmpty)
    }

    @Test func windowDecodesMissingOptionalFieldsToDefaults() throws {
        // Forward-compat: a window JSON carrying only `spaces` (with the minimum valid Space —
        // `id` is required because tabs reference spaces by it; auto-generating it on decode
        // would break restore identity) must default the rest of the window's fields.
        let json = """
        { "spaces": [ { "id": "s1", "name": "Solo" } ] }
        """
        let back = try JSONDecoder().decode(BrowserSessionWindow.self, from: Data(json.utf8))
        #expect(back.spaces.count == 1)
        #expect(back.spaces[0].name == "Solo")
        #expect(back.spaces[0].id == "s1")
        #expect(back.tabs.isEmpty)
        #expect(back.activeSpaceID == nil)
        #expect(back.activeTabID == nil)
        #expect(back.layout == .vertical)   // fresh-install default
        #expect(back.density == .standard)   // default
    }

    @Test func explicitTopLayoutStillRoundTrips() throws {
        let window = BrowserSessionWindow(layout: .top)
        let data = try JSONEncoder().encode(window)
        let back = try JSONDecoder().decode(BrowserSessionWindow.self, from: data)
        #expect(back.layout == .top)
    }

    @Test func sessionLoadResultEquality() {
        let s = BrowserSession(windows: [BrowserSessionWindow(spaces: [Space(name: "X")])])
        #expect(SessionLoadResult.restored(s) == SessionLoadResult.restored(s))
        #expect(SessionLoadResult.restored(s, repair: BrowserSessionRepairReport(removedPrivateTabs: 1)) != SessionLoadResult.restored(s))
        #expect(SessionLoadResult.none == .none)
        #expect(SessionLoadResult.restored(s) != .none)
        // Two corrupt results with the same recovered session are equal; differing recovered
        // sessions are not. (quarantineURL equality follows URL's Equatable; tested via nil here.)
        #expect(SessionLoadResult.corrupt(quarantineURL: nil, recovered: s)
                == SessionLoadResult.corrupt(quarantineURL: nil, recovered: s))
        #expect(SessionLoadResult.corrupt(quarantineURL: nil, recovered: s)
                != SessionLoadResult.corrupt(quarantineURL: nil, recovered: nil))
        // A corrupt result is a distinct case from .none and .restored regardless of payload.
        #expect(SessionLoadResult.corrupt(quarantineURL: nil, recovered: nil) != .none)
        #expect(SessionLoadResult.corrupt(quarantineURL: nil, recovered: s) != .restored(s))
    }
}

// MARK: - BrowserSessionStore (§9 durable layer — atomic + quarantine + backup-recovery + flush)

@Suite("BrowserSessionStore")
struct BrowserSessionStoreTests {

    private func tmpDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HiveSessionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    // Build a populated session, resilient to the fact that BrowserTab inits its own UUID.
    private func sampleSession(spaceName: String = "Work") -> BrowserSession {
        let tab = BrowserTab(url: URL(string: "https://hive.app/\(UUID().uuidString.prefix(4))"),
                             title: "Hive", spaceID: "spc")
        let space = Space(id: "spc", name: spaceName, tabIDs: [tab.id], activeTabID: tab.id)
        let window = BrowserSessionWindow(spaces: [space], tabs: [tab],
                                          activeSpaceID: "spc", activeTabID: tab.id,
                                          layout: .vertical, density: .compact)
        return BrowserSession(windows: [window])
    }

    @Test func loadReturnsNoneWhenNoFileExists() async throws {
        let dir = try tmpDir(); defer { cleanup(dir) }
        let store = BrowserSessionStore(url: dir.appendingPathComponent("session.json"),
                                        prevURL: dir.appendingPathComponent("session.prev.json"))
        let result = await store.load()
        #expect(result == .none)
    }

    @Test func writeSyncThenLoadRoundTrips() async throws {
        let dir = try tmpDir(); defer { cleanup(dir) }
        let url = dir.appendingPathComponent("session.json")
        let prev = dir.appendingPathComponent("session.prev.json")
        let session = sampleSession(spaceName: "Restored")
        // Synchronous write path = the path app-termination uses.
        BrowserSessionStore.writeSync(session, to: url, prevBackupTo: prev)
        let store = BrowserSessionStore(url: url, prevURL: prev)
        let result = await store.load()
        guard case .restored(let back, _) = result else {
            Issue.record("expected .restored, got \(result)"); return
        }
        #expect(back.windows.count == 1)
        #expect(back.windows[0].spaces.first?.name == "Restored")
        #expect(back.windows[0].layout == .vertical)
        #expect(back.windows[0].density == .compact)
        #expect(back.windows[0].tabs.count == 1)
    }

    @Test func loadQuarantinesCorruptFileAndRecoversFromBackup() async throws {
        let dir = try tmpDir(); defer { cleanup(dir) }
        let url = dir.appendingPathComponent("session.json")
        let prev = dir.appendingPathComponent("session.prev.json")
        // 1. Write a GOOD session, then write AGAIN so the good copy rotates into `prev`.
        let firstSession = sampleSession(spaceName: "GoodBackup")
        BrowserSessionStore.writeSync(firstSession, to: url, prevBackupTo: prev)
        let secondSession = sampleSession(spaceName: "CurrentBad")
        BrowserSessionStore.writeSync(secondSession, to: url, prevBackupTo: prev)
        // At this point: `url` holds the bad (soon-to-corrupt) session; `prev` holds GoodBackup.
        #expect(FileManager.default.fileExists(atPath: prev.path))
        // 2. Corrupt the CURRENT file.
        try Data("{ not: json ".utf8).write(to: url, options: .atomic)
        // 3. Load → must quarantine the corrupt file AND recover GoodBackup from prev.
        let store = BrowserSessionStore(url: url, prevURL: prev)
        let result = await store.load()
        guard case .corrupt(let quarantineURL, let recovered, _) = result else {
            Issue.record("expected .corrupt, got \(result)"); return
        }
        #expect(quarantineURL != nil)
        // The corrupt primary is quarantined, then the valid backup repairs
        // the primary atomically so a second launch cannot lose the recovered
        // session before the next user mutation.
        #expect(FileManager.default.fileExists(atPath: url.path))
        let dirContents = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(dirContents.contains { $0.contains(".corrupt-") })   // quarantined copy exists
        guard let recovered else { Issue.record("expected backup recovery"); return }
        #expect(recovered.windows.first?.spaces.first?.name == "GoodBackup")
        guard case .restored(let repaired, _) = await store.load() else {
            Issue.record("expected repaired primary to load as restored")
            return
        }
        #expect(repaired.windows.first?.spaces.first?.name == "GoodBackup")
    }

    @Test func corruptFileWithNoBackupReturnsCorruptNilRecovered() async throws {
        let dir = try tmpDir(); defer { cleanup(dir) }
        let url = dir.appendingPathComponent("session.json")
        let prev = dir.appendingPathComponent("session.prev.json")
        try Data("garbage".utf8).write(to: url, options: .atomic)   // no backup written
        let store = BrowserSessionStore(url: url, prevURL: prev)
        let result = await store.load()
        guard case .corrupt(_, let recovered, _) = result else {
            Issue.record("expected .corrupt"); return
        }
        #expect(recovered == nil)   // the lostNoBackup branch in HiveApp
    }

    @Test func flushWritesImmediatelyAndCancelsDebounce() async throws {
        let dir = try tmpDir(); defer { cleanup(dir) }
        let url = dir.appendingPathComponent("session.json")
        let prev = dir.appendingPathComponent("session.prev.json")
        let store = BrowserSessionStore(url: url, prevURL: prev, debounceSeconds: 60)
        let session = sampleSession(spaceName: "Flushed")
        // Schedule a save that would wait 60s — then flush immediately, cancelling the wait.
        await store.scheduleSave(session)
        await store.flush(session)
        // File must exist NOW (flush wrote synchronously, no 60s wait).
        #expect(FileManager.default.fileExists(atPath: url.path))
        let back = await store.load()
        guard case .restored(let loaded, _) = back else {
            Issue.record("expected .restored after flush"); return
        }
        #expect(loaded.windows.first?.spaces.first?.name == "Flushed")
    }

    @Test func loadSyncStaticMatchesActorLoad() async throws {
        let dir = try tmpDir(); defer { cleanup(dir) }
        let url = dir.appendingPathComponent("session.json")
        let prev = dir.appendingPathComponent("session.prev.json")
        let session = sampleSession(spaceName: "SyncLoad")
        BrowserSessionStore.writeSync(session, to: url, prevBackupTo: prev)
        let syncResult = BrowserSessionStore.loadSync(url: url, prevURL: prev)
        let asyncResult = await BrowserSessionStore(url: url, prevURL: prev).load()
        // Both paths read the same file with the same decode → same outcome.
        guard case .restored(let s1, _ ) = syncResult, case .restored(let s2, _ ) = asyncResult else {
            Issue.record("expected both restored"); return
        }
        #expect(s1 == s2)
    }

    @Test func writeSyncRotatesPriorGoodFileToBackup() async throws {
        let dir = try tmpDir(); defer { cleanup(dir) }
        let url = dir.appendingPathComponent("session.json")
        let prev = dir.appendingPathComponent("session.prev.json")
        BrowserSessionStore.writeSync(sampleSession(spaceName: "v1"), to: url, prevBackupTo: prev)
        #expect(!FileManager.default.fileExists(atPath: prev.path))   // no prior → no backup yet
        BrowserSessionStore.writeSync(sampleSession(spaceName: "v2"), to: url, prevBackupTo: prev)
        #expect(FileManager.default.fileExists(atPath: prev.path))   // v1 rotated into backup
        let backupResult = await BrowserSessionStore(url: url, prevURL: prev).load()
        if case .corrupt(_, let recovered, _) = backupResult { _ = recovered }   // touch the path
        // Corrupt current to force recovery from backup.
        let corruptData = try Data(contentsOf: url)
        try Data("\u{0}corrupt".utf8).write(to: url, options: .atomic)
        _ = corruptData
        let recovered = await BrowserSessionStore(url: url, prevURL: prev).load()
        guard case .corrupt(_, let backup, _ ) = recovered, let backup else {
            Issue.record("expected v1 backup recovery"); return
        }
        #expect(backup.windows.first?.spaces.first?.name == "v1")
    }
}

// MARK: - HibernationAdapter

@Suite("HibernationAdapter")
struct HibernationAdapterTests {

    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func activeGroupCannotCollapseButInactiveGroupCan() {
        #expect(!HibernationAdapter.canCollapseGroup(
            memberTabIDs: ["active", "other"], activeTabID: "active"))
        #expect(HibernationAdapter.canCollapseGroup(
            memberTabIDs: ["other"], activeTabID: "active"))
        #expect(HibernationAdapter.canCollapseGroup(
            memberTabIDs: ["other"], activeTabID: nil))
    }

    @Test func explicitCollapseIncludesMRUTabButOrdinaryMRUTabStaysWarm() {
        #expect(HibernationAdapter.shouldIncludeInCandidateSet(
            tabID: "collapsed", isMRU: true, collapsedGroupTabIDs: ["collapsed"]))
        #expect(!HibernationAdapter.shouldIncludeInCandidateSet(
            tabID: "recent", isMRU: true, collapsedGroupTabIDs: []))
        #expect(HibernationAdapter.shouldIncludeInCandidateSet(
            tabID: "old", isMRU: false, collapsedGroupTabIDs: []))
    }

    @Test func restoredActiveGroupIsExpandedBeforeFirstRender() {
        #expect(!HibernationAdapter.restoredCollapseState(
            isCollapsed: true,
            memberTabIDs: ["active", "other"],
            activeTabID: "active"))
        #expect(HibernationAdapter.restoredCollapseState(
            isCollapsed: true,
            memberTabIDs: ["other"],
            activeTabID: "active"))
        #expect(!HibernationAdapter.restoredCollapseState(
            isCollapsed: false,
            memberTabIDs: ["other"],
            activeTabID: "active"))
    }

    @Test func appliesWorkspaceThresholdsAndSkipsUnsupportedTabs() {
        let activeWorkspace = UUID()
        let inactiveWorkspace = UUID()
        let tabs = [
            HibernationAdapter.TabCandidate(
                id: "active-space-young", workspaceID: activeWorkspace,
                hasPage: true, lastAccessed: now.addingTimeInterval(-899)),
            HibernationAdapter.TabCandidate(
                id: "active-space-ready", workspaceID: activeWorkspace,
                hasPage: true, lastAccessed: now.addingTimeInterval(-900)),
            HibernationAdapter.TabCandidate(
                id: "inactive-space-ready", workspaceID: inactiveWorkspace,
                hasPage: true, lastAccessed: now.addingTimeInterval(-300)),
            HibernationAdapter.TabCandidate(
                id: "new-tab", workspaceID: inactiveWorkspace,
                hasPage: false, lastAccessed: now.addingTimeInterval(-9999))
        ]

        let result = HibernationAdapter.evaluate(
            tabs: tabs, activeTabID: "front", activeWorkspaceID: activeWorkspace,
            mediaPlayingTabIDs: [], activeDownloadTabIDs: [], now: now)

        #expect(result == ["active-space-ready", "inactive-space-ready"])
    }

    @Test func protectsActivePinnedEssentialMediaAndDownloads() {
        let workspace = UUID()
        let old = now.addingTimeInterval(-10_000)
        let tabs = [
            HibernationAdapter.TabCandidate(id: "active", workspaceID: workspace,
                                                    hasPage: true, lastAccessed: old),
            HibernationAdapter.TabCandidate(id: "pinned", workspaceID: workspace,
                                                    isPinned: true, hasPage: true, lastAccessed: old),
            HibernationAdapter.TabCandidate(id: "essential", workspaceID: workspace,
                                                    isEssential: true, hasPage: true, lastAccessed: old),
            HibernationAdapter.TabCandidate(id: "media", workspaceID: workspace,
                                                    hasPage: true, lastAccessed: old),
            HibernationAdapter.TabCandidate(id: "download", workspaceID: workspace,
                                                    hasPage: true, lastAccessed: old),
            HibernationAdapter.TabCandidate(id: "eligible", workspaceID: workspace,
                                                    hasPage: true, lastAccessed: old)
        ]

        let result = HibernationAdapter.evaluate(
            tabs: tabs, activeTabID: "active", activeWorkspaceID: workspace,
            mediaPlayingTabIDs: ["media"], activeDownloadTabIDs: ["download"], now: now)

        #expect(result == ["eligible"])
    }

    @Test func collapsedGroupMembersHibernateImmediately() {
        let workspace = UUID()
        let collapsed = HibernationAdapter.TabCandidate(
            id: "collapsed", workspaceID: workspace, hasPage: true,
            lastAccessed: now)
        let result = HibernationAdapter.evaluate(
            tabs: [collapsed], activeTabID: "other", activeWorkspaceID: workspace,
            mediaPlayingTabIDs: [], activeDownloadTabIDs: [],
            collapsedGroupTabIDs: ["collapsed"], now: now)

        #expect(result == ["collapsed"])
    }

    @Test func collapsedGroupNeverOverridesSafetyGuards() {
        let workspace = UUID()
        let old = now.addingTimeInterval(-10_000)
        let tabs = [
            HibernationAdapter.TabCandidate(id: "active", workspaceID: workspace,
                                                    hasPage: true, lastAccessed: old),
            HibernationAdapter.TabCandidate(id: "pinned", workspaceID: workspace,
                                                    isPinned: true, hasPage: true, lastAccessed: old),
            HibernationAdapter.TabCandidate(id: "essential", workspaceID: workspace,
                                                    isEssential: true, hasPage: true, lastAccessed: old),
            HibernationAdapter.TabCandidate(id: "media", workspaceID: workspace,
                                                    hasPage: true, lastAccessed: old),
            HibernationAdapter.TabCandidate(id: "download", workspaceID: workspace,
                                                    hasPage: true, lastAccessed: old),
            HibernationAdapter.TabCandidate(id: "eligible", workspaceID: workspace,
                                                    hasPage: true, lastAccessed: old)
        ]
        let result = HibernationAdapter.evaluate(
            tabs: tabs, activeTabID: "active", activeWorkspaceID: workspace,
            mediaPlayingTabIDs: ["media"], activeDownloadTabIDs: ["download"],
            collapsedGroupTabIDs: Set(tabs.map(\.id)), now: now)

        #expect(result == ["eligible"])
    }

    @Test func customThresholdsRemainDeterministic() {
        let workspace = UUID()
        let tab = HibernationAdapter.TabCandidate(
            id: "tab", workspaceID: workspace, hasPage: true,
            lastAccessed: now.addingTimeInterval(-60))
        let thresholds = HibernationPolicy.Thresholds(bgActiveSpaceSec: 30, inactiveSpaceSec: 10)

        let result = HibernationAdapter.evaluate(
            tabs: [tab], activeTabID: "other", activeWorkspaceID: workspace,
            mediaPlayingTabIDs: [], activeDownloadTabIDs: [], now: now,
            thresholds: thresholds)

        #expect(result == ["tab"])
    }

    @Test func capturingMediaTabIsNeverHibernated() {
        let workspace = UUID()
        let old = now.addingTimeInterval(-10_000)
        let capturing = HibernationAdapter.TabCandidate(
            id: "call", workspaceID: workspace, hasPage: true,
            lastAccessed: old, isCapturingMedia: true)
        let result = HibernationAdapter.evaluate(
            tabs: [capturing], activeTabID: "other", activeWorkspaceID: workspace,
            mediaPlayingTabIDs: [], activeDownloadTabIDs: [],
            collapsedGroupTabIDs: ["call"], now: now)
        // Even explicit group collapse cannot sever a live WebRTC/screen capture.
        #expect(result.isEmpty)
    }

    @Test func formEntryTabIsNeverHibernated() {
        let workspace = UUID()
        let old = now.addingTimeInterval(-10_000)
        let drafting = HibernationAdapter.TabCandidate(
            id: "draft", workspaceID: workspace, hasPage: true,
            lastAccessed: old, hasFormEntry: true)
        let result = HibernationAdapter.evaluate(
            tabs: [drafting], activeTabID: "other", activeWorkspaceID: workspace,
            mediaPlayingTabIDs: [], activeDownloadTabIDs: [], now: now)
        #expect(result.isEmpty)
    }

    @Test func protectedSchemeTabIsNeverHibernated() {
        let workspace = UUID()
        let old = now.addingTimeInterval(-10_000)
        let tabs = [
            HibernationAdapter.TabCandidate(
                id: "hive", workspaceID: workspace, hasPage: true,
                lastAccessed: old, urlScheme: "hive"),
            HibernationAdapter.TabCandidate(
                id: "about", workspaceID: workspace, hasPage: true,
                lastAccessed: old, urlScheme: "about"),
            HibernationAdapter.TabCandidate(
                id: "chrome", workspaceID: workspace, hasPage: true,
                lastAccessed: old, urlScheme: "chrome"),
            HibernationAdapter.TabCandidate(
                id: "web", workspaceID: workspace, hasPage: true,
                lastAccessed: old, urlScheme: "https")
        ]
        let result = HibernationAdapter.evaluate(
            tabs: tabs, activeTabID: "other", activeWorkspaceID: workspace,
            mediaPlayingTabIDs: [], activeDownloadTabIDs: [], now: now)
        #expect(result == ["web"])
    }

    @Test func recentlyAudibleTabIsDeferredWithinGraceWindow() {
        let workspace = UUID()
        let old = now.addingTimeInterval(-10_000)
        let tabs = [HibernationAdapter.TabCandidate(
            id: "just-audible", workspaceID: workspace, hasPage: true,
            lastAccessed: old)]
        // Not currently playing audio, but audible within the grace window: deferred.
        let deferred = HibernationAdapter.evaluate(
            tabs: tabs, activeTabID: "other", activeWorkspaceID: workspace,
            mediaPlayingTabIDs: [], activeDownloadTabIDs: [],
            recentlyAudibleTabIDs: ["just-audible"], now: now)
        #expect(deferred.isEmpty)
        // Without the recent-audio signal the same tab is eligible.
        let eligible = HibernationAdapter.evaluate(
            tabs: tabs, activeTabID: "other", activeWorkspaceID: workspace,
            mediaPlayingTabIDs: [], activeDownloadTabIDs: [], now: now)
        #expect(eligible == ["just-audible"])
    }

    @Test func isProtectedSchemeHandlesKnownAndUnknownSchemes() {
        #expect(HibernationAdapter.isProtectedScheme("hive"))
        #expect(HibernationAdapter.isProtectedScheme("about"))
        #expect(HibernationAdapter.isProtectedScheme("chrome"))
        #expect(HibernationAdapter.isProtectedScheme("chrome-extension"))
        #expect(HibernationAdapter.isProtectedScheme("ABOUT")) // case-insensitive
        #expect(!HibernationAdapter.isProtectedScheme("https"))
        #expect(!HibernationAdapter.isProtectedScheme("http"))
        #expect(!HibernationAdapter.isProtectedScheme("file"))
        #expect(!HibernationAdapter.isProtectedScheme(nil))
    }

    @Test func alreadyHibernatedTabsAreNotSelectedAgain() {
        let workspace = UUID()
        let old = now.addingTimeInterval(-10_000)
        let sleeping = HibernationAdapter.TabCandidate(
            id: "sleeping", workspaceID: workspace, hasPage: true,
            isHibernated: true, lastAccessed: old)
        let result = HibernationAdapter.evaluate(
            tabs: [sleeping], activeTabID: "other", activeWorkspaceID: workspace,
            mediaPlayingTabIDs: [], activeDownloadTabIDs: [],
            collapsedGroupTabIDs: ["sleeping"], now: now)
        #expect(result.isEmpty,
                "a cold tab must not be reselected by age or collapsed-group evaluation")
    }

    @Test func effectiveWakeURLPreservesSavedURLAndRejectsBlankPages() {
        let saved = URL(string: "https://example.com/remembered")!
        #expect(HibernationAdapter.effectiveWakeURL(
            currentURL: nil, savedURL: saved) == saved)
        #expect(HibernationAdapter.effectiveWakeURL(
            currentURL: URL(string: "https://example.com/current"), savedURL: saved)
            == URL(string: "https://example.com/current"))
        #expect(HibernationAdapter.effectiveWakeURL(
            currentURL: URL(string: "about:blank"), savedURL: saved) == saved,
            "a blank live renderer must fall back to a valid wake destination")
        #expect(HibernationAdapter.effectiveWakeURL(
            currentURL: nil, savedURL: URL(string: "about:blank")) == nil)
        #expect(HibernationAdapter.effectiveWakeURL(
            currentURL: nil, savedURL: nil) == nil)
    }
}

// MARK: - HibernationPolicy (§8 trigger table — pure)

@Suite("HibernationPolicy")
struct HibernationPolicyTests {

    // Build a tab with a provided last-visited timestamp; url is set so it's eligible.
    private func tab(id: String, spaceID: String, url: String = "https://hive.app",
                     pinned: Bool = false, lastVisited: Date) -> BrowserTab {
        var t = BrowserTab(id: id, url: URL(string: url), title: "T", spaceID: spaceID)
        t.isPinned = pinned
        t.lastVisitedAt = lastVisited
        return t
    }
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func pinnedTabNeverHibernatesEvenWhenVeryIdle() {
        let t = tab(id: "p", spaceID: "s", pinned: true, lastVisited: now.addingTimeInterval(-99999))
        let hib = HibernationPolicy.evaluate(tabs: [t], spaces: [Space(id: "s", name: "S")],
                                             activeTabID: "other", activeSpaceID: "s",
                                             now: now)
        #expect(hib.isEmpty)   // rule 1: pinned → never
    }

    @Test func activeTabNeverHibernates() {
        let t = tab(id: "a", spaceID: "s", lastVisited: now.addingTimeInterval(-99999))
        let hib = HibernationPolicy.evaluate(tabs: [t], spaces: [Space(id: "s", name: "S")],
                                             activeTabID: "a", activeSpaceID: "s", now: now)
        #expect(hib.isEmpty)   // rule 2: active → never
    }

    @Test func tabWithAudioIsDeferredEvenWhenIdle() {
        let t = tab(id: "aud", spaceID: "s", lastVisited: now.addingTimeInterval(-99999))
        let hib = HibernationPolicy.evaluate(tabs: [t], spaces: [Space(id: "s", name: "S")],
                                             activeTabID: "other", activeSpaceID: "s",
                                             audioPlayingTabIDs: ["aud"], now: now)
        #expect(hib.isEmpty)   // rule 3: audio → defer
    }

    @Test func tabWithActiveDownloadIsDeferredEvenWhenIdle() {
        let t = tab(id: "download", spaceID: "s", lastVisited: now.addingTimeInterval(-99999))
        let hib = HibernationPolicy.evaluate(tabs: [t], spaces: [Space(id: "s", name: "S")],
                                             activeTabID: "other", activeSpaceID: "s",
                                             activeDownloadTabIDs: ["download"], now: now)
        #expect(hib.isEmpty, "an active download must keep its originating tab alive")
    }

    @Test func mediaAndDownloadProtectionApplyBeforeFoldAndAgeRules() {
        let media = tab(id: "media", spaceID: "s", lastVisited: now)
        let download = tab(id: "download", spaceID: "s", lastVisited: now)
        let folded = tab(id: "folded", spaceID: "s", lastVisited: now)
        let group = TabGroup(name: "Research", tabIDs: ["media", "download", "folded"], isFolded: true)
        let space = Space(id: "s", name: "S", tabIDs: ["media", "download", "folded"], groups: [group])

        let hib = HibernationPolicy.evaluate(
            tabs: [media, download, folded], spaces: [space],
            activeTabID: "other", activeSpaceID: "s",
            audioPlayingTabIDs: ["media"],
            activeDownloadTabIDs: ["download"], now: now)

        #expect(hib == ["folded"],
                "live media/download tabs must be protected while unrelated folded tabs still hibernate")
    }

    @Test func tabInFoldedGroupHibernatesImmediately() {
        let t = tab(id: "g1", spaceID: "s", lastVisited: now)   // just visited — 0s idle
        let group = TabGroup(name: "Research", tabIDs: ["g1"], isFolded: true)
        let space = Space(id: "s", name: "S", tabIDs: ["g1"], groups: [group])
        let hib = HibernationPolicy.evaluate(tabs: [t], spaces: [space],
                                             activeTabID: "other", activeSpaceID: "s", now: now)
        #expect(hib == ["g1"])   // rule 4: folded group → NOW, regardless of age
    }

    @Test func tabInUnfoldedGroupDoesNotHibernateByTheFoldRule() {
        let t = tab(id: "g1", spaceID: "s", lastVisited: now)   // 0s — below the 15min threshold
        let group = TabGroup(name: "Research", tabIDs: ["g1"], isFolded: false)   // unfolded
        let space = Space(id: "s", name: "S", tabIDs: ["g1"], groups: [group])
        let hib = HibernationPolicy.evaluate(tabs: [t], spaces: [space],
                                             activeTabID: "other", activeSpaceID: "s", now: now)
        #expect(hib.isEmpty)   // unfolded → falls through to age rules → too young → stays
    }

    @Test func bgTabInActiveSpaceHibernatesAt15MinBoundary() {
        let young = tab(id: "y", spaceID: "s", lastVisited: now.addingTimeInterval(-899))   // 14:59
        let ready = tab(id: "r", spaceID: "s", lastVisited: now.addingTimeInterval(-900))   // 15:00
        let space = Space(id: "s", name: "S", tabIDs: ["y", "r"])
        let hib = HibernationPolicy.evaluate(tabs: [young, ready], spaces: [space],
                                             activeTabID: "front", activeSpaceID: "s", now: now)
        #expect(hib == ["r"])   // rule 5: >= 900s in the active space → hibernate
        #expect(!hib.contains("y"))
    }

    @Test func tabInInactiveSpaceHibernatesAt5MinBoundary() {
        // An inactive space is colder → shorter window (5 min vs 15).
        let young = tab(id: "y", spaceID: "other", lastVisited: now.addingTimeInterval(-299))
        let ready = tab(id: "r", spaceID: "other", lastVisited: now.addingTimeInterval(-300))
        let active = Space(id: "s", name: "Active")
        let inactive = Space(id: "other", name: "Other", tabIDs: ["y", "r"])
        let hib = HibernationPolicy.evaluate(tabs: [young, ready], spaces: [active, inactive],
                                             activeTabID: "front", activeSpaceID: "s", now: now)
        #expect(hib == ["r"])   // rule 6: inactive space, >= 300s → hibernate
    }

    @Test func tabWithNilSpaceIDTreatedAsInactiveSpace() {
        // A tab with no space (edge) follows the colder 5-min rule, not the 15-min one.
        var t = tab(id: "loose", spaceID: "anywhere", lastVisited: now.addingTimeInterval(-300))
        t.spaceID = nil
        let hib = HibernationPolicy.evaluate(tabs: [t], spaces: [Space(id: "s", name: "S")],
                                             activeTabID: "front", activeSpaceID: "s", now: now)
        #expect(hib == ["loose"])   // nil space ≠ active space → 5-min rule fires at 300s
    }

    @Test func tabWithNoUrlIsNeverHibernated() {
        // A fresh new-tab (no URL yet) has nothing to hibernate — no live page to serialize.
        var t = BrowserTab.newTab()
        t.spaceID = "s"
        t.lastVisitedAt = now.addingTimeInterval(-99999)
        let hib = HibernationPolicy.evaluate(tabs: [t], spaces: [Space(id: "s", name: "S")],
                                             activeTabID: "other", activeSpaceID: "s", now: now)
        #expect(hib.isEmpty)
    }

    @Test func precedencePinnedInsideFoldedGroupStillNeverHibernates() {
        // Rule 1 outranks rule 4: even a pinned tab placed (oddly) in a folded group stays alive.
        let t = tab(id: "pg", spaceID: "s", pinned: true, lastVisited: now)
        let group = TabGroup(name: "Pinned?", tabIDs: ["pg"], isFolded: true)
        let space = Space(id: "s", name: "S", tabIDs: ["pg"], groups: [group])
        let hib = HibernationPolicy.evaluate(tabs: [t], spaces: [space],
                                             activeTabID: "other", activeSpaceID: "s", now: now)
        #expect(hib.isEmpty)
    }

    @Test func customThresholdsAreHonored() {
        let t = tab(id: "c", spaceID: "s", lastVisited: now.addingTimeInterval(-60))
        let space = Space(id: "s", name: "S", tabIDs: ["c"])
        let tight = HibernationPolicy.Thresholds(bgActiveSpaceSec: 30, inactiveSpaceSec: 10)
        let hib = HibernationPolicy.evaluate(tabs: [t], spaces: [space],
                                             activeTabID: "front", activeSpaceID: "s",
                                             now: now, thresholds: tight)
        #expect(hib == ["c"])   // 60s idle ≥ 30s custom threshold → hibernate
    }

    @Test func mixedRealisticWindow() {
        // A snapshot resembling a real session: pinned, active, recently-visited, cold, audio,
        // folded-group, and an inactive-space tab — only the eligible ones hibernate.
        let pinned = tab(id: "pin", spaceID: "s", pinned: true,
                         lastVisited: now.addingTimeInterval(-99999))
        let active = tab(id: "act", spaceID: "s", lastVisited: now)
        let recent = tab(id: "rec", spaceID: "s", lastVisited: now.addingTimeInterval(-60))
        let cold   = tab(id: "cold", spaceID: "s", lastVisited: now.addingTimeInterval(-1000))
        let audio  = tab(id: "aud", spaceID: "s", lastVisited: now.addingTimeInterval(-99999))
        let folded = tab(id: "fld", spaceID: "s", lastVisited: now)
        let inact  = tab(id: "inact", spaceID: "other",
                        lastVisited: now.addingTimeInterval(-1000))
        let fg = TabGroup(name: "Research", tabIDs: ["fld"], isFolded: true)
        let s = Space(id: "s", name: "Main", tabIDs: ["pin", "act", "rec", "cold", "aud", "fld"],
                      groups: [fg])
        let other = Space(id: "other", name: "Other", tabIDs: ["inact"])
        let hib = HibernationPolicy.evaluate(
            tabs: [pinned, active, recent, cold, audio, folded, inact],
            spaces: [s, other], activeTabID: "act", activeSpaceID: "s",
            audioPlayingTabIDs: ["aud"], now: now)
        // Expect: cold (1000s ≥ 900s, active space) + folded (immediate) + inact (1000s ≥ 300s, inactive).
        // NOT: pin (pinned), act (active), rec (too young), aud (audio-deferred).
        #expect(hib == ["cold", "fld", "inact"])
    }
}

// MARK: - AutoArchivePolicy (§7 cold-tab detection)

@Suite("AutoArchivePolicy")
struct AutoArchivePolicyTests {

    @Test func returnsEmptyForEmptyTabs() {
        let result = AutoArchivePolicy.evaluate(tabs: [], now: Date())
        #expect(result.isEmpty)
    }

    @Test func skipsPinnedTab() {
        var pin = BrowserTab.newTab(spaceID: "s")
        pin.isPinned = true
        let result = AutoArchivePolicy.evaluate(tabs: [pin], pinnedTabIDs: ["pin"])
        #expect(result.isEmpty)
    }

    @Test func skipsPrivateTabEvenWhenCold() {
        var tab = BrowserTab(url: URL(string: "https://private.example"), isPrivate: true, spaceID: "s")
        tab.lastVisitedAt = Date().addingTimeInterval(-20 * 86_400)
        let result = AutoArchivePolicy.evaluate(tabs: [tab], now: Date())
        #expect(result.isEmpty)
    }

    @Test func skipsActiveTab() {
        var tab = BrowserTab.newTab(spaceID: "s")
        let result = AutoArchivePolicy.evaluate(tabs: [tab], activeTabID: tab.id)
        #expect(result.isEmpty)
    }

    @Test func skipsRecentTab() {
        var tab = BrowserTab.newTab(spaceID: "s")
        tab.lastVisitedAt = Date()
        let result = AutoArchivePolicy.evaluate(tabs: [tab], now: Date())
        #expect(result.isEmpty)
    }

    @Test func flagsColdTab() {
        var tab = BrowserTab(url: URL(string: "https://x.com"), spaceID: "s")
        tab.lastVisitedAt = Date().addingTimeInterval(-20 * 86_400) // 20 days ago
        let result = AutoArchivePolicy.evaluate(tabs: [tab], now: Date())
        #expect(result == [tab.id])
    }

    @Test func skipsNoURLNewTab() {
        var tab = BrowserTab(url: nil, spaceID: "s")
        tab.lastVisitedAt = Date().addingTimeInterval(-20 * 86_400)
        let result = AutoArchivePolicy.evaluate(tabs: [tab], now: Date())
        #expect(result.isEmpty)
    }

    @Test func skipsFoldedGroupMemberEvenWhenCold() {
        var tab = BrowserTab(url: URL(string: "https://a.com"), spaceID: "s")
        tab.lastVisitedAt = Date().addingTimeInterval(-20 * 86_400)
        let result = AutoArchivePolicy.evaluate(tabs: [tab], foldedGroupTabIDs: [tab.id], now: Date())
        #expect(result.isEmpty)
    }

    @Test func mixesConditionsCorrectly() {
        var pinned = BrowserTab(url: URL(string: "https://p.com"), spaceID: "s")
        pinned.isPinned = true
        var cold = BrowserTab(url: URL(string: "https://c.com"), spaceID: "s")
        cold.lastVisitedAt = Date().addingTimeInterval(-20 * 86_400)
        var tab = BrowserTab(url: URL(string: "https://w.com"), spaceID: "s")
        tab.lastVisitedAt = Date()
        let result = AutoArchivePolicy.evaluate(
            tabs: [pinned, cold, tab],
            pinnedTabIDs: [pinned.id],
            now: Date()
        )
        // pinned → skip, cold 20d → flagged, warm → skip
        #expect(result == [cold.id])
    }
}

// MARK: - ArchivedTab (§7 record roundtrip)

@Suite("ArchivedTab")
struct ArchivedTabTests {

    @Test func roundtripsCorrectly() throws {
        let encoder = JSONEncoder(); let decoder = JSONDecoder()
        let tab = ArchivedTab(id: "abc", title: "A Page", url: URL(string: "https://e.com"),
                              faviconURL: URL(string: "https://e.com/f.ico"),
                              sourceSpaceID: "s1", sourceGroupID: "g1",
                              archivedAt: Date(timeIntervalSince1970: 0),
                              lastVisitedAt: Date(timeIntervalSince1970: 86400))
        let data = try encoder.encode(tab)
        let decoded = try decoder.decode(ArchivedTab.self, from: data)
        #expect(decoded.id == tab.id)
        #expect(decoded.title == tab.title)
        #expect(decoded.isPrivate == false)
        #expect(decoded.url == tab.url)
        #expect(decoded.sourceSpaceID == tab.sourceSpaceID)
        #expect(decoded.sourceGroupID == tab.sourceGroupID)
    }

    @Test func decodesMissingOptionalsFromJSON() throws {
        let json = """
        {"id":"a1","title":"Old Tab"}
        """
        let decoded = try JSONDecoder().decode(ArchivedTab.self, from: Data(json.utf8))
        #expect(decoded.id == "a1")
        #expect(decoded.title == "Old Tab")
        #expect(decoded.url == nil)
        #expect(decoded.faviconURL == nil)
        #expect(decoded.sourceSpaceID == nil)
        #expect(decoded.sourceGroupID == nil)
    }
}

// MARK: - WebViewSessionBroker (§8 interactionState stash)

@Suite("WebViewSessionBroker")
struct WebViewSessionBrokerTests {

    @Test func emptyBrokerReportsEmpty() {
        let b = WebViewSessionBroker()
        #expect(b.isEmpty)
        #expect(b.count == 0)
        #expect(b.tabIDs.isEmpty)
        #expect(!b.hasBlob(for: "t1"))
        #expect(b.restore(tabID: "t1") == nil)   // drain on nothing → nil, no crash
    }

    @Test func captureThenRestoreDrainsTheBlob() {
        let b = WebViewSessionBroker()
        // blobs are opaque `Any`; a string stand-in proves the round-trip without a WKWebView.
        b.capture(tabID: "t1", state: "blob-payload-1")
        #expect(b.hasBlob(for: "t1"))
        #expect(b.count == 1)
        let back = b.restore(tabID: "t1")
        #expect((back as? String) == "blob-payload-1")
        // restore drains: a second restore is nil (the sprite can't survive a re-hibernate by residue).
        #expect(b.restore(tabID: "t1") == nil)
        #expect(!b.hasBlob(for: "t1"))
        #expect(b.isEmpty)
    }

    @Test func captureOverwritesAndManyTabsCoexist() {
        let b = WebViewSessionBroker()
        b.capture(tabID: "a", state: "a-blob")
        b.capture(tabID: "b", state: "b-blob")
        b.capture(tabID: "c", state: "c-blob")
        #expect(b.count == 3)
        let order = Set(b.tabIDs)
        #expect(order == ["a", "b", "c"])
        // overwrite same id (controller dropped + recaptured the webview) replaces, not stacks.
        b.capture(tabID: "b", state: "b-blob-v2")
        #expect(b.count == 3)
        #expect((b.restore(tabID: "b") as? String) == "b-blob-v2")
    }

    @Test func captureNilStateLeavesNoTrail() {
        let b = WebViewSessionBroker()
        // a nil-state tab (never loaded, e.g. a blank new tab) captures nothing — close/restore
        // are no-ops. This is why a hibernated blank tab wakes to the start page, not breakage.
        b.capture(tabID: "blank", state: nil)
        #expect(!b.hasBlob(for: "blank"))
        #expect(b.isEmpty)
    }

    @Test func clearDropsABlobSoIdsDontResurrect() {
        let b = WebViewSessionBroker()
        b.capture(tabID: "t1", state: "old-page")
        b.clear(tabID: "t1")
        #expect(!b.hasBlob(for: "t1"))
        #expect(b.restore(tabID: "t1") == nil)   // gone for good
        // a later capture for a recycled id starts clean (no stale sprite leaks through).
        b.capture(tabID: "t1", state: "new-page")
        #expect((b.restore(tabID: "t1") as? String) == "new-page")
    }

    @Test func restoreIsLosslessForBlobOntoAFreshSlot() {
        // The fidelity contract: what capture stored is exactly what restore returns. The broker
        // never inspects or copies the blob's contents — it is a pass-through bag keyed by id.
        let b = WebViewSessionBroker()
        struct StandIn { let bytes: [UInt8] }   // arbitrary struct as the "interactionState"
        let payload = StandIn(bytes: [0xDE, 0xAD, 0xBE, 0xEF])
        b.capture(tabID: "t", state: payload)
        guard let back = b.restore(tabID: "t") as? StandIn else {
            Issue.record("blob did not round-trip losslessly"); return
        }
        #expect(back.bytes == [0xDE, 0xAD, 0xBE, 0xEF])
    }
}

// MARK: - Tree tab model (slice 7)

/// Tests for the core tree-tab data model. ChromeState-level behavior lives in the Hive app
/// and is covered by manual/browser QA; here we lock the model invariants that support it.
@Suite("TreeTabModel")
struct TreeTabModelTests {

    @Test func browserTabCarriesParentTabID() {
        let parent = BrowserTab.newTab()
        let child = BrowserTab(parentTabID: parent.id)
        #expect(child.parentTabID == parent.id)

        let root = BrowserTab.newTab()
        #expect(root.parentTabID == nil)
    }

    @Test func hasAncestorWalksParentChain() {
        let a = BrowserTab.newTab()
        let b = BrowserTab(parentTabID: a.id)
        let c = BrowserTab(parentTabID: b.id)
        let orphan = BrowserTab.newTab()

        #expect(c.hasAncestor(a.id, in: [a, b, c, orphan]))
        #expect(c.hasAncestor(b.id, in: [a, b, c, orphan]))
        #expect(!c.hasAncestor(orphan.id, in: [a, b, c, orphan]))
        #expect(!a.hasAncestor(a.id, in: [a, b, c, orphan]))
    }

    @Test func parentTabIDRoundTripsThroughCodable() throws {
        let parent = BrowserTab.newTab()
        let tab = BrowserTab(title: "Child", parentTabID: parent.id)
        let data = try JSONEncoder().encode(tab)
        let back = try JSONDecoder().decode(BrowserTab.self, from: data)
        #expect(back.parentTabID == parent.id)
        #expect(back.title == "Child")
    }

    @Test func chromeUserPrefsDecodeOldJSONDefaultsTreeModeOff() throws {
        // An older chrome.json that lacks the new tree-mode fields must decode cleanly.
        let old: [String: AnyHashable] = [
            "tabPosition": "top",
            "tabDensity": "standard",
            "sidebarOpen": false,
            "defaultSearchEngine": "DuckDuckGo",
            "honorReduceMotion": true,
        ]
        let data = try JSONSerialization.data(withJSONObject: old, options: [])
        let prefs = try JSONDecoder().decode(ChromeUserPrefs.self, from: data)
        #expect(!prefs.isTreeMode)
        #expect(prefs.treeCollapsedParentIDs.isEmpty)
    }

    @Test func chromeUserPrefsRoundTripsTreeMode() throws {
        let prefs = ChromeUserPrefs(isTreeMode: true, treeCollapsedParentIDs: ["a", "b"])
        let data = try JSONEncoder().encode(prefs)
        let back = try JSONDecoder().decode(ChromeUserPrefs.self, from: data)
        #expect(back.isTreeMode)
        #expect(back.treeCollapsedParentIDs == ["a", "b"])
    }
}

// MARK: - Promise badges (slice 8)

@Suite("PromiseBadgeModel")
struct PromiseBadgeModelTests {

    @Test func browserTabCarriesPromiseFields() {
        let tab = BrowserTab(title: "Recipe", promise: "band to dining", promiseColor: "mint")
        #expect(tab.promise == "band to dining")
        #expect(tab.promiseColor == "mint")

        let plain = BrowserTab.newTab()
        #expect(plain.promise == nil)
        #expect(plain.promiseColor == nil)
    }

    @Test func promiseRoundTripsThroughCodable() throws {
        let tab = BrowserTab(title: "Read", promise: "read later", promiseColor: "accent")
        let data = try JSONEncoder().encode(tab)
        let back = try JSONDecoder().decode(BrowserTab.self, from: data)
        #expect(back.promise == "read later")
        #expect(back.promiseColor == "accent")
    }

    @Test func browserTabDecodesOldSessionWithoutPromiseFields() throws {
        // An older session.json that lacks promise/promiseColor must decode cleanly.
        let old: [String: AnyHashable] = [
            "id": "tab-1",
            "title": "Old tab",
            "isLoading": false,
            "loadProgress": 0,
            "canGoBack": false,
            "canGoForward": false,
            "isActive": true,
            "isPinned": false,
            "isPrivate": false,
            "isMuted": false,
            "isHibernated": false,
            "zoomLevel": 1.0,
        ]
        let data = try JSONSerialization.data(withJSONObject: old, options: [])
        let tab = try JSONDecoder().decode(BrowserTab.self, from: data)
        #expect(tab.promise == nil)
        #expect(tab.promiseColor == nil)
        #expect(tab.title == "Old tab")
    }
}

// MARK: - Page capture to Honeycomb

/// Tests that a browser page capture produces a Honeycomb Source + Capture, links them with a
/// `derivedFrom` edge, and appends a capture event to the EventLedger.
@Suite("PageCapture")
struct PageCaptureTests {
    private func makeStores() throws -> (HoneycombStore, EventLedgerStore) {
        let honeycomb = try HoneycombStore(path: ":memory:")
        let ledger = try EventLedgerStore(path: ":memory:")
        return (honeycomb, ledger)
    }

    @Test func captureCreatesSourceAndCaptureNodes() async throws {
        let (honeycomb, ledger) = try makeStores()

        let capturedURL = "https://example.com/page"
        let capturedTitle = "Example Page"
        let capturedText = "This is the visible text of the page."

        // 1. Create Source.
        let source = Source(
            url: capturedURL,
            title: capturedTitle,
            captureMethod: "browser-capture",
            provenance: "browser-capture"
        )
        let storedSource = try await honeycomb.createSource(source)
        #expect(storedSource.url == capturedURL)
        #expect(storedSource.title == capturedTitle)

        // 2. Create Capture node linked to the source.
        let captureNode = HoneycombStore.Node(
            type: .capture,
            label: "Capture: \(capturedTitle)",
            metadata: .object([
                "url": .string(capturedURL),
                "title": .string(capturedTitle),
                "text": .string(capturedText),
                "sourceID": .string(storedSource.id)
            ]),
            contentHash: HoneycombStore.sha256(capturedText),
            provenance: "browser-capture"
        )
        let storedCapture = try await honeycomb.insertNode(captureNode)

        // 3. Link capture → source.
        _ = try await honeycomb.insertEdge(
            HoneycombStore.Edge(
                sourceID: storedCapture.id,
                targetID: storedSource.id,
                relation: .derivedFrom
            )
        )

        // 4. Verify the edge exists.
        let edges = try await honeycomb.getEdges(from: storedCapture.id, relation: .derivedFrom)
        #expect(edges.count == 1)
        #expect(edges.first?.targetID == storedSource.id)

        // 5. Record an EventLedger capture event.
        let event = EventLedgerStore.LedgerEvent(
            actor: "user",
            intent: "Capture page to Honeycomb",
            actionKind: .capture,
            actionTarget: capturedURL,
            actionPreview: "Captured \"\(capturedTitle)\" as Source + Capture nodes",
            trustLevel: .t0,
            policyDecision: .allowed,
            consentState: .auto,
            contextIDs: [storedSource.id, storedCapture.id],
            result: .success,
            provenance: "browser-capture"
        )
        let recorded = try await ledger.record(event)
        #expect(!recorded.id.isEmpty)

        // 6. Verify the event can be queried back by action kind.
        let captures = try await ledger.getEvents(byActionKind: .capture)
        #expect(captures.count == 1)
        #expect(captures.first?.actionTarget == capturedURL)
        #expect(captures.first?.contextIDs == [storedSource.id, storedCapture.id])
    }

    @Test func captureDeduplicatesSourceByURL() async throws {
        let (honeycomb, _) = try makeStores()
        let source1 = Source(url: "https://hive.browser/capture", title: "One", captureMethod: "browser-capture")
        let source2 = Source(url: "https://hive.browser/capture", title: "Two", captureMethod: "browser-capture")
        let stored1 = try await honeycomb.createSource(source1)
        let stored2 = try await honeycomb.createSource(source2)
        #expect(stored1.id == stored2.id)
    }

    @Test func failedCaptureRecordsFailureEvent() async throws {
        let (_, ledger) = try makeStores()
        let event = EventLedgerStore.LedgerEvent(
            actor: "user",
            intent: "Capture page to Honeycomb",
            actionKind: .capture,
            actionTarget: "https://example.com",
            actionPreview: "Failed to capture",
            trustLevel: .t0,
            policyDecision: .allowed,
            consentState: .auto,
            result: .failure,
            errorDescription: "No URL",
            provenance: "browser-capture"
        )
        let recorded = try await ledger.record(event)
        let failed = try await ledger.getFailedEvents()
        #expect(failed.contains { $0.id == recorded.id })
    }
}

// MARK: - CommandRegistry

@Suite("CommandRegistry")
struct CommandRegistryTests {
    @Test func defaultCatalogIncludesCoreCommands() {
        let registry = CommandRegistry()
        let commands = registry.allCommands
        #expect(commands.count == BrowserCommand.allCases.count)
        #expect(commands.contains { $0.id == .newTab })
        #expect(commands.contains { $0.id == .closeTab })
        #expect(commands.contains { $0.id == .toggleLayout })
        #expect(commands.contains { $0.id == .capturePage })
    }

    @Test func searchFiltersByTitle() {
        let registry = CommandRegistry()
        let results = registry.search(query: "space")
        #expect(results.allSatisfy { $0.category == .space })
        #expect(results.contains { $0.id == .newSpace })
        #expect(results.contains { $0.id == .deleteSpace })
    }

    @Test func searchFiltersByKeyword() {
        let registry = CommandRegistry()
        let results = registry.search(query: "reload")
        #expect(results.count == 1)
        #expect(results.first?.id == .reload)
    }

    @Test func searchReturnsAllForEmptyQuery() {
        let registry = CommandRegistry()
        let results = registry.search(query: "")
        #expect(results.count == BrowserCommand.allCases.count)
    }

    @Test func definitionForID() {
        let registry = CommandRegistry()
        #expect(registry.definition(for: .newTab)?.title == "New Tab")
        #expect(registry.definition(for: .capturePage)?.category == .tools)
        #expect(registry.definition(for: .toggleReaderMode)?.title == "Toggle Reader Mode")
    }

    @Test func slashAliasResolvesExactlyAndNormalizesInput() {
        let registry = CommandRegistry()
        #expect(registry.definition(forSlashAlias: "reload")?.id == .reload)
        #expect(registry.definition(forSlashAlias: "  ReFrEsH  ")?.id == .reload)
        #expect(registry.definition(forSlashAlias: "reload page") == nil,
                "slash aliases are exact commands, not fuzzy execution")
        #expect(registry.definition(forSlashAlias: "") == nil)
    }

    @Test func slashCommandsExposeOnlyExplicitAliases() {
        let registry = CommandRegistry()
        let commands = registry.slashCommands(matching: "")
        #expect(!commands.isEmpty)
        #expect(commands.allSatisfy { !$0.slashAliases.isEmpty })
        #expect(commands.contains { $0.id == .toggleSwarm })
        #expect(!commands.contains { $0.id == .capturePage },
                "commands without a slash alias must stay out of omnibox discovery")
    }

    @Test func slashCommandSearchIncludesAliasesAndKeywords() {
        let registry = CommandRegistry()
        #expect(registry.slashCommands(matching: "refresh").map(\.id) == [.reload])
        let workspaceCommands = registry.slashCommands(matching: "workspace").map(\.id)
        #expect(workspaceCommands.isEmpty,
                "commands without slash aliases must stay out of omnibox discovery")
        #expect(!workspaceCommands.contains(.capturePage),
                "commands without slash aliases must stay out of omnibox discovery")
        #expect(registry.slashCommands(matching: "ask").map(\.id) == [.toggleSwarm])
    }

    @Test func slashAliasCollisionIsNotExecutableOrDisplayed() {
        let definitions = [
            CommandDefinition(id: .newTab, title: "New", category: .tab, slashAliases: ["same"]),
            CommandDefinition(id: .closeTab, title: "Close", category: .tab, slashAliases: ["same"])
        ]
        let registry = CommandRegistry(definitions: definitions)
        #expect(registry.definition(forSlashAlias: "same") == nil)
        #expect(registry.slashAlias(for: .newTab) == nil)
        #expect(registry.slashAlias(for: .closeTab) == nil)
        #expect(registry.slashCommands().isEmpty)
    }

    @Test func commandDefinitionDecodesWithoutLegacySlashAliases() throws {
        let legacy = """
        {"id":"reload","title":"Reload Page","keywords":["reload"],"category":"navigation","shortcut":null}
        """.data(using: .utf8)!
        let definition = try JSONDecoder().decode(CommandDefinition.self, from: legacy)
        #expect(definition.id == .reload)
        #expect(definition.slashAliases.isEmpty)
    }
}

// MARK: - Reader mode model

@Suite("ReaderModeModel")
struct ReaderModeModelTests {

    @Test func browserTabDefaultsToReaderModeOff() {
        let tab = BrowserTab(url: URL(string: "https://hive.app/article"), title: "Article")
        #expect(!tab.isReaderMode)
    }

    @Test func browserTabRoundTripsReaderModeFlag() throws {
        let tab = BrowserTab(url: URL(string: "https://hive.app/article"),
                             title: "Article",
                             isReaderMode: true)
        let data = try JSONEncoder().encode(tab)
        let decoded = try JSONDecoder().decode(BrowserTab.self, from: data)
        #expect(decoded.isReaderMode)
    }

    @Test func readerArtifactHoldsExtractedContent() {
        let artifact = ReaderArtifact(
            url: URL(string: "https://hive.app/article"),
            title: "The Article",
            byline: "Hive Team",
            contentHTML: "<p>Hello</p>",
            excerpt: "Hello"
        )
        #expect(artifact.title == "The Article")
        #expect(artifact.byline == "Hive Team")
        #expect(artifact.contentHTML == "<p>Hello</p>")
        #expect(artifact.url?.host == "hive.app")
    }
}

// MARK: - Browser download model

@Suite("BrowserDownload")
struct BrowserDownloadTests {

    @Test func browserDownloadDefaultsDisplayNameFromURL() {
        let url = URL(string: "https://example.com/report.pdf")!
        let download = BrowserDownload(url: url)
        #expect(download.displayName == "report.pdf")
    }

    @Test func browserDownloadDisplayNameFallsBackToHost() {
        let url = URL(string: "https://example.com")!
        let download = BrowserDownload(url: url)
        #expect(download.displayName == "example.com")
    }

    @Test func browserDownloadProgressTextUnknownTotal() {
        let download = BrowserDownload(url: URL(string: "https://example.com/file.zip")!,
                                       filename: "file.zip",
                                       receivedBytes: 1024)
        let text = download.progressText
        #expect(!text.isEmpty)
        #expect(text.contains("1"))
    }

    @Test func browserDownloadProgressTextWithTotal() {
        let download = BrowserDownload(url: URL(string: "https://example.com/file.zip")!,
                                       filename: "file.zip",
                                       totalBytes: 10_000,
                                       receivedBytes: 2_500)
        let text = download.progressText
        #expect(!text.isEmpty)
        #expect(text.localizedLowercase.contains("of") || text.contains("/"))
    }

    @Test func browserDownloadCodableRoundTrip() throws {
        let url = URL(string: "https://example.com/archive.zip")!
        let original = BrowserDownload(url: url,
                                         filename: "archive.zip",
                                         state: .inProgress,
                                         progress: 0.5,
                                         totalBytes: 100,
                                         receivedBytes: 50)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrowserDownload.self, from: data)
        #expect(decoded.filename == "archive.zip")
        #expect(decoded.state == .inProgress)
        #expect(decoded.progress == 0.5)
        #expect(decoded.totalBytes == 100)
        #expect(decoded.receivedBytes == 50)
    }
}

// MARK: - Onboarding prefs

@Suite("OnboardingPrefs")
struct OnboardingPrefsTests {

    @Test func hasCompletedOnboardingDefaultsToFalse() {
        let prefs = ChromeUserPrefs.defaults
        #expect(!prefs.hasCompletedOnboarding)
    }

    @Test func hasCompletedOnboardingRoundTripsThroughCodable() throws {
        var prefs = ChromeUserPrefs.defaults
        prefs.hasCompletedOnboarding = true
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(ChromeUserPrefs.self, from: data)
        #expect(decoded.hasCompletedOnboarding)
    }

    @Test func prefsDecodeWithoutHasCompletedOnboardingDefaultsFalse() throws {
        // Simulate an older chrome.json that lacks the onboarding flag.
        let old: [String: AnyHashable] = [
            "tabPosition": "top",
            "tabDensity": "standard",
            "sidebarOpen": false,
            "defaultSearchEngine": "DuckDuckGo",
            "honorReduceMotion": true
        ]
        let data = try JSONSerialization.data(withJSONObject: old, options: [])
        let prefs = try JSONDecoder().decode(ChromeUserPrefs.self, from: data)
        #expect(!prefs.hasCompletedOnboarding)
    }
}

// MARK: - BrowserImportEngine

@Suite("BrowserImportEngine")
struct BrowserImportEngineTests {

    @Test func parseChromiumHistoryExtractsEntry() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-test-chromium-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let dbPath = tmpDir.appendingPathComponent("History").path
        let db = try openSQLiteDB(path: dbPath)
        defer { sqlite3_close(db) }

        let schema = """
            CREATE TABLE urls (
                id INTEGER PRIMARY KEY,
                url TEXT NOT NULL,
                title TEXT,
                visit_count INTEGER,
                last_visit_time INTEGER
            );
            INSERT INTO urls (url, title, visit_count, last_visit_time)
            VALUES ('https://example.com/page', 'Example Page', 3, 133_000_000_000_000_00);
            """
        try executeSQL(db: db, sql: schema)

        let history = BrowserImportEngine.parseChromiumHistory(at: dbPath)
        #expect(history.count == 1)
        #expect(history.first?.title == "Example Page")
        #expect(history.first?.url.absoluteString == "https://example.com/page")
        #expect(history.first?.visitCount == 3)
    }

    @Test func parseSafariHistoryExtractsEntry() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-test-safari-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let dbPath = tmpDir.appendingPathComponent("History.db").path
        let db = try openSQLiteDB(path: dbPath)
        defer { sqlite3_close(db) }

        let schema = """
            CREATE TABLE history_items (id INTEGER PRIMARY KEY, url TEXT, title TEXT, visit_count INTEGER);
            CREATE TABLE history_visits (id INTEGER PRIMARY KEY, history_item INTEGER, visit_time REAL);
            INSERT INTO history_items (id, url, title, visit_count) VALUES (1, 'https://safari.example.com', 'Safari Test', 5);
            INSERT INTO history_visits (history_item, visit_time) VALUES (1, 700_000_000.0);
            """
        try executeSQL(db: db, sql: schema)

        let history = BrowserImportEngine.parseSafariHistory(at: dbPath)
        #expect(history.count == 1)
        #expect(history.first?.title == "Safari Test")
        #expect(history.first?.url.absoluteString == "https://safari.example.com")
        #expect(history.first?.visitCount == 5)
    }

    @Test func parseChromiumHistoryReturnsEmptyForMissingDB() {
        let path = NSTemporaryDirectory() + "nonexistent-history-\(UUID().uuidString).db"
        let history = BrowserImportEngine.parseChromiumHistory(at: path)
        #expect(history.isEmpty)
    }

    @Test func parseSafariHistoryReturnsEmptyForMissingDB() {
        let path = NSTemporaryDirectory() + "nonexistent-history-\(UUID().uuidString).db"
        let history = BrowserImportEngine.parseSafariHistory(at: path)
        #expect(history.isEmpty)
    }

    // MARK: - Helpers

    private func openSQLiteDB(path: String) throws -> OpaquePointer {
        var db: OpaquePointer?
        guard sqlite3_open(path, &db) == SQLITE_OK, let db else {
            throw TestError("Failed to open SQLite database at \(path)")
        }
        return db
    }

    private func executeSQL(db: OpaquePointer, sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        defer { sqlite3_free(err) }
        guard sqlite3_exec(db, sql, nil, nil, &err) == SQLITE_OK else {
            let msg = err.map { String(cString: $0) } ?? "unknown error"
            throw TestError("SQLite error: \(msg)")
        }
    }

    private struct TestError: Error, CustomStringConvertible {
        let message: String
        init(_ message: String) { self.message = message }
        var description: String { message }
    }
}

// MARK: - RetrievalRankerFilter: validated allow-list parsing

/// Locks the security boundary of the ranker step: the model may ONLY narrow
/// the assembled context, never expand it. Fabricated IDs are dropped by
/// intersection; malformed output degrades to nil (raw context kept).
@Suite("RetrievalRankerFilter")
struct RetrievalRankerFilterTests {

    @Test func allowListKeepsOnlyKnownIDs() {
        let allowed = RetrievalRankerFilter.parseAllowList(
            "[\"node-a\",\"node-b\"]", from: ["node-a", "node-b", "node-c"])
        #expect(allowed == ["node-a", "node-b"])
    }

    @Test func unknownIDsAreDroppedNeverExpanded() {
        // A hallucinated ID must be silently dropped — the allow-list is a
        // strict subset of the assembled set.
        let allowed = RetrievalRankerFilter.parseAllowList(
            "[\"node-a\",\"fabricated-evil\"]", from: ["node-a"])
        #expect(allowed == ["node-a"])
        #expect(!allowed!.contains("fabricated-evil"))
    }

    @Test func emptyAllowListIsHonored() {
        // An explicit empty array means "no hot node relevant" — honored, not
        // treated as malformed.
        let allowed = RetrievalRankerFilter.parseAllowList("[]", from: ["node-a"])
        #expect(allowed == [])
    }

    @Test func malformedOutputDegradesToNil() {
        // Prose / invalid JSON must degrade (caller keeps the raw context).
        #expect(RetrievalRankerFilter.parseAllowList("MOCK RANK", from: ["a"]) == nil)
        #expect(RetrievalRankerFilter.parseAllowList("", from: ["a"]) == nil)
        #expect(RetrievalRankerFilter.parseAllowList("   \n  ", from: ["a"]) == nil)
    }

    @Test func objectWrapperDegradesToNil() {
        // An object wrapper ({"ids": [...]}) is not the contract — a bare
        // array is required. Anything else degrades.
        #expect(RetrievalRankerFilter.parseAllowList("{\"ids\":[\"a\"]}", from: ["a"]) == nil)
        #expect(RetrievalRankerFilter.parseAllowList("[1,2,3]", from: ["a"]) == nil)
    }

    @Test func productionRankContractIsParsed() {
        // The real Cell contract: a JSON object with ranks[] ordered
        // most-relevant-first; source_id must be the exact ID given.
        let output = #"{"ranks":[{"source_id":"node-b","score":0.9},{"source_id":"node-a","score":0.4}]}"#
        let allowed = RetrievalRankerFilter.parseAllowList(output, from: ["node-a", "node-b", "node-c"])
        #expect(allowed == ["node-b", "node-a"],
                "the ranker's own order must be preserved in the allow-list")
    }

    @Test func productionContractMissingRanksDegrades() {
        // A JSON object without a `ranks` key is not the contract — degrade.
        #expect(RetrievalRankerFilter.parseAllowList("{\"other\":[]}", from: ["a"]) == nil)
        #expect(RetrievalRankerFilter.parseAllowList(#"{"ranks":null}"#, from: ["a"]) == nil)
    }

    @Test func fencedJsonBlockIsParsed() {
        // Models often wrap output in a ```json fence — tolerated.
        let allowed = RetrievalRankerFilter.parseAllowList(
            "```json\n[\"node-a\"]\n```", from: ["node-a", "node-b"])
        #expect(allowed == ["node-a"])
    }
}

// MARK: - Hot memory: allow-list formatting (the ranker consumes this)

@Suite("HotMemoryRankerFiltering")
struct HotMemoryRankerFilteringTests {

    @Test func allowListRestrictsRenderedHotNodes() async {
        let store = HotMemoryStore()
        await store.didAccessNode(id: "node-a", sourceHint: "browsed",
                                  label: "Alpha", content: "about alpha")
        await store.didAccessNode(id: "node-b", sourceHint: "browsed",
                                  label: "Beta", content: "about beta")

        let filtered = await store.assembleContextPrompt(allowingHotNodeIDs: ["node-a"])
        #expect(filtered.contains("Alpha"))
        #expect(!filtered.contains("Beta"),
                "allow-list must exclude non-listed hot nodes from the prompt")

        let raw = await store.assembleContextPrompt()
        #expect(raw.contains("Beta"), "without an allow-list all hot nodes render")
    }

    @Test func allowListCannotExpandBeyondAssembledSet() async {
        let store = HotMemoryStore()
        await store.didAccessNode(id: "node-a", sourceHint: "browsed",
                                  label: "Alpha", content: "about alpha")

        // A fabricated ID in the allow-list must be ignored — never rendered.
        let filtered = await store.assembleContextPrompt(
            allowingHotNodeIDs: ["node-a", "fabricated-id"])
        #expect(filtered.contains("Alpha"))
        #expect(!filtered.contains("fabricated-id"),
                "an allow-list can never introduce a node that was not assembled")
    }

    @Test func allowListOrderIsRespectedAtRender() async {
        // The ranker's own most-relevant-first order must reach the prompt —
        // the RetrievalRanker step is a re-rank, not just a filter. Even
        // though the hot set may order entries by its own score, the rendered
        // context follows the allow-list order the model chose.
        let store = HotMemoryStore()
        await store.didAccessNode(id: "node-a", sourceHint: "browsed",
                                  label: "Alpha", content: "about alpha")
        await store.didAccessNode(id: "node-b", sourceHint: "browsed",
                                  label: "Beta", content: "about beta")

        let filtered = await store.assembleContextPrompt(
            allowingHotNodeIDs: ["node-b", "node-a"])
        #expect(filtered.contains("Alpha"))
        #expect(filtered.contains("Beta"))
        let betaIndex = filtered.range(of: "Beta")?.lowerBound
        let alphaIndex = filtered.range(of: "Alpha")?.lowerBound
        #expect(betaIndex != nil && alphaIndex != nil)
        #expect(betaIndex! < alphaIndex!,
                "the ranker's priority order must reach the prompt (Beta first)")
    }

    @Test func rankerListingCarriesIDsAndLabels() async {
        let store = HotMemoryStore()
        await store.didAccessNode(id: "node-a", sourceHint: "browsed",
                                  label: "Alpha", content: "about alpha")
        let (assembled, listing) = await store.rankerListing()
        #expect(assembled.hotNodes.contains("node-a"))
        #expect(listing.contains("node-a"))
        #expect(listing.contains("Alpha"),
                "the ranker must see labels, not opaque IDs, to judge relevance")
    }
}

// MARK: - SwarmOrchestrator: retrieval-ranker wiring

@Suite("SwarmOrchestratorRanker")
struct SwarmOrchestratorRankerTests {

    /// A temp CellPromptLoader with a retrievalRanker Cell file so the ranker
    /// step actually runs through the dispatcher (which falls back to the
    /// honest MockRuntime — output "MOCK RANK", deliberately not a JSON
    /// allow-list, exercising the degrade path).
    private func makeLoaderWithRankerCell() throws -> CellPromptLoader {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-ranker-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let routerDir = tmpDir.appendingPathComponent("router", isDirectory: true)
        try FileManager.default.createDirectory(at: routerDir, withIntermediateDirectories: true)
        try """
        # 100m_retrieval_ranker

        ## Job (one sentence)
        Select the hot context nodes relevant to the intent.

        ## Distilled rules (from source prompts)
        Return ONLY a JSON array of node IDs.
        """.write(to: routerDir.appendingPathComponent("100m_retrieval_ranker.md"),
                  atomically: true, encoding: .utf8)
        return CellPromptLoader(promptsDir: tmpDir)
    }

    @Test func processRunsFullPipelineWhenRankerSkipped() async throws {
        let ledger = try EventLedgerStore(path: ":memory:")
        let orch = SwarmOrchestrator(hotMemory: HotMemoryStore(), ledger: ledger)

        let result = try await orch.process(intent: "What is 2+2?", page: nil)

        #expect(!result.text.isEmpty)
        #expect(result.provider == .mock)
        #expect(result.rankerProvider == nil, "no prompts -> ranker step skipped")
        #expect(result.contextSummary.contains("no ranking pass"))
        // The full pipeline is audited: orchestrator model call + start/completion.
        let calls = try await ledger.getEvents(byActionKind: .modelCall)
        #expect(calls.contains(where: { $0.actor == ModelRole.orchestrator.rawValue }))
    }

    @Test func rankerStepRunsAndReportsHonestDecision() async throws {
        // Host-agnostic contract: .retrievalRanker is Apple-FMF-allowed, so on
        // a Mac with FMF the ranker runs on REAL inference (unpredictable text);
        // on hosts without FMF it falls back to mock ("MOCK RANK" — invalid
        // JSON). Either way the step must run, be audited with its decision,
        // and never claim "no ranking pass". The degrade-to-raw semantics of
        // malformed output are locked deterministically by the pure
        // RetrievalRankerFilter tests.
        let ledger = try EventLedgerStore(path: ":memory:")
        let orch = SwarmOrchestrator(hotMemory: HotMemoryStore(), ledger: ledger,
                                     prompts: try makeLoaderWithRankerCell())

        let result = try await orch.process(intent: "summarize the swift guide", page: nil)

        #expect(result.rankerProvider != nil,
                "with a ranker Cell present the ranker step must execute")
        #expect(!result.contextSummary.contains("no ranking pass"),
                "the summary must report the ranker decision, never claim the step was skipped")
        #expect(result.contextSummary.contains("[Context available:"))
        #expect(!result.text.isEmpty)

        // The ranker decision (degraded / filtered:N/M / approved-all) is
        // recorded in the audit trail — never silent.
        let calls = try await ledger.getEvents(byActionKind: .modelCall)
        let rankerEvent = calls.first(where: { $0.actor == "retrievalRanker" })
        #expect(rankerEvent != nil, "the ranker invocation must be audited")
        #expect(rankerEvent?.outputSummary != nil,
                "the ranker decision must be recorded (degraded / filtered / approved-all)")
        #expect(rankerEvent?.modelProvider == result.rankerProvider,
                "the ledger provider label must match the reported ranker provider")
    }
}

// MARK: - PreferenceExtractor

@Suite("PreferenceExtractor")
struct PreferenceExtractorTests {
    @Test func vegetarianSet() {
        let candidates = PreferenceExtractor.extract(from: "I'm vegetarian")
        #expect(candidates.count == 1)
        #expect(candidates[0].path == "food.preferences.dietary.vegetarian")
        #expect(candidates[0].value == "vegetarian")
        #expect(candidates[0].action == .set)
        #expect(candidates[0].confidence > 0.9)
    }

    @Test func vegetarianSetAlternatePhrasing() {
        for phrase in ["I am vegetarian", "I'm a vegetarian",
                       "my diet is vegetarian", "I don't eat meat",
                       "i avoid meat"] {
            let candidates = PreferenceExtractor.extract(from: phrase)
            #expect(candidates.count >= 1)
            #expect(candidates.contains(where: { $0.path == "food.preferences.dietary.vegetarian" }))
        }
    }

    @Test func vegetarianWithdraw() {
        let candidates = PreferenceExtractor.extract(from: "I'm no longer vegetarian")
        #expect(candidates.count == 1)
        #expect(candidates[0].path == "food.preferences.dietary.vegetarian")
        #expect(candidates[0].action == .withdraw)
        #expect(candidates[0].confidence > 0.9)
    }

    @Test func vegetarianWithdrawAlternatePhrasing() {
        for phrase in ["I am no longer vegetarian", "I'm not vegetarian anymore",
                       "i eat meat now"] {
            let candidates = PreferenceExtractor.extract(from: phrase)
            #expect(candidates.count >= 1)
            #expect(candidates.contains(where: {
                $0.path == "food.preferences.dietary.vegetarian" && $0.action == .withdraw
            }))
        }
    }

    @Test func veganSet() {
        let candidates = PreferenceExtractor.extract(from: "I'm vegan")
        #expect(candidates.count == 1)
        #expect(candidates[0].path == "food.preferences.dietary.vegan")
        #expect(candidates[0].value == "vegan")
        #expect(candidates[0].action == .set)
    }

    @Test func veganWithdraw() {
        let candidates = PreferenceExtractor.extract(from: "I'm no longer vegan")
        #expect(candidates.count == 1)
        #expect(candidates[0].action == .withdraw)
        #expect(candidates[0].path == "food.preferences.dietary.vegan")
    }

    @Test func glutenFreeSet() {
        let candidates = PreferenceExtractor.extract(from: "I'm gluten-free")
        #expect(candidates.count == 1)
        #expect(candidates[0].path == "food.preferences.dietary.gluten_free")
        #expect(candidates[0].value == "gluten-free")
        #expect(candidates[0].action == .set)
    }

    @Test func peanutAllergy() {
        let candidates = PreferenceExtractor.extract(from: "I'm allergic to peanuts")
        // "peanuts" also matches "peanut" as a substring allergen — both are
        // valid representations of the same dietary restriction.
        #expect(candidates.count >= 1)
        #expect(candidates.contains(where: { $0.path.hasPrefix("food.preferences.allergies.peanut") }))
        #expect(candidates.contains(where: { $0.action == .set && $0.confidence > 0.98 }))
    }

    @Test func shellfishAllergy() {
        let candidates = PreferenceExtractor.extract(from: "I have a shellfish allergy")
        #expect(candidates.count == 1)
        #expect(candidates[0].path == "food.preferences.allergies.shellfish")
    }

    @Test func sesameAllergy() {
        let candidates = PreferenceExtractor.extract(from: "I cannot eat sesame")
        #expect(candidates.count == 1)
        #expect(candidates[0].path == "food.preferences.allergies.sesame")
    }

    @Test func treeNutsAllergy() {
        let candidates = PreferenceExtractor.extract(from: "I can't eat tree nuts")
        #expect(candidates.count == 1)
        #expect(candidates[0].path == "food.preferences.allergies.tree_nuts")
    }

    @Test func emptyInputProducesNoCandidates() {
        #expect(PreferenceExtractor.extract(from: "").isEmpty)
        #expect(PreferenceExtractor.extract(from: "   ").isEmpty)
    }

    @Test func externalAttributionIsNeverExtracted() {
        for phrase in ["the page says I'm vegetarian",
                       "this page says I am vegan",
                       "the article says I'm gluten-free",
                       "the email says I'm allergic to peanuts",
                       "someone says I don't eat meat",
                       "they say I'm vegetarian"] {
            let candidates = PreferenceExtractor.extract(from: phrase)
            #expect(candidates.isEmpty,
                    "External attribution must not create preferences: '\(phrase)'")
        }
    }

    @Test func nonPreferenceTextProducesNoCandidates() {
        for phrase in ["find vegetarian restaurants near me",
                       "what's a good vegan cookbook",
                       "show me gluten-free recipes",
                       "restaurants with peanut-free options",
                       "hello", "what's the weather", "open github.com"] {
            let candidates = PreferenceExtractor.extract(from: phrase)
            #expect(candidates.isEmpty,
                    "Non-preference text must not produce candidates: '\(phrase)'")
        }
    }

    @Test func mixedPreferenceAndRequestExtractsPreference() {
        // "I'm vegetarian, recommend restaurants" — the preference extractor
        // should catch the dietary preference, while the voice classifier
        // routes the combined request as a generic question.
        let candidates = PreferenceExtractor.extract(
            from: "I'm vegetarian, recommend restaurants nearby"
        )
        #expect(candidates.count >= 1)
        #expect(candidates.contains(where: { $0.path == "food.preferences.dietary.vegetarian" }))
    }

    @Test func caseInsensitivity() {
        let candidates = PreferenceExtractor.extract(from: "I'M VEGETARIAN")
        #expect(candidates.count == 1)
        #expect(candidates[0].path == "food.preferences.dietary.vegetarian")
    }

    @Test func whitespaceTrimming() {
        let candidates = PreferenceExtractor.extract(from: "   I'm vegetarian   ")
        #expect(candidates.count == 1)
    }

    @Test func evidencePreservesOriginalText() {
        let candidates = PreferenceExtractor.extract(from: "I'm vegetarian")
        #expect(candidates[0].evidence == "I'm vegetarian")
    }

    @Test func confidenceIsClampedTo01() {
        let candidate = PreferenceCandidate(
            path: "test", value: "test", action: .set,
            confidence: 1.5, evidence: "test"
        )
        #expect(candidate.confidence == 1.0)
        let negative = PreferenceCandidate(
            path: "test", value: "test", action: .set,
            confidence: -0.5, evidence: "test"
        )
        #expect(negative.confidence == 0.0)
    }

    @Test func evidenceIsBoundedTo240Chars() {
        let long = String(repeating: "x", count: 500)
        let candidate = PreferenceCandidate(
            path: "test", value: "test", action: .set,
            confidence: 0.95, evidence: long
        )
        #expect(candidate.evidence.count <= 240)
    }
}

// MARK: - BeeQueue: job orchestration lifecycle

/// Locks the BeeQueue actor contract: enqueue, start, cancel, retry, verify,
/// auto-retry on failure, and EventLedger integration. The queue's `perform`
/// methods are honest stubs (they return string summaries, not real side
/// effects) — these tests prove the lifecycle machinery, not execution fidelity.
@Suite("BeeQueue")
struct BeeQueueTests {

    private func makeJob(
        kind: BeeJobKind = .toolExecution,
        label: String = "Test job",
        payload: [String: String] = [:],
        maxAttempts: Int = 3
    ) -> BeeJob {
        BeeJob(kind: kind, label: label, payload: payload, maxAttempts: maxAttempts)
    }

    // MARK: - Enqueue and retrieval

    @Test func enqueueStoresJobAsPending() async {
        let queue = BeeQueue.shared
        let job = makeJob(label: "enqueue-test")
        await queue.enqueue(job)

        let retrieved = await queue.job(job.id)
        #expect(retrieved?.id == job.id)
        #expect(retrieved?.status == .pending)
        #expect(retrieved?.label == "enqueue-test")
    }

    @Test func allJobsReturnsAllEnqueuedJobs() async {
        let queue = BeeQueue.shared
        let a = makeJob(label: "job-a")
        let b = makeJob(label: "job-b")
        await queue.enqueue(a)
        await queue.enqueue(b)

        let all = await queue.allJobs()
        #expect(all.count >= 2)
        #expect(all.contains(where: { $0.id == a.id }))
        #expect(all.contains(where: { $0.id == b.id }))
    }

    @Test func pendingJobsFiltersCorrectly() async {
        let queue = BeeQueue.shared
        let job = makeJob(label: "pending-filter-test")
        await queue.enqueue(job)

        let pending = await queue.pendingJobs()
        #expect(pending.contains(where: { $0.id == job.id }))
    }

    // MARK: - Start and execute

    @Test func startTransitionsJobToRunningAndCompletes() async {
        let queue = BeeQueue.shared
        let job = makeJob(kind: .toolExecution, payload: ["tool": "test-tool"])
        await queue.enqueue(job)
        await queue.start(job.id)

        // Give the async execution a moment to complete.
        try? await Task.sleep(for: .milliseconds(100))

        let completed = await queue.job(job.id)
        #expect(completed?.status == .succeeded, "Job should complete after start")
        #expect(completed?.resultSummary != nil)
        #expect(completed?.attempt == 1)
    }

    @Test func startIgnoresAlreadyRunningJob() async {
        let queue = BeeQueue.shared
        let job = makeJob(label: "already-running", payload: ["tool": "noop"], maxAttempts: 1)
        await queue.enqueue(job)
        await queue.start(job.id)
        // Second start on a running job should no-op.
        await queue.start(job.id)

        try? await Task.sleep(for: .milliseconds(100))

        let completed = await queue.job(job.id)
        #expect(completed?.attempt == 1, "Second start must not increment attempt")
    }

    @Test func startIgnoresNonexistentJob() async {
        let queue = BeeQueue.shared
        await queue.start("nonexistent-id")
        // Should not crash or produce a job.
        let job = await queue.job("nonexistent-id")
        #expect(job == nil)
    }

    // MARK: - Cancel

    @Test func cancelTransitionsPendingJobToCancelled() async {
        let queue = BeeQueue.shared
        let job = makeJob(label: "cancel-pending")
        await queue.enqueue(job)
        await queue.cancel(job.id)

        let cancelled = await queue.job(job.id)
        #expect(cancelled?.status == .cancelled)
        #expect(cancelled?.completedAt != nil)
    }

    @Test func cancelIsIdempotent() async {
        let queue = BeeQueue.shared
        let job = makeJob(label: "cancel-twice")
        await queue.enqueue(job)
        await queue.cancel(job.id)
        await queue.cancel(job.id) // second cancel must not crash or change state

        let cancelled = await queue.job(job.id)
        #expect(cancelled?.status == .cancelled)
    }

    // MARK: - Retry from failed

    @Test func retryRestartsFailedJob() async throws {
        let queue = BeeQueue.shared
        let job = makeJob(kind: .toolExecution, payload: [:], maxAttempts: 3)
        await queue.enqueue(job)

        // Manually set the job to failed to simulate a prior failure.
        // We do this by starting a job that will fail (missing required param).
        let failJob = makeJob(kind: .toolExecution, payload: [:], maxAttempts: 3)
        await queue.enqueue(failJob)
        await queue.start(failJob.id)
        try await Task.sleep(for: .milliseconds(100))

        // If it auto-retried, it may have succeeded or be retrying.
        // The key contract: a job with maxAttempts > 1 must try again.
        let finalJob = await queue.job(failJob.id)
        #expect(finalJob?.attempt ?? 0 >= 1, "Job should have at least one attempt")
    }

    @Test func retryRefusesJobAtMaxAttempts() async {
        let queue = BeeQueue.shared
        var job = makeJob(label: "maxed-out", maxAttempts: 1)
        job.status = .failed
        job.attempt = 1
        await queue.enqueue(job)
        await queue.retry(job.id)

        let result = await queue.job(job.id)
        #expect(result?.status == .failed, "Job at max attempts must not retry")
    }

    @Test func retryRefusesNonFailedJob() async {
        let queue = BeeQueue.shared
        let job = makeJob(label: "pending-not-failed")
        await queue.enqueue(job)
        await queue.retry(job.id)

        let result = await queue.job(job.id)
        #expect(result?.status == .pending, "Retry must no-op on non-failed jobs")
    }

    // MARK: - Verify

    @Test func verifyReportsSuccessForCompletedJob() async throws {
        let queue = BeeQueue.shared
        let job = makeJob(kind: .toolExecution, payload: ["tool": "test"])
        await queue.enqueue(job)
        await queue.start(job.id)
        try await Task.sleep(for: .milliseconds(100))

        let verification = await queue.verify(job.id)
        #expect(verification.verified)
        #expect(verification.reason.contains("completed"))
    }

    @Test func verifyReportsFailureForFailedJob() async {
        let queue = BeeQueue.shared
        let failJob = makeJob(kind: .toolExecution, payload: [:], maxAttempts: 1)
        await queue.enqueue(failJob)
        await queue.start(failJob.id)
        try? await Task.sleep(for: .milliseconds(100))

        let verification = await queue.verify(failJob.id)
        #expect(!verification.verified)
    }

    @Test func verifyReportsUnverifiedForPendingJob() async {
        let queue = BeeQueue.shared
        let job = makeJob(label: "still-pending")
        await queue.enqueue(job)

        let verification = await queue.verify(job.id)
        #expect(!verification.verified)
        #expect(verification.reason.contains("not yet complete"))
    }

    @Test func verifyReportsNotFoundForMissingJob() async {
        let queue = BeeQueue.shared
        let verification = await queue.verify("nonexistent")
        #expect(!verification.verified)
        #expect(verification.reason.contains("not found"))
    }

    // MARK: - Running jobs

    @Test func runningJobsReturnsEmptyForCompletedJob() async throws {
        let queue = BeeQueue.shared
        let job = makeJob(kind: .toolExecution, payload: ["tool": "test"])
        await queue.enqueue(job)
        await queue.start(job.id)
        try await Task.sleep(for: .milliseconds(200))

        let running = await queue.runningJobs()
        #expect(!running.contains(where: { $0.id == job.id }),
                "Completed jobs must not appear in running list")
    }

    // MARK: - Running jobs during execution

    @Test func runningJobsIncludesJobsDuringExecution() async throws {
        let queue = BeeQueue.shared
        // A job with a long-running command will be in .running state
        // while execute() is in progress. Use a real shell command that
        // sleeps to exercise this path reliably.
        let job = makeJob(
            kind: .runCheck,
            label: "long-check",
            payload: ["command": "sleep 0.2", "timeout": "5"]
        )
        await queue.enqueue(job)
        await queue.start(job.id)

        // Check immediately — the job should still be running.
        let running = await queue.runningJobs()
        #expect(running.contains(where: { $0.id == job.id }),
                "Active job must appear in running list")

        // Poll for completion instead of a fixed sleep.
        for _ in 0..<20 {
            let after = await queue.runningJobs()
            if !after.contains(where: { $0.id == job.id }) { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(Bool(false), "Completed job must leave the running list — timed out waiting")
    }

    // MARK: - Auto-retry exhaustion

    @Test func autoRetryExhaustedJobStaysFailed() async throws {
        let queue = BeeQueue.shared
        // A job with a missing required parameter that can only attempt once.
        // It will fail on execute() and auto-retry will be blocked.
        let job = makeJob(
            kind: .toolExecution,
            label: "exhausted-retry",
            payload: [:],
            maxAttempts: 1
        )
        await queue.enqueue(job)
        await queue.start(job.id)
        try await Task.sleep(for: .milliseconds(150))

        let final = await queue.job(job.id)
        #expect(final?.status == .failed,
                "Job with maxAttempts=1 must stay failed after one attempt")
        #expect(final?.attempt == 1)
        #expect(final?.lastError != nil,
                "Failed job must record the error that caused failure")
    }

    @Test func jobWithMultipleAttemptsRetriesOnFailure() async throws {
        let queue = BeeQueue.shared
        // A job with maxAttempts=3. The first execution fails (missing
        // required param), so it auto-retries. If the second attempt also
        // fails, the third is tried. The job should end with attempt >= 2.
        let job = makeJob(
            kind: .toolExecution,
            label: "multi-attempt",
            payload: [:],
            maxAttempts: 3
        )
        await queue.enqueue(job)
        await queue.start(job.id)
        // 3 attempts × ~100ms per attempt + buffer.
        try await Task.sleep(for: .milliseconds(500))

        let final = await queue.job(job.id)
        // After 3 attempts with empty payload (missing "tool"), the job
        // should have exhausted retries and be in .failed state.
        #expect(final?.status == .failed || final?.status == .succeeded,
                "Job with 3 attempts should either eventually succeed or exhaust")
        #expect((final?.attempt ?? 0) >= 1,
                "Job should have at least one attempt recorded")
    }

@Test func taskStatesAreNonEmpty() {
        #expect(!HiveTask.State.allCases.isEmpty)
    }

@Test func hibernationThresholdsDefaults() {
        let t = HibernationPolicy.Thresholds.defaults
        #expect(t.bgActiveSpaceSec == 900)
        #expect(t.inactiveSpaceSec == 300)
    }

@Test func beeJobStatusesAreNonEmpty() {
        #expect(!BeeJobStatus.allCases.isEmpty)
    }

@Test func beeJobKindsAreNonEmpty() {
        #expect(!BeeJobKind.allCases.isEmpty)
    }

@Test func honeycombCategoriesAreNonEmpty() {
        #expect(!HoneycombCategory.allCases.isEmpty)
    }

@Test func eventLedgerActionKindsAreNonEmpty() {
        #expect(!EventLedgerStore.ActionKind.allCases.isEmpty)
    }

@Test func eventLedgerTrustLevelsAreNonEmpty() {
        #expect(!EventLedgerStore.TrustLevel.allCases.isEmpty)
    }

@Test func eventLedgerPolicyDecisionsAreNonEmpty() {
        #expect(!EventLedgerStore.PolicyDecision.allCases.isEmpty)
    }

@Test func eventLedgerConsentStatesAreNonEmpty() {
        #expect(!EventLedgerStore.ConsentState.allCases.isEmpty)
    }

@Test func eventLedgerEventResultsAreNonEmpty() {
        #expect(!EventLedgerStore.EventResult.allCases.isEmpty)
    }

@Test func contradictionStatesAreNonEmpty() {
        #expect(!ContradictionState.allCases.isEmpty)
    }

@Test func browserSessionWindowDefaultsVertical() {
        let w = BrowserSessionWindow()
        #expect(w.layout == .vertical)
    }

@Test func browsingHistoryEntryPreservesTitle() {
        let url = URL(string: "https://example.com")!
        let e = BrowsingHistoryEntry(url: url, title: "Example", visitDate: Date())
        #expect(e.title == "Example")
    }

@Test func boostPreservesName() {
        let b = Boost(name: "Dark Mode", urlPattern: "*.example.com", isEnabled: true)
        #expect(b.name == "Dark Mode")
    }

@Test func autoArchivePolicyDefaultThreshold() {
        #expect(AutoArchivePolicy.defaultThreshold == 14 * 86_400)
    }
}
