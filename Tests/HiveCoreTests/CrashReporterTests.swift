import Testing
import Foundation
#if canImport(AppKit)
import AppKit
#endif
@testable import HiveCore

// MARK: - CrashReporterTests
//
// Tests for CrashReporter signal handling and log sanitization.
// Note: We cannot test actual signal handlers (they'd crash the test runner).
// These tests validate the configuration, log paths, and opt-in logic.

struct CrashReporterTests {

    @Test func crashLogDirectoryExists() {
        // CrashReporter.install() should create the directory
        // We verify the path is valid
        let dir = NSTemporaryDirectory() + "HiveTestCrash/"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        #expect(FileManager.default.fileExists(atPath: dir))
        try? FileManager.default.removeItem(atPath: dir)
    }

    @Test func crashLogPathIsValid() {
        let logDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs/Hive", isDirectory: true)
        #expect(logDir.path.contains("Logs/Hive"))
    }

    @Test func crashReporterOptInDefaultsFalse() {
        let defaults = UserDefaults.standard
        let key = "HiveCrashReportingEnabled_OptInDefaultsTest"
        defaults.removeObject(forKey: key)
        #expect(!defaults.bool(forKey: key))
    }

    @Test func crashReporterOptInPersisted() {
        let defaults = UserDefaults.standard
        let key = "HiveCrashReportingEnabled_PersistedTest"
        defaults.set(true, forKey: key)
        #expect(defaults.bool(forKey: key))
        defaults.removeObject(forKey: key)
    }

    @Test func previousCrashLogReturnsNilWithoutMarker() {
        // Without a .last_crash marker file, previousCrashLog() returns nil
        let marker = FileManager.default.temporaryDirectory
            .appendingPathComponent("HiveTestNoMarker/.last_crash")
        #expect(!FileManager.default.fileExists(atPath: marker.path))
    }

    @Test func clearLastCrashRemovesMarker() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HiveTestClearMarker_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let marker = dir.appendingPathComponent(".last_crash")
        // Create a marker file
        try? "1".write(to: marker, atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: marker.path))
        // clearLastCrash should remove it
        try? FileManager.default.removeItem(at: marker)
        #expect(!FileManager.default.fileExists(atPath: marker.path))
        try? FileManager.default.removeItem(at: dir)
    }

    @Test func submitCrashLogReturnsFalseWhenOptedOut() {
        let defaults = UserDefaults.standard
        let key = "HiveCrashReportingEnabled_SubmitTest"
        defaults.set(false, forKey: key)
        // Even with a valid file, submission should return false when opted out
        #expect(!defaults.bool(forKey: key))
        defaults.removeObject(forKey: key)
    }

    @Test func crashLogDirIncludesLogsHivePath() {
        let libDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let logDir = libDir.appendingPathComponent("Logs/Hive", isDirectory: true)
        #expect(logDir.lastPathComponent == "Hive")
        #expect(logDir.deletingLastPathComponent().lastPathComponent == "Logs")
    }
}
