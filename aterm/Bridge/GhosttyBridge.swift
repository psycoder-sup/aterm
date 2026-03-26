import Foundation

enum GhosttyBridge {

    // MARK: - Terminal

    final class Terminal: @unchecked Sendable {
        let handle: GhosttyTerminal

        init(columns: UInt16, rows: UInt16, maxScrollback: Int = 10_000) throws {
            var terminal: GhosttyTerminal?
            let options = GhosttyTerminalOptions(
                cols: columns,
                rows: rows,
                max_scrollback: maxScrollback
            )
            try ghosttyCheck(
                ghostty_terminal_new(nil, &terminal, options),
                context: "terminal_new"
            )
            guard let terminal else {
                throw GhosttyError.outOfMemory
            }
            self.handle = terminal
        }

        deinit {
            ghostty_terminal_free(handle)
        }

        func vtWrite(_ data: Data) {
            data.withUnsafeBytes { buffer in
                guard let base = buffer.baseAddress else { return }
                ghostty_terminal_vt_write(
                    handle,
                    base.assumingMemoryBound(to: UInt8.self),
                    buffer.count
                )
            }
        }

        func resize(columns: UInt16, rows: UInt16) {
            ghostty_terminal_resize(handle, columns, rows, 0, 0)
        }

        func setUserdata(_ ptr: UnsafeMutableRawPointer?) {
            ghostty_terminal_set(handle, GHOSTTY_TERMINAL_OPT_USERDATA, ptr)
        }

        func setWritePtyCallback(_ fn: GhosttyTerminalWritePtyFn?) {
            var callback = fn
            ghostty_terminal_set(handle, GHOSTTY_TERMINAL_OPT_WRITE_PTY, &callback)
        }
    }

    // MARK: - Render State

    final class RenderState: @unchecked Sendable {
        let handle: GhosttyRenderState

        init() throws {
            var state: GhosttyRenderState?
            try ghosttyCheck(
                ghostty_render_state_new(nil, &state),
                context: "render_state_new"
            )
            guard let state else {
                throw GhosttyError.outOfMemory
            }
            self.handle = state
        }

        deinit {
            ghostty_render_state_free(handle)
        }

        func update(from terminal: Terminal) {
            ghostty_render_state_update(handle, terminal.handle)
        }

        func getDirtyState() -> DirtyState {
            var dirty = GHOSTTY_RENDER_STATE_DIRTY_FALSE
            ghostty_render_state_get(handle, GHOSTTY_RENDER_STATE_DATA_DIRTY, &dirty)
            switch dirty {
            case GHOSTTY_RENDER_STATE_DIRTY_FALSE: return .none
            case GHOSTTY_RENDER_STATE_DIRTY_PARTIAL: return .partial
            case GHOSTTY_RENDER_STATE_DIRTY_FULL: return .full
            default: return .full
            }
        }

        func clearDirty() {
            var dirty = GHOSTTY_RENDER_STATE_DIRTY_FALSE
            ghostty_render_state_set(handle, GHOSTTY_RENDER_STATE_OPTION_DIRTY, &dirty)
        }

        func getGridSize() -> (cols: UInt16, rows: UInt16) {
            var cols: UInt16 = 0
            var rows: UInt16 = 0
            ghostty_render_state_get(handle, GHOSTTY_RENDER_STATE_DATA_COLS, &cols)
            ghostty_render_state_get(handle, GHOSTTY_RENDER_STATE_DATA_ROWS, &rows)
            return (cols, rows)
        }

