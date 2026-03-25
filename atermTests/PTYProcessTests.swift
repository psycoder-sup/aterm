import Testing
import Foundation
@testable import aterm

struct PTYProcessTests {
    // MARK: - Environment

    @Test func buildEnvironmentSetsTerminalVars() {
        // Access via a spawned process and check env
        // Since buildEnvironment is private static, we test indirectly
        // by verifying the shell gets the right TERM value
        let process = try! PTYProcess(columns: 80, rows: 24)
        defer { process.terminate() }

        // Write a command to echo TERM
        let cmd = "echo $TERM\r"
        let data = cmd.data(using: .utf8)!
        data.withUnsafeBytes { buffer in
            _ = Darwin.write(process.masterFD, buffer.baseAddress!, buffer.count)
        }

        // Read back output
        usleep(500_000)
        var readBuf = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(process.masterFD, &readBuf, readBuf.count)
        let output = String(bytes: readBuf[..<bytesRead], encoding: .utf8) ?? ""

        #expect(output.contains("xterm-256color"))
    }

    @Test func buildEnvironmentInheritsPath() {
        let process = try! PTYProcess(columns: 80, rows: 24)
        defer { process.terminate() }

        let cmd = "echo $PATH\r"
        let data = cmd.data(using: .utf8)!
        data.withUnsafeBytes { buffer in
            _ = Darwin.write(process.masterFD, buffer.baseAddress!, buffer.count)
        }

        usleep(500_000)
        var readBuf = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(process.masterFD, &readBuf, readBuf.count)
        let output = String(bytes: readBuf[..<bytesRead], encoding: .utf8) ?? ""

        // PATH should be non-empty and contain /usr/bin at minimum
        #expect(output.contains("/usr/bin"))
    }

    // MARK: - Shell detection

    @Test func spawnsWithValidShell() {
        let process = try! PTYProcess(columns: 80, rows: 24)
        defer { process.terminate() }

        // If we got here without throwing, the shell spawned successfully
        #expect(process.childPID > 0)
        #expect(process.masterFD >= 0)
    }

    // MARK: - Resize

    @Test func resizeDoesNotCrash() {
        let process = try! PTYProcess(columns: 80, rows: 24)
        defer { process.terminate() }

        // Should not crash or throw
        process.resize(columns: 120, rows: 40)
        process.resize(columns: 40, rows: 10)
    }
}
