import Foundation
import Testing
@testable import HiveCore

// MARK: - StudioWorkspace

@Suite("StudioWorkspace")
struct StudioWorkspaceTests {

    /// Builds a temp workspace with a seed file and returns (workspace, root).
    private func makeWorkspace() async throws -> (StudioWorkspace, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-studio-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "let x = 1\n".write(to: dir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)
        let workspace = StudioWorkspace(rootURL: dir)
        return (workspace, dir)
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Containment

    @Test func rejectsTraversalEscape() async throws {
        let (workspace, dir) = try await makeWorkspace()
        defer { cleanup(dir) }
        await #expect(throws: StudioWorkspace.StudioError.self) {
            _ = try await workspace.resolvedURL(for: "../../etc/passwd")
        }
        await #expect(throws: StudioWorkspace.StudioError.self) {
            _ = try await workspace.resolvedURL(for: "sub/../../etc/passwd")
        }
    }

    @Test func rejectsAbsoluteAndHomePaths() async throws {
        let (workspace, dir) = try await makeWorkspace()
        defer { cleanup(dir) }
        await #expect(throws: StudioWorkspace.StudioError.self) {
            _ = try await workspace.resolvedURL(for: "/etc/passwd")
        }
        await #expect(throws: StudioWorkspace.StudioError.self) {
            _ = try await workspace.resolvedURL(for: "~/secrets")
        }
    }

    @Test func resolvesPathsInsideRoot() async throws {
        let (workspace, dir) = try await makeWorkspace()
        defer { cleanup(dir) }
        let resolved = try await workspace.resolvedURL(for: "main.swift")
        #expect(resolved.path == dir.appendingPathComponent("main.swift").path)
    }

    @Test func containsIsFalseWithoutRoot() async throws {
        let workspace = StudioWorkspace(rootURL: nil)
        let outside = FileManager.default.temporaryDirectory
        #expect(await !workspace.contains(outside))
    }

    @Test func symlinkEscapeIsRejected() async throws {
        let (workspace, dir) = try await makeWorkspace()
        defer { cleanup(dir) }
        // Create a symlink inside the root pointing outside it.
        let outside = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-outside-\(UUID().uuidString)")
        try "secret".write(to: outside, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: outside) }
        let link = dir.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        await #expect(throws: StudioWorkspace.StudioError.self) {
            _ = try await workspace.resolvedURL(for: "link")
        }
    }

    // MARK: - Read / Write / Rollback

    @Test func readsExistingFile() async throws {
        let (workspace, dir) = try await makeWorkspace()
        defer { cleanup(dir) }
        let content = try await workspace.readFile("main.swift")
        #expect(content == "let x = 1\n")
    }

    @Test func applyEditBacksUpAndWrites() async throws {
        let (workspace, dir) = try await makeWorkspace()
        defer { cleanup(dir) }
        let edit = try await workspace.applyEdit("main.swift", newContent: "let x = 2\n")
        #expect(edit.originalContent == "let x = 1\n")
        #expect(edit.backupPath != nil)
        let after = try await workspace.readFile("main.swift")
        #expect(after == "let x = 2\n")
    }

    @Test func rollbackRestoresOriginal() async throws {
        let (workspace, dir) = try await makeWorkspace()
        defer { cleanup(dir) }
        let edit = try await workspace.applyEdit("main.swift", newContent: "let x = 2\n")
        try await workspace.rollback(edit)
        let restored = try await workspace.readFile("main.swift")
        #expect(restored == "let x = 1\n")
    }

    @Test func newFileEditRollbackDeletes() async throws {
        let (workspace, dir) = try await makeWorkspace()
        defer { cleanup(dir) }
        let edit = try await workspace.applyEdit("new.swift", newContent: "// fresh\n")
        #expect(edit.backupPath == nil)
        #expect(try await workspace.readFile("new.swift") == "// fresh\n")
        try await workspace.rollback(edit)
        await #expect(throws: StudioWorkspace.StudioError.self) {
            _ = try await workspace.readFile("new.swift")
        }
    }

    @Test func rejectsWriteToDirectory() async throws {
        let (workspace, dir) = try await makeWorkspace()
        defer { cleanup(dir) }
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("sub"), withIntermediateDirectories: true)
        await #expect(throws: StudioWorkspace.StudioError.self) {
            _ = try await workspace.applyEdit("sub", newContent: "x")
        }
    }

    // MARK: - Diff

    @Test func diffIdenticalIsNoChanges() {
        let diff = StudioWorkspace.unifiedDiff(original: "a\nb\n", new: "a\nb\n", path: "f.txt")
        #expect(diff == "No changes.")
    }

    @Test func diffShowsChangedLinesWithHunk() {
        let diff = StudioWorkspace.unifiedDiff(
            original: "a\nb\nc\n",
            new: "a\nB\nc\n",
            path: "f.txt"
        )
        #expect(diff.contains("--- a/f.txt"))
        #expect(diff.contains("+++ b/f.txt"))
        #expect(diff.contains("@@ -2,1 +2,1 @@"))
        #expect(diff.contains("-b"))
        #expect(diff.contains("+B"))
    }

    @Test func diffHandlesInsertionAndDeletion() {
        let inserted = StudioWorkspace.unifiedDiff(
            original: "a\nc\n",
            new: "a\nb\nc\n",
            path: "f.txt"
        )
        #expect(inserted.contains("+b"))

        let deleted = StudioWorkspace.unifiedDiff(
            original: "a\nb\nc\n",
            new: "a\nc\n",
            path: "f.txt"
        )
        #expect(deleted.contains("-b"))
    }

    @Test func diffEmptyToContent() {
        let diff = StudioWorkspace.unifiedDiff(original: "", new: "hello\n", path: "f.txt")
        #expect(diff.contains("+hello"))
    }

    // MARK: - Bounded Check Runner

    @Test func runCheckRunsInWorkspace() async throws {
        let (workspace, dir) = try await makeWorkspace()
        defer { cleanup(dir) }
        let output = try await workspace.runCheck(command: "pwd")
        #expect(output.hasSuffix(dir.path) || output == dir.path)
    }

    @Test func runCheckReturnsCommandOutput() async throws {
        let (workspace, dir) = try await makeWorkspace()
        defer { cleanup(dir) }
        let output = try await workspace.runCheck(command: "echo hive-check")
        #expect(output == "hive-check")
    }

    @Test func runCheckReportsFailure() async throws {
        let (workspace, dir) = try await makeWorkspace()
        defer { cleanup(dir) }
        await #expect(throws: StudioWorkspace.StudioError.self) {
            _ = try await workspace.runCheck(command: "exit 3")
        }
    }

    @Test func runCheckTimesOut() async throws {
        let (workspace, dir) = try await makeWorkspace()
        defer { cleanup(dir) }
        await #expect(throws: StudioWorkspace.StudioError.self) {
            _ = try await workspace.runCheck(command: "sleep 5", timeout: 0.4)
        }
    }

    @Test func runCheckRequiresRoot() async throws {
        let workspace = StudioWorkspace(rootURL: nil)
        await #expect(throws: StudioWorkspace.StudioError.self) {
            _ = try await workspace.runCheck(command: "echo hi")
        }
    }

    // MARK: - Repo Detection

    @Test func detectsGitRepository() async throws {
        let (workspace, dir) = try await makeWorkspace()
        defer { cleanup(dir) }
        #expect(await !workspace.isGitRepository())
        try FileManager.default.createDirectory(at: dir.appendingPathComponent(".git"), withIntermediateDirectories: true)
        #expect(await workspace.isGitRepository())
    }

    // MARK: - Git-native Rollback

    @Test func gitRestoreRejectsNoRoot() async throws {
        let workspace = StudioWorkspace(rootURL: nil)
        await #expect(throws: StudioWorkspace.StudioError.self) {
            _ = try await workspace.gitRestore(file: "main.swift")
        }
    }

    @Test func gitRestoreRejectsTraversal() async throws {
        let (workspace, dir) = try await makeWorkspace()
        defer { cleanup(dir) }
        await #expect(throws: StudioWorkspace.StudioError.self) {
            _ = try await workspace.gitRestore(file: "../../etc/passwd")
        }
    }

    @Test func gitRestoreRejectsWithoutGitRepo() async throws {
        let (workspace, dir) = try await makeWorkspace()
        defer { cleanup(dir) }
        // No .git directory — git restore will fail because there's no repo.
        await #expect(throws: StudioWorkspace.StudioError.self) {
            _ = try await workspace.gitRestore(file: "main.swift")
        }
    }
}
