import Foundation
import OSLog

/// Stateless service wrapping git CLI subprocess calls.
/// All methods are async and run subprocesses on background threads.
enum GitStatusService {

    /// Detects the git repository for a given directory.
    /// Returns the git dir and common dir paths, or nil if not in a git repo.
    static func detectRepo(
        directory: String
    ) async -> (gitDir: String, commonDir: String)? {
        do {
            // Single subprocess: get both --git-dir and --git-common-dir at once
            let result = try await runGit(
                ["rev-parse", "--git-dir", "--git-common-dir"],
                workingDirectory: directory
            )
            guard result.exitCode == 0, !result.stdout.isEmpty else {
                Log.git.info("Not a git repo: \(directory)")
                return nil
            }

            let lines = result.stdout.components(separatedBy: "\n")
            guard lines.count >= 2, !lines[0].isEmpty, !lines[1].isEmpty else {
                Log.git.info("Unexpected rev-parse output for: \(directory)")
                return nil
            }

            let gitDir = lines[0]
            let rawCommonDir = lines[1]

            // Canonicalize commonDir to an absolute path
            let absoluteCommonDir: String
            if rawCommonDir.hasPrefix("/") {
                absoluteCommonDir = URL(filePath: rawCommonDir).standardizedFileURL.path
            } else {
                absoluteCommonDir = URL(filePath: rawCommonDir, relativeTo: URL(filePath: directory))
                    .standardizedFileURL.path
            }

            Log.git.debug("Detected repo at \(directory): gitDir=\(gitDir), commonDir=\(absoluteCommonDir)")
            return (gitDir: gitDir, commonDir: absoluteCommonDir)
        } catch {
            Log.git.error("detectRepo failed for \(directory): \(error)")
            return nil
        }
    }

    /// Returns the current branch name and whether HEAD is detached.
    static func currentBranch(
        directory: String
    ) async -> (name: String, isDetached: Bool)? {
        do {
            let symbolicResult = try await runGit(
                ["symbolic-ref", "--short", "HEAD"],
                workingDirectory: directory
            )
            if symbolicResult.exitCode == 0, !symbolicResult.stdout.isEmpty {
                return (name: symbolicResult.stdout, isDetached: false)
            }

            // Detached HEAD — fall back to abbreviated SHA
            let revParseResult = try await runGit(
                ["rev-parse", "--short", "HEAD"],
                workingDirectory: directory
            )
            if revParseResult.exitCode == 0, !revParseResult.stdout.isEmpty {
                return (name: revParseResult.stdout, isDetached: true)
            }

            Log.git.info("Could not determine branch for: \(directory)")
            return nil
        } catch {
            Log.git.error("currentBranch failed for \(directory): \(error)")
            return nil
        }
    }

    // MARK: - Private

    private static func runGit(
        _ arguments: [String],
        workingDirectory: String
    ) async throws -> (exitCode: Int32, stdout: String, stderr: String) {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(filePath: "/usr/bin/git")
                process.arguments = arguments
                process.currentDirectoryURL = URL(filePath: workingDirectory)

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                let stdout = String(data: stdoutData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                continuation.resume(returning: (process.terminationStatus, stdout, stderr))
            }
        }
    }
}
