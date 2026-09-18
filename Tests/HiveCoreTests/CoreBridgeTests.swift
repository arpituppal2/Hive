import Foundation
import Testing
@testable import HiveCore

/// The bridge contract test — resurrected from v1's
/// `WebChromeBridgeContractTests` pattern (SALVAGE-MANIFEST), re-aimed at v2:
/// every `hive.*` method the web chrome calls must be registered natively, and
/// every registered non-internal method must be reachable from the web side.
/// CI merge gate: this failing means the two halves of the product disagree.
struct WebChromeBridgeContractTests {

    static let appJSPath = RepoLocator.locate("Sources/Hive/WebChrome/app.js")

    static let callRegex = try! NSRegularExpression(
        pattern: "(?:hive\\.call|\\bcall|\\brpc)\\(\\s*['\"]([a-z]+\\.[a-zA-Z]+)['\"]"
    )

    /// Extracts `call('method'` / `hive.call("method"` call sites.
    static func calledMethods(source: String) -> Set<String> {
        let range = NSRange(source.startIndex..., in: source)
        return Set(callRegex.matches(in: source, range: range)
            .compactMap { Range($0.range(at: 1), in: source).map { String(source[$0]) } })
    }

    /// Event types the native bus emits (`bus.emit("type"` in Swift sources).
    static func emittedEvents(sources: [String]) -> Set<String> {
        let regex = try! NSRegularExpression(pattern: "\\.emit\\(\\s*\"([a-z]+\\.[a-z]+)\"")
        var out: Set<String> = []
        for src in sources {
            let range = NSRange(src.startIndex..., in: src)
            out.formUnion(regex.matches(in: src, range: range)
                .compactMap { Range($0.range(at: 1), in: src).map { String(src[$0]) } })
        }
        return out
    }

    /// Event types the chrome consumes (`case 'x.y'` / `type === 'x.y'`).
    static func handledEventTypes(appJS: String) -> Set<String> {
        let regex = try! NSRegularExpression(
            pattern: "(?:case\\s+['\"]|type\\s*===?\\s*['\"])([a-z]+\\.[a-z]+)['\"]")
        let range = NSRange(appJS.startIndex..., in: appJS)
        return Set(regex.matches(in: appJS, range: range)
            .compactMap { Range($0.range(at: 1), in: appJS).map { String(appJS[$0]) } })
    }

    @Test func everyWebCallIsRegistered() throws {
        let js = try String(contentsOf: Self.appJSPath, encoding: .utf8)
        let calls = Self.calledMethods(source: js)
        #expect(!calls.isEmpty, "no bridge calls found — file layout drifted?")
        for m in calls {
            #expect(BridgeRegistry.methods.contains(m),
                    "web calls '\(m)' but native never registers it (v1's fatal bug class)")
        }
    }

    @Test func everyRegisteredMethodIsReachableOrInternal() throws {
        let js = try String(contentsOf: Self.appJSPath, encoding: .utf8)
        let calls = Self.calledMethods(source: js)
        for m in BridgeRegistry.methods where !BridgeRegistry.internalMethods.contains(m) {
            #expect(calls.contains(m),
                    "'\(m)' is registered but the web chrome never calls it — dead surface or wrong name")
        }
    }

    @Test func eventsEmittedAreHandled() throws {
        let swiftSources = [
            try String(contentsOf: RepoLocator.locate("Sources/Hive/AppController.swift"), encoding: .utf8),
            try String(contentsOf: RepoLocator.locate("Sources/Hive/CaptureService.swift"), encoding: .utf8),
            try String(contentsOf: RepoLocator.locate("Sources/Hive/Bridge/BridgeInstaller.swift"), encoding: .utf8),
        ]
        let js = try String(contentsOf: Self.appJSPath, encoding: .utf8)
        let emitted = Self.emittedEvents(sources: swiftSources)
        let handled = Self.handledEventTypes(appJS: js)
        // Native → web direction is authoritative; unhandled emissions are bugs.
        for e in emitted {
            #expect(handled.contains(e),
                    "native emits '\(e)' but chrome never handles it")
        }
    }

    @Test func dotDelimitedEverywhere() {
        for m in BridgeRegistry.methods {
            #expect(!m.contains("-"), "hyphenated method '\(m)' violates BRIDGE-SPEC naming")
        }
    }
}

/// Locates repo files from the test bundle regardless of working directory.
enum RepoLocator {
    static func locate(_ rel: String) -> URL {
        var url = URL(fileURLWithPath: #filePath)   // …/Tests/HiveCoreTests/CoreBridgeTests.swift
        for _ in 0..<3 { url.deleteLastPathComponent() }   // repo root
        return url.appending(path: rel)
    }
}
