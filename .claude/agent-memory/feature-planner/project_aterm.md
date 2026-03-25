---
name: aterm project context
description: Core product decisions for aterm - macOS terminal emulator built with Swift, libghostty, Metal. Personal tool for the developer.
type: project
---

aterm is a GPU-accelerated macOS terminal emulator. Key decisions: Swift + SwiftUI for app chrome, libghostty-vt (Zig, C ABI) for VT parsing/terminal state, Metal for GPU rendering (font atlas + instanced cell rendering), POSIX PTY. macOS 26+ only.

Primary differentiators: (1) 4-level workspace hierarchy (Workspace > Space > Tab > Pane) for project-oriented terminal management, (2) more customizable than Ghostty (themes, profiles, extensibility).

Workspace model: Workspace = project, Space = branch/worktree, Tab = standard tabs, Pane = splits. All persist across app launches. Navigation uses chord-based shortcuts (Cmd+Shift+...), no leader key.

v1 bar: full workspace/space/tab/pane model working + persistent sessions + fast GPU rendering. Must be daily-drivable before shipping.

**Why:** Ghostty lacks workspace/space concepts, has limited customizability, and no session persistence. Developer wants native macOS integration to replace tmux-style workflows.

**How to apply:** All feature planning should respect: macOS-only, keyboard-driven, no plugin system in v1, no telemetry. PRD lives at docs/feature/aterm/aterm-prd.md. Doc structure: docs/feature/[feature-name]/[feature-name]-prd.md.
