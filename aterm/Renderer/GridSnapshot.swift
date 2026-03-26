import AppKit

struct GridSnapshot: Sendable {
    let columns: Int
    let rows: Int
    let cells: [SnapshotCell]
    let cursor: CursorState
    let palette: ColorPalette
    let dirtyState: DirtyState

    func cell(at position: GridPosition) -> SnapshotCell? {
        guard position.col >= 0, position.col < columns,
              position.row >= 0, position.row < rows else { return nil }
        let index = position.row * columns + position.col
        guard index < cells.count else { return nil }
        return cells[index]
    }

    func toAttributedString(font: NSFont) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let defaultFG = palette.foreground
        let defaultBG = palette.background

        // Pre-compute font variants and cache colors to avoid per-cell allocations
        let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        let italicFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        let boldItalicFont = NSFontManager.shared.convert(boldFont, toHaveTrait: .italicFontMask)
        var colorCache = [RGBColor: NSColor]()

        func cachedColor(_ c: RGBColor) -> NSColor {
            if let cached = colorCache[c] { return cached }
            let nsColor = NSColor(
                red: CGFloat(c.r) / 255.0,
                green: CGFloat(c.g) / 255.0,
                blue: CGFloat(c.b) / 255.0,
                alpha: 1.0
            )
            colorCache[c] = nsColor
            return nsColor
        }

        result.beginEditing()
        for row in 0..<rows {
            if row > 0 {
                result.append(NSAttributedString(string: "\n"))
            }
            for col in 0..<columns {
                let index = row * columns + col
                guard index < cells.count else { continue }
                let cell = cells[index]

                if cell.wideFlag == .spacerTail || cell.wideFlag == .spacerHead {
                    continue
                }

                let text: String
                if let codepoints = cell.graphemeCodepoints, !codepoints.isEmpty {
                    text = String(codepoints.compactMap { Unicode.Scalar($0) }.map { Character($0) })
                } else if let scalar = cell.codepoint {
                    text = String(scalar)
                } else {
                    text = " "
                }

                let style = cell.style
                var fg = style.foreground ?? defaultFG
                var bg = style.background ?? defaultBG
                if style.inverse { swap(&fg, &bg) }
                if style.faint { fg = RGBColor(fg.r / 2, fg.g / 2, fg.b / 2) }

                let effectiveFont: NSFont = switch (style.bold, style.italic) {
                case (true, true): boldItalicFont
                case (true, false): boldFont
                case (false, true): italicFont
                case (false, false): font
                }

                var attrs: [NSAttributedString.Key: Any] = [
                    .font: effectiveFont,
                    .foregroundColor: style.invisible ? cachedColor(bg) : cachedColor(fg),
                ]
                if bg != defaultBG || style.inverse {
                    attrs[.backgroundColor] = cachedColor(bg)
                }
                if style.strikethrough {
                    attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                }
                if style.underline != .none {
                    attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
                }

                result.append(NSAttributedString(string: text, attributes: attrs))
            }
        }
        result.endEditing()

        return result
    }

}

struct SnapshotCell: Sendable {
    let codepoint: Unicode.Scalar?
    let graphemeCodepoints: [UInt32]?
    let style: CellStyle
    let wideFlag: CellWide
}
