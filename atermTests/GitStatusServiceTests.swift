import Foundation
import Testing
@testable import aterm

struct GitStatusServiceTests {

    // MARK: - detectRepo

    @Test func detectRepoOnGitDir() async throws {
        let repo = try makeTempGitRepo()
        defer { cleanup(repo) }

        let result = await GitStatusService.detectRepo(directory: repo)
        #expect(result != nil)
        #expect(result?.gitDir == ".git")
        // commonDir should be an absolute path ending with .git
        #expect(result?.commonDir.hasPrefix("/") == true)
        #expect(result?.commonDir.hasSuffix(".git") == true)
    }

    @Test func detectRepoOnNonGitDir() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let result = await GitStatusService.detectRepo(directory: dir)
        #expect(result == nil)
    }

    @Test func detectRepoOnWorktree() async throws {
        let repo = try makeTempGitRepo()
        defer { cleanup(repo) }

        // Create a worktree
        let worktreePath = (repo as NSString)
            .deletingLastPathComponent
            .appending("/aterm-wt-\(UUID().uuidString)")
        defer { cleanup(worktreePath) }

        try runGitSync(["worktree", "add", worktreePath, "-b", "wt-branch"], in: repo)

        let result = await GitStatusService.detectRepo(directory: worktreePath)
        #expect(result != nil)
        // gitDir should be an absolute path inside main repo's .git/worktrees/
        #expect(result?.gitDir.contains("/worktrees/") == true || result?.gitDir == ".git")
        // commonDir should point to the main repo's .git (shared)
        let mainGitDir = (repo as NSString).appendingPathComponent(".git")
        let canonicalMain = URL(filePath: mainGitDir).standardizedFileURL.path
        #expect(result?.commonDir == canonicalMain)
    }

    // MARK: - currentBranch

    @Test func currentBranchReturnsSymbolicRef() async throws {
        let repo = try makeTempGitRepo()
        defer { cleanup(repo) }

        let result = await GitStatusService.currentBranch(directory: repo)
        #expect(result != nil)
        #expect(result?.isDetached == false)
        // Default branch is typically "main" or "master"
        #expect(result?.name.isEmpty == false)
    }

    @Test func currentBranchReturnsAbbreviatedSHAForDetachedHEAD() async throws {
        let repo = try makeTempGitRepo()
        defer { cleanup(repo) }

        // Detach HEAD by checking out the commit hash
        try runGitSync(["checkout", "--detach", "HEAD"], in: repo)

        let result = await GitStatusService.currentBranch(directory: repo)
        #expect(result != nil)
        #expect(result?.isDetached == true)
        // Should be an abbreviated SHA (7+ hex chars)
        let name = try #require(result?.name)
        #expect(name.count >= 7)
        #expect(name.allSatisfy { $0.isHexDigit })
    }

    // MARK: - Helpers

    private func makeTempGitRepo() throws -> String {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("aterm-test-\(UUID().uuidString)")
            .path
        try FileManager.default.createDirectory(atPath: dir,
                                                  withIntermediateDirectories: true)
        try runGitSync(["init"], in: dir)
        try runGitSync(["config", "user.email", "test@test.com"], in: dir)
        try runGitSync(["config", "user.name", "Test"], in: dir)

        let readmePath = (dir as NSString).appendingPathComponent("README.md")
        try "# Test".write(toFile: readmePath, atomically: true, encoding: .utf8)

        try runGitSync(["add", "."], in: dir)
        try runGitSync(["commit", "-m", "Initial commit"], in: dir)

        return dir
    }

    private func makeTempDir() throws -> String {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("aterm-test-\(UUID().uuidString)")
            .path
        try FileManager.default.createDirectory(atPath: dir,
                                                  withIntermediateDirectories: true)
        return dir
    }

    private func runGitSync(_ args: [String], in dir: String) throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(filePath: dir)
        let stderr = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let msg = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw StringError("git \(args.joined(separator: " ")) failed: \(msg)")
        }
    }

    private func cleanup(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    private struct StringError: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
}
