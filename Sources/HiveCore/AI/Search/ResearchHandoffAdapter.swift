import CryptoKit
import Foundation

// MARK: - Research handoff application adapter

/// Consumes the Rust research-boundary JSON document at the application layer.
///
/// This is intentionally not an FFI implementation. The Rust worker can emit
/// this document now; a future process supervisor can pass its bytes here. The
/// adapter validates the document again, persists only verified source metadata,
/// and records the real Honeycomb node ID in EventLedger.
public struct ResearchHandoffAdapter: Sendable {
    public enum PrivacyScope: Sendable {
        case nonPrivate
        case privateBrowsing
    }

    public struct IngestedSource: Sendable, Equatable {
        public let source: Source
        public let ledgerEventID: String
        /// Raw bytes were integrity-checked but are not retained because the
        /// current Source contract has no raw-body artifact store.
        public let rawBodyRetained: Bool
        /// True when Honeycomb returned an existing content-addressed Source.
        public let wasDeduplicated: Bool
    }

    public struct ReconciliationResult: Sendable, Equatable {
        public enum Outcome: Sendable, Equatable {
            case repaired
            case alreadyComplete
            case deferred(String)
        }

        public let journalID: String
        public let sourceID: String?
        public let ledgerEventID: String
        public let outcome: Outcome

        public init(journalID: String, sourceID: String?, ledgerEventID: String, outcome: Outcome) {
            self.journalID = journalID
            self.sourceID = sourceID
            self.ledgerEventID = ledgerEventID
            self.outcome = outcome
        }
    }

    public enum AdapterError: Error, Sendable, Equatable, CustomStringConvertible {
        case payloadTooLarge(limit: Int)
        case malformedDocument(String)
        case invalidDocument(String)
        case privateContentNotSupported
        case durableRetentionRequiresApproval
        case capabilityExpired
        case capabilityMismatch
        case capabilityReplayed
        case capabilityStorage(String)
        case recoveryJournal(String)
        case honeycombPersistence(String)
        case ledgerPersistence(sourceID: String, message: String)

        public var description: String {
            switch self {
            case .payloadTooLarge(let limit):
                return "research handoff exceeds the \(limit)-byte application limit"
            case .malformedDocument(let message):
                return "research handoff JSON is malformed: \(message)"
            case .invalidDocument(let message):
                return "research handoff is invalid: \(message)"
            case .privateContentNotSupported:
                return "private browsing content is categorically rejected by this adapter"
            case .durableRetentionRequiresApproval:
                return "project or permanent retention requires explicit user approval"
            case .capabilityExpired:
                return "durable retention capability has expired"
            case .capabilityMismatch:
                return "durable retention capability does not match this handoff"
            case .capabilityReplayed:
                return "durable retention capability has already been consumed"
            case .capabilityStorage(let message):
                return "durable retention capability storage failed: \(message)"
            case .recoveryJournal(let message):
                return "research handoff recovery journal failed: \(message)"
            case .honeycombPersistence(let message):
                return "Honeycomb source persistence failed: \(message)"
            case .ledgerPersistence(let sourceID, let message):
                return "EventLedger persistence failed after source \(sourceID) was stored: \(message)"
            }
        }
    }

    private let honeycomb: HoneycombStore
    private let ledger: EventLedgerStore
    private let capabilityRegistry: RetentionCapabilityRegistry
    private let recoveryJournal: HandoffRecoveryJournal
    private let approvalAuthority: RetentionCapabilityAuthority

    public init(
        honeycomb: HoneycombStore,
        ledger: EventLedgerStore,
        capabilityRegistry: RetentionCapabilityRegistry,
        recoveryJournal: HandoffRecoveryJournal,
        approvalAuthority: RetentionCapabilityAuthority
    ) {
        self.honeycomb = honeycomb
        self.ledger = ledger
        self.capabilityRegistry = capabilityRegistry
        self.recoveryJournal = recoveryJournal
        self.approvalAuthority = approvalAuthority
    }