        func getCursor() -> CursorState {
            var inViewport = false
            ghostty_render_state_get(handle, GHOSTTY_RENDER_STATE_DATA_CURSOR_VIEWPORT_HAS_VALUE, &inViewport)

            var x: UInt16 = 0
            var y: UInt16 = 0
            if inViewport {
                ghostty_render_state_get(handle, GHOSTTY_RENDER_STATE_DATA_CURSOR_VIEWPORT_X, &x)
                ghostty_render_state_get(handle, GHOSTTY_RENDER_STATE_DATA_CURSOR_VIEWPORT_Y, &y)
            }

            var visualStyle = GHOSTTY_RENDER_STATE_CURSOR_VISUAL_STYLE_BLOCK
            ghostty_render_state_get(handle, GHOSTTY_RENDER_STATE_DATA_CURSOR_VISUAL_STYLE, &visualStyle)

            var visible = false
            ghostty_render_state_get(handle, GHOSTTY_RENDER_STATE_DATA_CURSOR_VISIBLE, &visible)

            var blinking = false
            ghostty_render_state_get(handle, GHOSTTY_RENDER_STATE_DATA_CURSOR_BLINKING, &blinking)

            let style: CursorStyle = switch visualStyle {
            case GHOSTTY_RENDER_STATE_CURSOR_VISUAL_STYLE_BAR: .bar
            case GHOSTTY_RENDER_STATE_CURSOR_VISUAL_STYLE_BLOCK: .block
            case GHOSTTY_RENDER_STATE_CURSOR_VISUAL_STYLE_UNDERLINE: .underline
            case GHOSTTY_RENDER_STATE_CURSOR_VISUAL_STYLE_BLOCK_HOLLOW: .blockHollow
            default: .block
            }

            return CursorState(
                position: GridPosition(col: Int(x), row: Int(y)),
                style: style,
                visible: visible,
                blinking: blinking,
                inViewport: inViewport
            )
        }

        func getColors() -> ColorPalette {
            var colors = ghostty_init_render_state_colors()
            ghostty_render_state_colors_get(handle, &colors)

            var paletteColors = [RGBColor]()
            paletteColors.reserveCapacity(256)
            withUnsafePointer(to: &colors.palette) { ptr in
                ptr.withMemoryRebound(to: GhosttyColorRgb.self, capacity: 256) { palette in
                    for i in 0..<256 {
                        paletteColors.append(RGBColor(palette[i]))
                    }
                }
            }

            return ColorPalette(
                foreground: RGBColor(colors.foreground),
                background: RGBColor(colors.background),
                cursor: colors.cursor_has_value ? RGBColor(colors.cursor) : nil,
                palette: paletteColors
            )
        }

        func extractSnapshot(terminal: Terminal) -> GridSnapshot? {
            update(from: terminal)

            let dirty = getDirtyState()
            guard dirty != .none else { return nil }

            let (cols, rows) = getGridSize()
            let cursor = getCursor()
            let palette = getColors()

            var rowIter: GhosttyRenderStateRowIterator?
            guard ghostty_render_state_row_iterator_new(nil, &rowIter) == GHOSTTY_SUCCESS,
                  var rowIterVal = rowIter else { return nil }
            defer { ghostty_render_state_row_iterator_free(rowIterVal) }

            ghostty_render_state_get(handle, GHOSTTY_RENDER_STATE_DATA_ROW_ITERATOR, &rowIterVal)

            var rowCells: GhosttyRenderStateRowCells?
            guard ghostty_render_state_row_cells_new(nil, &rowCells) == GHOSTTY_SUCCESS,
                  var rowCellsVal = rowCells else { return nil }
            defer { ghostty_render_state_row_cells_free(rowCellsVal) }

            var cells = [SnapshotCell]()
            cells.reserveCapacity(Int(cols) * Int(rows))

            while ghostty_render_state_row_iterator_next(rowIterVal) {
                ghostty_render_state_row_get(rowIterVal, GHOSTTY_RENDER_STATE_ROW_DATA_CELLS, &rowCellsVal)

                while ghostty_render_state_row_cells_next(rowCellsVal) {
                    cells.append(extractCell(from: rowCellsVal, palette: palette))
                }
            }

            clearDirty()

            return GridSnapshot(
                columns: Int(cols),
                rows: Int(rows),
                cells: cells,
                cursor: cursor,
                palette: palette,
                dirtyState: dirty
            )
        }

