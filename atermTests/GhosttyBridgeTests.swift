import Testing
import AppKit
@testable import aterm

@Suite("GhosttyBridge")
struct GhosttyBridgeTests {

    @Test func terminalCreationAndFree() throws {
        let terminal = try GhosttyBridge.Terminal(columns: 80, rows: 24)
        // Should not crash — deinit will free
        _ = terminal
    }

    @Test func renderStateCreation() throws {
        let state = try GhosttyBridge.RenderState()
        _ = state
    }

    @Test func keyEncoderCreation() throws {
        let encoder = try GhosttyBridge.KeyEncoder()
        _ = encoder
    }

    @Test func vtWriteUpdatesRenderState() throws {
        let terminal = try GhosttyBridge.Terminal(columns: 80, rows: 24)
        let renderState = try GhosttyBridge.RenderState()

        // Write "hello" to the terminal
        let data = "hello".data(using: .utf8)!
        terminal.vtWrite(data)

        // Update render state and check dirty
        renderState.update(from: terminal)
        let dirty = renderState.getDirtyState()
        #expect(dirty != .none)
    }

    @Test func snapshotExtraction() throws {
        let terminal = try GhosttyBridge.Terminal(columns: 80, rows: 24)
        let renderState = try GhosttyBridge.RenderState()

        terminal.vtWrite("Hello World".data(using: .utf8)!)

        let snapshot = renderState.extractSnapshot(terminal: terminal)
        #expect(snapshot != nil)

        guard let snapshot else { return }
        #expect(snapshot.columns == 80)
        #expect(snapshot.rows == 24)
        #expect(snapshot.cells.count == 80 * 24)

        // First cell should be 'H'
        let firstCell = snapshot.cell(at: GridPosition(col: 0, row: 0))
        #expect(firstCell?.codepoint == Unicode.Scalar("H"))
    }

    @Test func snapshotColorsResolved() throws {
        let terminal = try GhosttyBridge.Terminal(columns: 80, rows: 24)
        let renderState = try GhosttyBridge.RenderState()

        // Write red text: ESC[31m RED ESC[0m
        let data = "\u{1b}[31mRED\u{1b}[0m".data(using: .utf8)!
        terminal.vtWrite(data)

        let snapshot = renderState.extractSnapshot(terminal: terminal)
        #expect(snapshot != nil)

        guard let snapshot else { return }
        let rCell = snapshot.cell(at: GridPosition(col: 0, row: 0))
        #expect(rCell?.codepoint == Unicode.Scalar("R"))
        // The cell should have a non-nil foreground color (red palette entry)
        #expect(rCell?.style.foreground != nil)
    }

    @Test func terminalResize() throws {
        let terminal = try GhosttyBridge.Terminal(columns: 80, rows: 24)
        let renderState = try GhosttyBridge.RenderState()

        terminal.resize(columns: 120, rows: 40)
        renderState.update(from: terminal)

        let (cols, rows) = renderState.getGridSize()
        #expect(cols == 120)
        #expect(rows == 40)
    }

    @Test func keyEncoderProducesOutput() throws {
        let terminal = try GhosttyBridge.Terminal(columns: 80, rows: 24)
        let encoder = try GhosttyBridge.KeyEncoder()
        encoder.syncFromTerminal(terminal)

        // Encode 'a' key press
        let result = encoder.encode(
            action: GHOSTTY_KEY_ACTION_PRESS,
            key: GHOSTTY_KEY_A,
            mods: 0,
            text: "a"
        )
        #expect(result != nil)
        // The encoder produces output for 'a' — exact byte depends on mode
        #expect(result!.count > 0)
    }

    @Test func keyEncoderArrowKeys() throws {
        let terminal = try GhosttyBridge.Terminal(columns: 80, rows: 24)
        let encoder = try GhosttyBridge.KeyEncoder()
        encoder.syncFromTerminal(terminal)

        let result = encoder.encode(
            action: GHOSTTY_KEY_ACTION_PRESS,
            key: GHOSTTY_KEY_ARROW_UP,
            mods: 0,
            text: nil
        )
        #expect(result != nil)
        // Should be ESC [ A in normal mode
        #expect(result == [0x1B, 0x5B, 0x41])
    }

    @Test func snapshotBoldStyle() throws {
        let terminal = try GhosttyBridge.Terminal(columns: 80, rows: 24)
        let renderState = try GhosttyBridge.RenderState()

        // Write bold text: ESC[1m BOLD ESC[0m
        terminal.vtWrite("\u{1b}[1mBOLD\u{1b}[0m".data(using: .utf8)!)

        let snapshot = renderState.extractSnapshot(terminal: terminal)!
        let bCell = snapshot.cell(at: GridPosition(col: 0, row: 0))!
        #expect(bCell.codepoint == Unicode.Scalar("B"))
        #expect(bCell.style.bold == true)
    }

    @Test func snapshotCursorPosition() throws {
        let terminal = try GhosttyBridge.Terminal(columns: 80, rows: 24)
        let renderState = try GhosttyBridge.RenderState()

        terminal.vtWrite("abc".data(using: .utf8)!)

        let snapshot = renderState.extractSnapshot(terminal: terminal)!
        #expect(snapshot.cursor.inViewport == true)
        #expect(snapshot.cursor.position.col == 3)
        #expect(snapshot.cursor.position.row == 0)
    }

    @Test func snapshotOutOfBoundsReturnsNil() throws {
        let terminal = try GhosttyBridge.Terminal(columns: 80, rows: 24)
        let renderState = try GhosttyBridge.RenderState()

        terminal.vtWrite("x".data(using: .utf8)!)
        let snapshot = renderState.extractSnapshot(terminal: terminal)!

        #expect(snapshot.cell(at: GridPosition(col: -1, row: 0)) == nil)
        #expect(snapshot.cell(at: GridPosition(col: 80, row: 0)) == nil)
        #expect(snapshot.cell(at: GridPosition(col: 0, row: 24)) == nil)
    }

    @Test func toAttributedStringBasic() throws {
        let terminal = try GhosttyBridge.Terminal(columns: 10, rows: 2)
        let renderState = try GhosttyBridge.RenderState()

        terminal.vtWrite("Hello".data(using: .utf8)!)

        let snapshot = renderState.extractSnapshot(terminal: terminal)!
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let attrStr = snapshot.toAttributedString(font: font)

        #expect(attrStr.string.contains("Hello"))
    }

    @Test func terminalBridgeIntegration() throws {
        let bridge = try TerminalBridge.create(columns: 80, rows: 24, ptyFD: -1)

        bridge.processOutput("test".data(using: .utf8)!)

        let snapshot = bridge.extractSnapshot()
        #expect(snapshot != nil)
        #expect(snapshot?.columns == 80)
    }
}