    /// Decodes and validates before crossing either actor boundary.
    ///
    /// Private content is rejected because the transport envelope currently
    /// carries no private-browsing provenance bit and this adapter has no
    /// private-retention policy. A future caller must introduce a separately
    /// reviewed policy rather than silently treating an unlabelled payload as
    /// durable memory.
    public func ingest(
        json: Data,
        privacy: PrivacyScope = .nonPrivate,
        sessionID: String? = nil,
        projectID: String? = nil,
        retentionCapability: RetentionCapability? = nil
    ) async throws -> IngestedSource {
        switch privacy {
        case .nonPrivate:
            break
        case .privateBrowsing:
            throw AdapterError.privateContentNotSupported
        }

        let payload = try Self.decodeAndValidate(json)
        let capability = try validateCapability(
            retentionCapability,
            for: payload,
            projectID: projectID
        )

        let source: Source
        do {
            source = try payload.makeSource()
        } catch let error as PayloadValidationError {
            throw AdapterError.invalidDocument(error.description)
        } catch {
            throw AdapterError.invalidDocument(String(describing: error))
        }
        if let capability {
            do {
                try await capabilityRegistry.reserve(capability.nonce)
            } catch let error as RetentionCapabilityError {
                switch error {
                case .replayed:
                    throw AdapterError.capabilityReplayed
                case .storage(let message):
                    throw AdapterError.capabilityStorage(message)
                case .invalid, .expired, .issuerMismatch, .keyVersionMismatch, .signatureMissing, .signatureInvalid, .bindingConflict:
                    throw AdapterError.invalidDocument(error.description)
                }
            }
        }

        let provisionalEvent = makeLedgerEvent(
            source: source,
            storedSourceID: source.id,
            sessionID: sessionID,
            projectID: projectID,
            capability: capability
        )
        let journalRecord = HandoffRecoveryJournal.Record(
            source: source,
            event: provisionalEvent,
            retentionCapability: capability
        )
        do {
            // Bind before append: a crash can leave an orphaned reservation,
            // but cannot leave a journal record that recovery cannot prove was
            // issued by this application's approval registry.
            if let capability {
                try await capabilityRegistry.bind(
                    capability.nonce,
                    journalID: journalRecord.id,
                    eventID: journalRecord.event.id
                )
            }
            try await recoveryJournal.append(journalRecord)
        } catch {
            if let capability {
                _ = try? await capabilityRegistry.unbind(
                    capability.nonce,
                    journalID: journalRecord.id,
                    eventID: journalRecord.event.id
                )
                _ = try? await capabilityRegistry.release(capability.nonce)
            }
            _ = try? await recoveryJournal.remove(id: journalRecord.id)
            throw AdapterError.recoveryJournal(String(describing: error))
        }

        let stored: Source
        do {
            stored = try await honeycomb.createSource(source)
        } catch {
            if let capability {
                // Preserve the source-write failure. A release failure is a
                // fail-closed condition: the durable registry may have burned
                // the grant, so the caller must issue a fresh approval.
                _ = try? await capabilityRegistry.release(capability.nonce)
            }
            _ = try? await recoveryJournal.remove(id: journalRecord.id)
            throw AdapterError.honeycombPersistence(String(describing: error))
        }

        let wasDeduplicated = stored.id != source.id
        let event = makeLedgerEvent(
            source: source,
            storedSourceID: stored.id,
            sessionID: sessionID,
            projectID: projectID,
            capability: capability
        )
        let finalizedRecord = HandoffRecoveryJournal.Record(
            id: journalRecord.id,
            source: stored,
            event: event,
            retentionCapability: capability,
            createdAt: journalRecord.createdAt
        )
        do {
            try await recoveryJournal.replace(finalizedRecord)
        } catch {
            throw AdapterError.recoveryJournal(String(describing: error))
        }

        let recorded: EventLedgerStore.LedgerEvent
        do {
            recorded = try await ledger.recordIfAbsent(event)
        } catch {
            // The Source and recovery record are durable. Leave the journal in
            // place so startup reconciliation can finish the audit later.
            throw AdapterError.ledgerPersistence(
                sourceID: stored.id,
                message: String(describing: error)
            )
        }
        do {
            try await recoveryJournal.remove(id: journalRecord.id)
        } catch {
            // The audit is complete; retaining the journal is safe because the
            // next reconciliation sees the existing event and removes it.
            throw AdapterError.recoveryJournal(String(describing: error))
        }

        return IngestedSource(
            source: stored,
            ledgerEventID: recorded.id,
            rawBodyRetained: false,
            wasDeduplicated: wasDeduplicated
        )
    }

