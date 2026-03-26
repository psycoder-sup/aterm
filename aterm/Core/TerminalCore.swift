import Foundation
import Observation

// C-compatible callback for terminal write-to-PTY responses.
// userdata points to an Int32 containing the PTY master FD.
private func terminalWritePtyCallback(
    _: GhosttyTerminal?,
    userdata: UnsafeMutableRawPointer?,
    data: UnsafePointer<UInt8>?,
    len: Int
) {
    guard let data, len > 0,
          let userdata else { return }
    let fd = userdata.assumingMemoryBound(to: Int32.self).pointee
    var totalWritten = 0
    while totalWritten < len {
        let result = Darwin.write(fd, data.advanced(by: totalWritten), len - totalWritten)
        if result < 0 {
            if errno == EINTR { continue }
            return
        }
        totalWritten += result
    }
}

@Observable
@MainActor
final class TerminalCore {
    private(set) var latestSnapshot: GridSnapshot?
    private(set) var snapshotGeneration: UInt64 = 0
    private(set) var isRunning: Bool = true

    private let ptyProcess: PTYProcess
    private var ptyFileHandle: PTYFileHandle?

    // Bridge objects — accessed only on coreQueue
    private let bridge: TerminalBridge

    private let coreQueue = DispatchQueue(
        label: "com.aterm.terminal-core",
        qos: .userInteractive
    )

    init(columns: UInt16 = 80, rows: UInt16 = 24) throws {
        let process = try PTYProcess(columns: columns, rows: rows)
        self.ptyProcess = process

        let bridge = try TerminalBridge.create(
            columns: columns,
            rows: rows,
            ptyFD: process.masterFD
        )
        bridge.setupWriteCallback(ptyFD: process.masterFD)
        self.bridge = bridge

        self.ptyFileHandle = PTYFileHandle(fd: process.masterFD, queue: coreQueue) {
            [weak self] data in
            guard let self else { return }
            self.bridge.processOutput(data)
            if let snapshot = self.bridge.extractSnapshot() {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.latestSnapshot = snapshot
                    self.snapshotGeneration &+= 1
                }
            }
        }

        Task { [weak self] in
            for await exitCode in process.exitStream {
                guard let self else { return }
                await MainActor.run {
                    self.isRunning = false
                    Log.core.info("Shell exited with code \(exitCode)")
                }
            }
        }

        Log.core.info("TerminalCore initialized with ghostty bridge")
    }

    func sendInput(_ string: String) {
        guard isRunning, let fileHandle = ptyFileHandle else { return }
        if let data = string.data(using: .utf8) {
            coreQueue.async {
                fileHandle.write(data)
            }
        }
    }

    func sendKeyEvent(
        action: GhosttyKeyAction,
        key: GhosttyKey,
        mods: GhosttyMods,
        text: String?
    ) {
        guard isRunning, let fileHandle = ptyFileHandle else { return }
        let bridge = self.bridge
        coreQueue.async {
            if let bytes = bridge.encodeKey(action: action, key: key, mods: mods, text: text) {
                fileHandle.write(Data(bytes))
            }
        }
    }

    func resize(columns: UInt16, rows: UInt16) {
        ptyProcess.resize(columns: columns, rows: rows)
        let bridge = self.bridge
        coreQueue.async {
            bridge.resize(columns: columns, rows: rows)
        }
    }

    func terminate() {
        ptyFileHandle?.close()
        ptyFileHandle = nil
        isRunning = false
        let process = ptyProcess
        coreQueue.async {
            process.terminate()
        }
    }
}

// Encapsulates all non-Sendable bridge objects behind a facade
// that is only accessed from the terminal-core queue.
final class TerminalBridge: Sendable {
    private let terminal: GhosttyBridge.Terminal
    private let renderState: GhosttyBridge.RenderState
    private let keyEncoder: GhosttyBridge.KeyEncoder
    private nonisolated(unsafe) var fdPtr: UnsafeMutablePointer<Int32>?

    init(
        terminal: GhosttyBridge.Terminal,
        renderState: GhosttyBridge.RenderState,
        keyEncoder: GhosttyBridge.KeyEncoder
    ) {
        self.terminal = terminal
        self.renderState = renderState
        self.keyEncoder = keyEncoder
    }

    deinit {
        fdPtr?.deallocate()
    }

    static func create(columns: UInt16, rows: UInt16, ptyFD: Int32) throws -> TerminalBridge {
        let terminal = try GhosttyBridge.Terminal(
            columns: columns,
            rows: rows,
            maxScrollback: 10_000
        )
        let renderState = try GhosttyBridge.RenderState()
        let keyEncoder = try GhosttyBridge.KeyEncoder()
        keyEncoder.syncFromTerminal(terminal)

        return TerminalBridge(terminal: terminal, renderState: renderState, keyEncoder: keyEncoder)
    }

    func setupWriteCallback(ptyFD: Int32) {
        let ptr = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        ptr.pointee = ptyFD
        self.fdPtr = ptr
        terminal.setUserdata(ptr)
        terminal.setWritePtyCallback(terminalWritePtyCallback)
    }

    func processOutput(_ data: Data) {
        terminal.vtWrite(data)
    }

    func extractSnapshot() -> GridSnapshot? {
        renderState.extractSnapshot(terminal: terminal)
    }

    func encodeKey(
        action: GhosttyKeyAction,
        key: GhosttyKey,
        mods: GhosttyMods,
        text: String?
    ) -> [UInt8]? {
        keyEncoder.syncFromTerminal(terminal)
        return keyEncoder.encode(action: action, key: key, mods: mods, text: text)
    }

    func resize(columns: UInt16, rows: UInt16) {
        terminal.resize(columns: columns, rows: rows)
    }
}
