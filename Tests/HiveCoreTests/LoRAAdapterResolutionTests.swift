import Foundation
import Testing
@testable import HiveCore

// MARK: - LoRA adapter resolution (Track D1)
//
// The differentiating thesis (PITCH/colonization-thesis.md) is that tiny distilled
// Swarm Cells beat generalists on UNSEEN inputs. The 3 distilled roles —
// intentClassifier, spamDetector, urgencyDetector — were verified on held-out
// data and flipped to `.instructLoRA`, each carrying a `loraAdapter` key
// (intent_router / spam_detector / urgency_detector) that names a trained adapter
// to be merged onto the shared Qwen2.5-0.5B base.
//
// That merge only happens at runtime when the adapter directory resolves on disk
// (`ModelStore.adapterDirectory(for:)`). Until the trained weights are shipped
// (blocked — needs Brev artifacts; see PITCH/backend-completion.md "out of
// scope"), the adapter dir is ABSENT in CI. The honest behavior then is: run the
// off-the-shelf base, label `provider: .mlx` WITHOUT the "+LoRA" suffix — real
// local inference, NOT a silent Mock flip hiding behind a LoRA claim.
//
// This test pins that honest-degradation state so it is OBSERVABLE in CI, not
// silent. It FAILS if a regression makes degradation invisible:
//   • a `.instructLoRA` role drops its `loraAdapter` key (you could no longer tell
//     "adapter missing" from "no adapter at all"), OR
//   • an absent adapter is paired with NO base repo (the role would silently flip
//     to Mock, despite being declared LoRA — the exact lie this test exists to
//     catch), OR
//   • the named keys drift (a rename that would quietly break the on-disk path).
// It PASSES when the adapter is absent AND a real base repo is declared — the
// honest base-only degrade, auditable rather than fabricated.

@Suite("LoRA adapter resolution")
struct LoRAAdapterResolutionTests {

    private let loraRoles: [ModelRole] = [.intentClassifier, .spamDetector, .urgencyDetector]
    private let expectedKeys: Set<String> = ["intent_router", "spam_detector", "urgency_detector"]

    @Test func loraRolesDegradeObservablyNotSilently() async throws {
        for role in loraRoles {
            let entry = try #require(ModelManifest.entries[role],
                                     "\(role) missing from ModelManifest.entries")
            #expect(entry.servingStrategy == .instructLoRA,
                    "\(role) must be .instructLoRA; a drift breaks the adapter-merge path")

            // The adapter key is the manifest's document-of-record. Without it the
            // base-only degrade can't be observed (silent), so a nil key on a
            // .instructLoRA role is an honest-degradation regression.
            guard let key = entry.loraAdapter else {
                Issue.record(".instructLoRA role \(role) has no loraAdapter key — degradation would be silent")
                continue
            }
            #expect(expectedKeys.contains(key),
                    "\(role): adapter key '\(key)' is not one of the named distilled adapters")

            // Observe presence/absence on disk. EITHER is correct — both are honest.
            let present = ModelStore.adapterDirectory(for: key) != nil

            if !present {
                // Documented-absent. The honest degrade is to the real off-the-shelf
                // base (provider .mlx, no "+LoRA" suffix) — NOT a silent Mock flip.
                // That requires a declared base repo; an absent adapter with no base
                // repo would fall through to Mock while wearing a LoRA label — the lie.
                #expect(entry.hfRepo != nil,
                        "\(role): absent adapter + undeclared base repo = silent Mock degrade behind a LoRA label")
            }
            // `present` is asserted only to make the state observable; we do not
            // require either value. The point is that it was checked, so the degrade
            // path is reachable and auditable rather than dead code.
        }
    }

    @Test func nonLoRARolesStayUnchanged() {
        let nonLoRARoles: [ModelRole] = [.orchestrator, .summarizer, .librarian, .titleGenerator]
        for role in nonLoRARoles {
            guard let entry = ModelManifest.entries[role] else { continue }
            #expect(entry.servingStrategy != .instructLoRA,
                    "\(role) must not be .instructLoRA — only distilled roles carry LoRA adapters")
        }
    }

    @Test func loraRolesAreExactlyThree() {
        let loraCount = ModelRole.allCases.filter { role in
            guard let entry = ModelManifest.entries[role] else { return false }
            return entry.servingStrategy == .instructLoRA
        }.count
        #expect(loraCount == 3, "Exactly 3 distilled LoRA roles expected, found \(loraCount)")
    }

    @Test func adapterKeysMatchExpectedSet() {
        let keys = loraRoles.compactMap { ModelManifest.entries[$0]?.loraAdapter }
        #expect(Set(keys) == expectedKeys,
                "LoRA adapter key drift — keys: \(keys), expected: \(expectedKeys)")
    }
}