    /// Repairs every durable handoff left in the journal after a crash or
    /// ledger failure. This is safe to call at startup and repeatedly.
    public func reconcilePending() async throws -> [ReconciliationResult] {
        let records: [HandoffRecoveryJournal.Record]
        do {
            records = try await recoveryJournal.pending()
        } catch {
            throw AdapterError.recoveryJournal(String(describing: error))
        }

        var results: [ReconciliationResult] = []
        for record in records {
            try Task.checkCancellation()
            if let capability = record.retentionCapability {
                do {
                    guard let binding = try await capabilityRegistry.binding(for: capability.nonce),
                          binding.journalID == record.id,
                          binding.eventID == record.event.id else {
                        results.append(ReconciliationResult(
                            journalID: record.id,
                            sourceID: nil,
                            ledgerEventID: record.event.id,
                            outcome: .deferred("journal approval is not bound to this journal and event")
                        ))
                        continue
                    }
                } catch {
                    results.append(ReconciliationResult(
                        journalID: record.id,
                        sourceID: nil,
                        ledgerEventID: record.event.id,
                        outcome: .deferred("capability binding lookup failed: \(error)")
                    ))
                    continue
                }
            }
            if let bindingError = validateRecoveryBinding(record) {
                results.append(ReconciliationResult(
                    journalID: record.id,
                    sourceID: nil,
                    ledgerEventID: record.event.id,
                    outcome: .deferred(bindingError)
                ))
                continue
            }
            let existingEvent = try await ledger.getEvent(id: record.event.id)
            let existingSource: Source?
            if let hash = record.source.contentHash, !hash.isEmpty {
                existingSource = try await honeycomb.findSource(byContentHash: hash)
            } else {
                existingSource = nil
            }
            if let existingEvent, let existingSource,
               validateExistingEvent(existingEvent, against: record, source: existingSource) == nil,
               validateStoredSource(existingSource, against: record.source) == nil {
                try await recoveryJournal.remove(id: record.id)
                results.append(ReconciliationResult(
                    journalID: record.id,
                    sourceID: existingSource.id,
                    ledgerEventID: existingEvent.id,
                    outcome: .alreadyComplete
                ))
                continue
            }

            let source: Source
            do {
                if let existingSource {
                    source = existingSource
                } else {
                    source = try await honeycomb.createSource(record.source)
                }
            } catch {
                results.append(ReconciliationResult(
                    journalID: record.id,
                    sourceID: existingSource?.id,
                    ledgerEventID: record.event.id,
                    outcome: .deferred("Honeycomb persistence failed: \(error)" )
                ))
                continue
            }

            if let bindingError = validateStoredSource(source, against: record.source) {
                results.append(ReconciliationResult(
                    journalID: record.id,
                    sourceID: source.id,
                    ledgerEventID: record.event.id,
                    outcome: .deferred(bindingError)
                ))
                continue
            }

            let event = record.event.withContextIDs([source.id])
            do {
                let recorded = try await ledger.recordIfAbsent(event)
                try await recoveryJournal.remove(id: record.id)
                results.append(ReconciliationResult(
                    journalID: record.id,
                    sourceID: source.id,
                    ledgerEventID: recorded.id,
                    outcome: .repaired
                ))
            } catch {
                results.append(ReconciliationResult(
                    journalID: record.id,
                    sourceID: source.id,
                    ledgerEventID: record.event.id,
                    outcome: .deferred("EventLedger reconciliation failed: \(error)")
                ))
            }
        }
        return results
    }

    private func validateRecoveryBinding(_ record: HandoffRecoveryJournal.Record) -> String? {
        let source = record.source
        guard record.event.actionKind == .research else {
            return "journal event is not a research event"
        }
        guard record.event.actionTarget == (source.requestedURL ?? source.url) else {
            return "journal event target does not match the staged source"
        }
        guard record.event.provenance == source.provenance else {
            return "journal event provenance does not match the staged source"
        }
        if let capability = record.retentionCapability {
            do {
                // Recovery honors the capability's validity at staging time.
                // A crash after expiry must not turn an already-approved,
                // journaled source into an unrecoverable orphan.
                try approvalAuthority.verify(capability, at: record.createdAt)
            } catch {
                return "journal approval signature could not be verified: \(error)"
            }
            guard capability.action == "research_source.persist",
                  capability.sourceContentHash == source.contentHash,
                  capability.retentionClass == source.retentionClass,
                  capability.deletionScope == source.deletionScope,
                  capability.projectID == record.event.projectID,
                  capability.provenance == source.provenance else {
                return "journal approval capability does not match the staged source"
            }
            guard record.event.consentState == .approved else {
                return "journal approval capability is not reflected in the audit event"
            }
        } else if record.event.consentState != .notRequired {
            return "journal audit event claims consent without an approval capability"
        }
        return nil
    }

