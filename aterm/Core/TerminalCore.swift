import Foundation
import Observation

@Observable
@MainActor
final class TerminalCore {
    private(set) var latestChunk: String = ""
    private(set) var outputGeneration: UInt64 = 0
    private(set) var isRunning: Bool = true

    private let ptyProcess: PTYProcess
    private var ptyFileHandle: PTYFileHandle?
    private let coreQueue = DispatchQueue(label: "com.aterm.terminal-core", qos: .userInteractive)

    init(columns: UInt16 = 80, rows: UInt16 = 24) throws {
        let process = try PTYProcess(columns: columns, rows: rows)
        self.ptyProcess = process

        self.ptyFileHandle = PTYFileHandle(fd: process.masterFD, queue: coreQueue) { data in
            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor [weak self] in
                self?.appendOutput(text)
            }
        }

        Task { [weak self] in
            for await exitCode in process.exitStream {
                guard let self else { return }
                await MainActor.run {
                    self.isRunning = false
                    self.appendOutput("\n[Process exited with code \(exitCode)]")
                    Log.core.info("Shell exited with code \(exitCode)")
                }
            }
        }

        Log.core.info("TerminalCore initialized")
    }

    func sendInput(_ string: String) {
        guard isRunning, let fileHandle = ptyFileHandle else { return }
        if let data = string.data(using: .utf8) {
            coreQueue.async {
                fileHandle.write(data)
            }
        }
    }

    func sendBytes(_ bytes: [UInt8]) {
        guard isRunning, let fileHandle = ptyFileHandle else { return }
        let data = Data(bytes)
        coreQueue.async {
            fileHandle.write(data)
        }
    }

    func resize(columns: UInt16, rows: UInt16) {
        ptyProcess.resize(columns: columns, rows: rows)
    }

    func terminate() {
        ptyFileHandle?.close()
        ptyFileHandle = nil
        ptyProcess.terminate()
        isRunning = false
    }

    private var ansiStripper = ANSIStripper()

    // MARK: - Private

    private func appendOutput(_ text: String) {
        let stripped = ansiStripper.strip(text)
        latestChunk = stripped
        outputGeneration &+= 1
    }
}
