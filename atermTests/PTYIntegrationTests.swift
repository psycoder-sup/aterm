import Testing
import Foundation
import os
@testable import aterm

struct PTYIntegrationTests {
    // MARK: - Round-trip I/O

    @Test func echoRoundTrip() async throws {
        let process = try PTYProcess(columns: 80, rows: 24)
        let receivedOutput = OSAllocatedUnfairLock(initialState: "")
        let readQueue = DispatchQueue(label: "test-pty-io")

        let fileHandle = PTYFileHandle(fd: process.masterFD, queue: readQueue) { data in
            let text = String(decoding: data, as: UTF8.self)
            receivedOutput.withLock { $0.append(text) }
        }
        defer {
            fileHandle.close()
            process.terminate()
        }

        // Wait for shell startup
        try await Task.sleep(for: .milliseconds(500))

        // Send echo command
        fileHandle.write("echo TESTOUTPUT42\r".data(using: .utf8)!)

        // Wait for output
        try await Task.sleep(for: .milliseconds(500))

        let output = receivedOutput.withLock { $0 }
        #expect(output.contains("TESTOUTPUT42"))
    }

    @Test func asyncReadCallbackFires() async throws {
        let process = try PTYProcess(columns: 80, rows: 24)
        let receivedOutput = OSAllocatedUnfairLock(initialState: "")
        let readQueue = DispatchQueue(label: "test-pty-read")

        let fileHandle = PTYFileHandle(fd: process.masterFD, queue: readQueue) { data in
            let text = String(decoding: data, as: UTF8.self)
            receivedOutput.withLock { $0.append(text) }
        }
        defer {
            fileHandle.close()
            process.terminate()
        }

        try await Task.sleep(for: .milliseconds(300))

        fileHandle.write("echo CALLBACKTEST77\r".data(using: .utf8)!)

        try await Task.sleep(for: .seconds(1))

        let output = receivedOutput.withLock { $0 }
        #expect(output.contains("CALLBACKTEST77"))
    }

    // MARK: - Shell exit

    @Test(.timeLimit(.minutes(1)))
    func shellExitProducesExitCode() async throws {
        let process = try PTYProcess(columns: 80, rows: 24)

        // Wait for shell to start
        try await Task.sleep(for: .milliseconds(300))

        // Send exit command via direct write
        let cmd = "exit 0\r".data(using: .utf8)!
        cmd.withUnsafeBytes { buffer in
            _ = Darwin.write(process.masterFD, buffer.baseAddress!, buffer.count)
        }

        // Collect exit code with timeout
        var exitCode: Int32?
        for await code in process.exitStream {
            exitCode = code
            break
        }

        #expect(exitCode == 0)
    }

    // MARK: - Terminate

    @Test func terminateKillsChild() throws {
        let process = try PTYProcess(columns: 80, rows: 24)
        let pid = process.childPID

        #expect(kill(pid, 0) == 0)

        process.terminate()
        usleep(100_000)

        #expect(kill(pid, 0) != 0)
    }
}