    private func validateExistingEvent(
        _ event: EventLedgerStore.LedgerEvent,
        against record: HandoffRecoveryJournal.Record,
        source: Source
    ) -> String? {
        guard event.actionKind == .research,
              event.actionTarget == (record.source.requestedURL ?? record.source.url),
              event.provenance == record.source.provenance,
              event.contextIDs == [source.id],
              event.consentState == record.event.consentState else {
            return "existing audit event does not match the staged handoff"
        }
        return nil
    }

    private func validateStoredSource(_ stored: Source, against staged: Source) -> String? {
        guard stored.contentHash == staged.contentHash,
              stored.url == staged.url,
              stored.provenance == staged.provenance,
              stored.retentionClass == staged.retentionClass,
              stored.deletionScope == staged.deletionScope else {
            return "stored source does not match the staged source binding"
        }
        return nil
    }

    private func makeLedgerEvent(
        source: Source,
        storedSourceID: String,
        sessionID: String?,
        projectID: String?,
        capability: RetentionCapability?
    ) -> EventLedgerStore.LedgerEvent {
        let deduplicationNote = storedSourceID == source.id
            ? ""
            : " Existing content-addressed source reused; this fetch remains separately audited."
        return EventLedgerStore.LedgerEvent(
            actor: "research-boundary",
            sessionID: sessionID,
            projectID: projectID,
            intent: "Persist verified research source handoff",
            actionKind: .research,
            actionTarget: source.requestedURL ?? source.url,
            actionPreview: "Store verified source metadata and content hash",
            trustLevel: .t2,
            policyDecision: .allowed,
            consentState: capability == nil ? .notRequired : .approved,
            contextIDs: [storedSourceID],
            environment: "swift-6",
            outputSummary: "Source \(storedSourceID) persisted; requested=\(source.requestedURL ?? source.url); final=\(source.url); status=\(source.httpStatus.map(String.init) ?? "unknown"); content_type=\(source.contentType ?? "unknown"); body_bytes=\(source.bodySize.map(String.init) ?? "unknown"); retention=\(source.retentionClass ?? "unknown"); deletion_scope=\(source.deletionScope ?? "unknown"); expires_at=\(source.expiresAtUnixMS ?? "none"); raw body not retained; citation readiness remains false; approval_nonce=\(capability?.nonce ?? "none").\(deduplicationNote)",
            result: .success,
            verificationResult: .verified,
            provenance: "rust-research-boundary"
        )
    }

    private func validateCapability(
        _ capability: RetentionCapability?,
        for payload: HandoffPayload,
        projectID: String?
    ) throws -> RetentionCapability? {
        guard payload.retention.requiresDurableApproval else {
            if capability != nil {
                throw AdapterError.invalidDocument("approval capability is only valid for durable retention")
            }
            return nil
        }
        guard let capability else {
            throw AdapterError.durableRetentionRequiresApproval
        }
        do {
            try approvalAuthority.verify(capability)
        } catch let error as RetentionCapabilityError {
            switch error {
            case .expired: throw AdapterError.capabilityExpired
            default: throw AdapterError.invalidDocument(error.description)
            }
        }
        guard capability.retentionClass == payload.retention.className,
              capability.deletionScope == payload.retention.deletionScope,
              capability.sourceContentHash == payload.source.contentHashSHA256,
              capability.provenance == payload.provenance,
              capability.projectID == projectID else {
            throw AdapterError.capabilityMismatch
        }
        return capability
    }

    // MARK: - Decoding and validation

    static let maxJSONBytes = 8 * 1024 * 1024
    static let maxURLBytes = 8 * 1024
    static let maxFinalURLBytes = 8 * 1024
    static let maxBodyBytes = 5 * 1024 * 1024
    static let maxRedirectCount = 64

    private static func decodeAndValidate(_ data: Data) throws -> HandoffPayload {
        guard data.count <= maxJSONBytes else {
            throw AdapterError.payloadTooLarge(limit: maxJSONBytes)
        }
        let decoded: HandoffPayload
        do {
            decoded = try JSONDecoder().decode(HandoffPayload.self, from: data)
        } catch {
            throw AdapterError.malformedDocument(String(describing: error))
        }
        do {
            try decoded.validate()
        } catch let error as PayloadValidationError {
            throw AdapterError.invalidDocument(error.description)
        } catch {
            throw AdapterError.invalidDocument(String(describing: error))
        }
        return decoded
    }
}

