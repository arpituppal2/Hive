import CryptoKit
import Foundation

// MARK: - SyncCipher
//
// P3.4 end-to-end envelope: AES-256-GCM over the JSON-encoded SyncPayload.
// The CloudKit server never sees plaintext — only `v1 | nonce | sealedBox`.
// AES-GCM's authentication tag doubles as tamper detection and gives us
// wrong-key rejection for free (decrypt throws).

public struct SyncCipher: Sendable {

    /// Envelope version marker. Bump when the wire format changes.
    public static let version: UInt8 = 1

    public enum Error: Swift.Error, Equatable, Sendable {
        case badEnvelope
        case unsupportedVersion(UInt8)
        case decryptionFailed
    }

    public init() {}

    /// Generates a fresh 256-bit key. The app is responsible for persisting
    /// it (Keychain) — the engine only ever consumes an injected key.
    public static func makeKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    /// Encrypts arbitrary authenticated data for local encrypted stores.
    /// The same versioned AES-GCM envelope is used for CloudKit payloads and
    /// the local outbox, so URLs/titles never sit in UserDefaults plaintext.
    public func encryptData(_ plaintext: Data, with key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw Error.badEnvelope }
        var envelope = Data([Self.version])
        envelope.append(combined)
        return envelope
    }

    /// Decrypts arbitrary authenticated data, rejecting tampering and wrong
    /// keys before any caller attempts to decode it.
    public func decryptData(_ envelope: Data, with key: SymmetricKey) throws -> Data {
        guard let first = envelope.first else { throw Error.badEnvelope }
        guard first == Self.version else { throw Error.unsupportedVersion(first) }
        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.SealedBox(combined: envelope.dropFirst())
        } catch {
            throw Error.badEnvelope
        }
        do {
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw Error.decryptionFailed
        }
    }

    /// Encrypts a payload into an envelope: `[version][nonce][sealedBox]`.
    public func encrypt(_ payload: SyncPayload, with key: SymmetricKey) throws -> Data {
        try encryptData(JSONEncoder().encode(payload), with: key)
    }

    /// Decrypts an envelope, authenticating it and rejecting tampering and
    /// wrong keys.
    public func decrypt(_ envelope: Data, with key: SymmetricKey) throws -> SyncPayload {
        do {
            return try JSONDecoder().decode(
                SyncPayload.self,
                from: try decryptData(envelope, with: key)
            )
        } catch let error as Error {
            throw error
        } catch {
            throw Error.decryptionFailed
        }
    }
}
