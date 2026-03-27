# aterm

A native macOS terminal emulator built with SwiftUI. Uses the full ghostty embedding API (`ghostty_app_t` / `ghostty_surface_t`) from the Ghostty project. Ghostty handles PTY, VT parsing, Metal rendering, font atlas, cursor, selection, scrollback, and color themes internally. aterm provides the NSView + CAMetalLayer and forwards keyboard/mouse events.

## Target

- **Platform:** macOS 26

## Architecture

- **App** — `AtermApp` (SwiftUI entry point, GhosttyApp init), `TerminalWindow` (surface lifecycle, title/close handling)
- **Core** — `GhosttyApp` (singleton wrapping `ghostty_app_t`, runtime callbacks, clipboard, tick), `GhosttyTerminalSurface` (per-terminal `ghostty_surface_t` wrapper), `ANSIStripper` (utility)
- **View** — `TerminalContentView` (NSViewRepresentable), `TerminalSurfaceView` (NSView + CAMetalLayer, keyboard/mouse/IME forwarding to ghostty surface)
- **Utilities** — `Logger`, `Colors`
- **Vendor** — `GhosttyKit.xcframework` + `ghostty.h` (built from `.ghostty-src` via `scripts/build-ghostty.sh`)

## Build

Run `scripts/build-ghostty.sh` to build and vendor GhosttyKit.xcframework from the ghostty source. Requires `zig` (`brew install zig`).