// MARK: - Versioned wire mirror

private struct HandoffPayload: Codable, Sendable {
    let schemaVersion: UInt16
    let kind: String
    let provenance: String
    let source: HandoffSourcePayload
    let retention: RetentionPayload
    let extraction: String
    let citationReady: Bool

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case kind, provenance, source, retention, extraction
        case citationReady = "citation_ready"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(UInt16.self, forKey: .schemaVersion)
        kind = try c.decode(String.self, forKey: .kind)
        provenance = try c.decodeIfPresent(String.self, forKey: .provenance) ?? "legacy-v1"
        source = try c.decode(HandoffSourcePayload.self, forKey: .source)
        retention = try c.decode(RetentionPayload.self, forKey: .retention)
        extraction = try c.decode(String.self, forKey: .extraction)
        citationReady = try c.decodeIfPresent(Bool.self, forKey: .citationReady) ?? false
    }

    func validate() throws {
        guard schemaVersion == 1 else {
            throw PayloadValidationError.unsupportedSchema(schemaVersion)
        }
        guard kind == "research_source" else {
            throw PayloadValidationError.invalid("kind must be research_source")
        }
        try validateText(provenance, maxBytes: 256, field: "provenance")
        guard extraction == "not_extracted" else {
            throw PayloadValidationError.invalid("unsupported extraction state")
        }
        guard citationReady == false else {
            throw PayloadValidationError.invalid("raw handoff cannot claim citation readiness")
        }
        try source.validate()
        try retention.validate()
    }

    func makeSource() throws -> Source {
        guard let retrievalDate = source.retrievalDate else {
            throw PayloadValidationError.invalid("retrieved_at_unix_ms cannot be represented as a Foundation Date")
        }
        let bodySize = Data(base64Encoded: source.bodyBase64)?.count
        return Source(
            url: source.finalURL,
            captureMethod: source.captureMethod,
            contentHash: source.contentHashSHA256,
            retrievalTimestamp: retrievalDate,
            createdAt: retrievalDate,
            updatedAt: retrievalDate,
            provenance: provenance,
            requestedURL: source.requestedURL,
            redirectCount: source.redirectCount,
            httpStatus: source.status,
            contentType: source.contentType,
            bodySize: bodySize,
            retrievedAtUnixMS: source.retrievedAtUnixMS.value,
            expiresAtUnixMS: retention.expiresAtUnixMS?.value,
            retentionClass: retention.className,
            deletionScope: retention.deletionScope,
            extractionState: extraction,
            citationReady: false
        )
    }
}

private struct HandoffSourcePayload: Codable, Sendable {
    let requestedURL: String
    let finalURL: String
    let status: Int
    let contentType: String?
    let redirectCount: Int
    let retrievedAtUnixMS: DecimalWireValue
    let contentHashSHA256: String
    let bodyBase64: String
    let captureMethod: String

    enum CodingKeys: String, CodingKey {
        case requestedURL = "requested_url"
        case finalURL = "final_url"
        case status
        case contentType = "content_type"
        case redirectCount = "redirect_count"
        case retrievedAtUnixMS = "retrieved_at_unix_ms"
        case contentHashSHA256 = "content_hash_sha256"
        case bodyBase64 = "body_base64"
        case captureMethod = "capture_method"
    }

    var retrievalDate: Date? {
        guard let milliseconds = UInt64(retrievedAtUnixMS.value),
              milliseconds <= UInt64(Int64.max) else { return nil }
        return Date(timeIntervalSince1970: Double(milliseconds) / 1000.0)
    }

