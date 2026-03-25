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

    private var stripperState = ANSIStripperState.normal

    // MARK: - Private

    private func appendOutput(_ text: String) {
        let stripped = stripANSI(text)
        latestChunk = stripped
        outputGeneration &+= 1
    }

    /// Strip ANSI escape sequences, persisting state across calls to handle
    /// sequences split across data chunks.
    private func stripANSI(_ input: String) -> String {
        var result = String()
        result.reserveCapacity(input.count)

        for char in input {
            switch stripperState {
            case .normal:
                if char == "\u{1B}" {
                    stripperState = .escape
                } else if char == "\u{9B}" {
                    // 8-bit CSI
                    stripperState = .csi
                } else if char.asciiValue.map({ $0 < 0x20 && $0 != 0x0A && $0 != 0x0D && $0 != 0x09 }) == true {
                    // Strip control chars except newline, carriage return, tab
                } else {
                    result.append(char)
                }

            case .escape:
                switch char {
                case "[":
                    stripperState = .csi
                case "]":
                    stripperState = .osc
                case "(", ")", "*", "+", "#":
                    stripperState = .escapeIntermediate
                default:
                    stripperState = .normal
                }

            case .escapeIntermediate:
                // Consume one more byte after ESC( etc.
                stripperState = .normal

            case .csi:
                if char.asciiValue.map({ $0 >= 0x40 && $0 <= 0x7E }) == true {
                    stripperState = .normal
                }

            case .osc:
                if char == "\u{07}" {
                    stripperState = .normal
                } else if char == "\u{1B}" {
                    stripperState = .oscEscape
                }

            case .oscEscape:
                if char == "\\" {
                    stripperState = .normal
                } else {
                    stripperState = .osc
                }
            }
        }

        return result
    }
}

private enum ANSIStripperState {
    case normal
    case escape
    case escapeIntermediate
    case csi
    case osc
    case oscEscape
}