        private func extractCell(from cells: GhosttyRenderStateRowCells, palette: ColorPalette) -> SnapshotCell {
            var cell: GhosttyCell = 0
            ghostty_render_state_row_cells_get(cells, GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_RAW, &cell)

            var wideRaw = GHOSTTY_CELL_WIDE_NARROW
            ghostty_cell_get(cell, GHOSTTY_CELL_DATA_WIDE, &wideRaw)
            let wide: CellWide = switch wideRaw {
            case GHOSTTY_CELL_WIDE_NARROW: .narrow
            case GHOSTTY_CELL_WIDE_WIDE: .wide
            case GHOSTTY_CELL_WIDE_SPACER_TAIL: .spacerTail
            case GHOSTTY_CELL_WIDE_SPACER_HEAD: .spacerHead
            default: .narrow
            }

            var style = ghostty_init_style()
            ghostty_render_state_row_cells_get(cells, GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_STYLE, &style)

            var fgColor: RGBColor? = nil
            var fgRgb = GhosttyColorRgb(r: 0, g: 0, b: 0)
            if ghostty_render_state_row_cells_get(cells, GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_FG_COLOR, &fgRgb) == GHOSTTY_SUCCESS {
                fgColor = RGBColor(fgRgb)
            }

            var bgColor: RGBColor? = nil
            var bgRgb = GhosttyColorRgb(r: 0, g: 0, b: 0)
            if ghostty_render_state_row_cells_get(cells, GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_BG_COLOR, &bgRgb) == GHOSTTY_SUCCESS {
                bgColor = RGBColor(bgRgb)
            }

            var graphemeLen: UInt32 = 0
            ghostty_render_state_row_cells_get(cells, GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_GRAPHEMES_LEN, &graphemeLen)

            var scalar: Unicode.Scalar? = nil
            var codepoints: [UInt32]? = nil

            if graphemeLen > 0 {
                var buf = [UInt32](repeating: 0, count: Int(graphemeLen))
                ghostty_render_state_row_cells_get(cells, GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_GRAPHEMES_BUF, &buf)
                if graphemeLen == 1 {
                    scalar = Unicode.Scalar(buf[0])
                } else {
                    scalar = Unicode.Scalar(buf[0])
                    codepoints = buf
                }
            }

            let cellStyle = CellStyle(
                foreground: fgColor,
                background: bgColor,
                bold: style.bold,
                italic: style.italic,
                faint: style.faint,
                underline: UnderlineStyle(rawValue: Int(style.underline)) ?? .none,
                strikethrough: style.strikethrough,
                inverse: style.inverse,
                invisible: style.invisible
            )

            return SnapshotCell(
                codepoint: scalar,
                graphemeCodepoints: codepoints,
                style: cellStyle,
                wideFlag: wide
            )
        }
    }

    // MARK: - Key Encoder

    final class KeyEncoder: @unchecked Sendable {
        let handle: GhosttyKeyEncoder

        init() throws {
            var encoder: GhosttyKeyEncoder?
            try ghosttyCheck(
                ghostty_key_encoder_new(nil, &encoder),
                context: "key_encoder_new"
            )
            guard let encoder else {
                throw GhosttyError.outOfMemory
            }
            self.handle = encoder
        }

        deinit {
            ghostty_key_encoder_free(handle)
        }

        func syncFromTerminal(_ terminal: Terminal) {
            ghostty_key_encoder_setopt_from_terminal(handle, terminal.handle)
        }

        func encode(
            action: GhosttyKeyAction,
            key: GhosttyKey,
            mods: GhosttyMods,
            text: String?
        ) -> [UInt8]? {
            var event: GhosttyKeyEvent?
            guard ghostty_key_event_new(nil, &event) == GHOSTTY_SUCCESS,
                  let event else { return nil }
            defer { ghostty_key_event_free(event) }

            ghostty_key_event_set_action(event, action)
            ghostty_key_event_set_key(event, key)
            ghostty_key_event_set_mods(event, mods)

            // Encode must happen inside withCString — the event borrows the pointer.
            if let text {
                return text.withCString { cstr in
                    ghostty_key_event_set_utf8(event, cstr, text.utf8.count)
                    var buf = [CChar](repeating: 0, count: 128)
                    var written: Int = 0
                    let result = ghostty_key_encoder_encode(handle, event, &buf, buf.count, &written)
                    return (result == GHOSTTY_SUCCESS && written > 0)
                        ? buf.prefix(written).map { UInt8(bitPattern: $0) } : nil
                }
            } else {
                var buf = [CChar](repeating: 0, count: 128)
                var written: Int = 0
                let result = ghostty_key_encoder_encode(handle, event, &buf, buf.count, &written)
                return (result == GHOSTTY_SUCCESS && written > 0)
                    ? buf.prefix(written).map { UInt8(bitPattern: $0) } : nil
            }
        }
    }
}