    func validate() throws {
        try validateURL(requestedURL, field: "requested_url")
        try validateURL(finalURL, field: "final_url", maxBytes: ResearchHandoffAdapter.maxFinalURLBytes)
        guard (200...599).contains(status) else {
            throw PayloadValidationError.invalid("status must be between 200 and 599")
        }
        guard (0...ResearchHandoffAdapter.maxRedirectCount).contains(redirectCount) else {
            throw PayloadValidationError.invalid("redirect_count exceeds the maximum")
        }
        if let contentType {
            try validateText(contentType, maxBytes: 1024, field: "content_type")
        }
        try validateText(captureMethod, maxBytes: 128, field: "capture_method")
        guard retrievedAtUnixMS.value.isCanonicalPositiveDecimal,
              let milliseconds = UInt64(retrievedAtUnixMS.value),
              milliseconds <= UInt64(Int64.max) else {
            throw PayloadValidationError.invalid(
                "retrieved_at_unix_ms must be a bounded positive decimal"
            )
        }
        guard contentHashSHA256.count == 64,
              contentHashSHA256 == contentHashSHA256.lowercased(),
              contentHashSHA256.allSatisfy(\.isHexDigit) else {
            throw PayloadValidationError.invalid("content_hash_sha256 must be 64 hexadecimal characters")
        }
        guard let body = Data(base64Encoded: bodyBase64), body.count <= ResearchHandoffAdapter.maxBodyBytes else {
            throw PayloadValidationError.invalid("body_base64 is invalid or too large")
        }
        let actualHash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        guard actualHash == contentHashSHA256 else {
            throw PayloadValidationError.invalid("content hash does not match body")
        }
    }
}

/// A decimal value accepted from either the Rust string representation or the
/// legacy JSON-number representation. The original text is preserved so the
/// application never rounds a cross-language timestamp before validation.
private struct DecimalWireValue: Codable, Sendable {
    let value: String

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let string = try? c.decode(String.self) {
            value = string
            return
        }
        if let unsigned = try? c.decode(UInt64.self) {
            value = String(unsigned)
            return
        }
        if let signed = try? c.decode(Int64.self) {
            value = String(signed)
            return
        }
        throw DecodingError.dataCorruptedError(
            in: c,
            debugDescription: "expected a decimal string or JSON integer"
        )
    }

    init(value: String) { self.value = value }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(value)
    }
}

private struct RetentionPayload: Codable, Sendable {
    let `class`: String
    let deletionScope: String
    let expiresAtUnixMS: DecimalWireValue?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        `class` = try c.decode(String.self, forKey: .class)
        deletionScope = try c.decode(String.self, forKey: .deletionScope)
        expiresAtUnixMS = try c.decodeIfPresent(DecimalWireValue.self, forKey: .expiresAtUnixMS)
    }

    enum CodingKeys: String, CodingKey {
        case `class`
        case deletionScope = "deletion_scope"
        case expiresAtUnixMS = "expires_at_unix_ms"
    }

    var className: String { `class` }
    var requiresDurableApproval: Bool { `class` == "project" || `class` == "permanent" }

    func validate() throws {
        guard ["ephemeral", "session", "project", "permanent"].contains(`class`) else {
            throw PayloadValidationError.invalid("unknown retention class")
        }
        guard ["this_source", "provenance", "project"].contains(deletionScope) else {
            throw PayloadValidationError.invalid("unknown deletion scope")
        }
        if let expiresAtUnixMS {
            guard expiresAtUnixMS.value.isCanonicalPositiveDecimal else {
                throw PayloadValidationError.invalid("expires_at_unix_ms must be a positive decimal")
            }
        }
    }
}

private enum PayloadValidationError: Error, CustomStringConvertible {
    case unsupportedSchema(UInt16)
    case invalid(String)

    var description: String {
        switch self {
        case .unsupportedSchema(let version): return "unsupported schema version \(version)"
        case .invalid(let message): return message
        }
    }
}

private extension String {
    var isCanonicalPositiveDecimal: Bool {
        guard !isEmpty, allSatisfy(\.isNumber), first != "0" else { return false }
        return true
    }
}

private func validateText(_ value: String, maxBytes: Int, field: String) throws {
    guard !value.isEmpty, value.utf8.count <= maxBytes,
          !value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else {
        throw PayloadValidationError.invalid("\(field) is empty, too long, or contains controls")
    }
}

private func validateURL(_ value: String, field: String, maxBytes: Int = ResearchHandoffAdapter.maxURLBytes) throws {
    guard value.utf8.count <= maxBytes,
          let components = URLComponents(string: value),
          let scheme = components.scheme,
          ["http", "https"].contains(scheme.lowercased()),
          let host = components.host, !host.isEmpty,
          components.user == nil, components.password == nil,
          !value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else {
        throw PayloadValidationError.invalid("\(field) must be a bounded HTTP(S) URL without credentials")
    }
}
