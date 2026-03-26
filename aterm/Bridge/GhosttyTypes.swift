import Foundation

// MARK: - Error Handling

enum GhosttyError: Error, LocalizedError {
    case outOfMemory
    case invalidValue(String)
    case outOfSpace

    init?(result: GhosttyResult) {
        switch result {
        case GHOSTTY_SUCCESS:
            return nil
        case GHOSTTY_OUT_OF_MEMORY:
            self = .outOfMemory
        case GHOSTTY_INVALID_VALUE:
            self = .invalidValue("")
        case GHOSTTY_OUT_OF_SPACE:
            self = .outOfSpace
        default:
            self = .invalidValue("unknown error code \(result.rawValue)")
        }
    }

    var errorDescription: String? {
        switch self {
        case .outOfMemory: "libghostty-vt: out of memory"
        case .invalidValue(let ctx): "libghostty-vt: invalid value\(ctx.isEmpty ? "" : " (\(ctx))")"
        case .outOfSpace: "libghostty-vt: out of space"
        }
    }
}

@discardableResult
func ghosttyCheck(_ result: GhosttyResult, context: String = "") throws -> GhosttyResult {
    if let error = GhosttyError(result: result) {
        if case .invalidValue = error, !context.isEmpty {
            throw GhosttyError.invalidValue(context)
        }
        throw error
    }
    return result
}

// MARK: - Grid Position

struct GridPosition: Equatable, Hashable, Sendable {
    var col: Int
    var row: Int
}

// MARK: - Cursor

enum CursorStyle: Sendable {
    case bar
    case block
    case underline
    case blockHollow
}

struct CursorState: Sendable {
    let position: GridPosition
    let style: CursorStyle
    let visible: Bool
    let blinking: Bool
    let inViewport: Bool
}

// MARK: - Cell Style

struct CellStyle: Sendable {
    let foreground: RGBColor?
    let background: RGBColor?
    let bold: Bool
    let italic: Bool
    let faint: Bool
    let underline: UnderlineStyle
    let strikethrough: Bool
    let inverse: Bool
    let invisible: Bool
}

enum UnderlineStyle: Int, Sendable {
    case none = 0
    case single = 1
    case double_ = 2
    case curly = 3
    case dotted = 4
    case dashed = 5
}

// MARK: - Color

struct RGBColor: Sendable, Equatable, Hashable {
    let r: UInt8
    let g: UInt8
    let b: UInt8

    init(_ r: UInt8, _ g: UInt8, _ b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(_ c: GhosttyColorRgb) {
        self.r = c.r
        self.g = c.g
        self.b = c.b
    }
}

// MARK: - Cell Width

enum CellWide: Sendable {
    case narrow
    case wide
    case spacerTail
    case spacerHead
}

// MARK: - Dirty State

enum DirtyState: Sendable {
    case none
    case partial
    case full
}

// MARK: - Color Palette

struct ColorPalette: Sendable {
    let foreground: RGBColor
    let background: RGBColor
    let cursor: RGBColor?
    let palette: [RGBColor]
}
