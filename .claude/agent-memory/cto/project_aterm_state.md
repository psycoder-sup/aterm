---
name: aterm project state
description: Current state of aterm project - greenfield, no code yet, PRD approved at v1.4, all 7 milestone specs written and validated 2026-03-24.
type: project
---

As of 2026-03-24, aterm is a greenfield project with no source code. Only documentation exists: PRD v1.4 at docs/feature/aterm/aterm-prd.md.

Tech stack: Swift + SwiftUI (app chrome), libghostty-vt (VT parsing, C ABI from Zig), Metal (GPU rendering), POSIX PTY, macOS 26+.

All 7 milestone specs (M1-M7) have been written and validated. Validation issues resolved on 2026-03-24:
- Keybindings: Cmd+W = pane close (cascading), Cmd+Shift+W = workspace switcher, no keyboard resize
- Type naming: PaneNode (enum with .leaf and .split cases) is the canonical name across all specs
- JSON schema: binary tree format (first/second, not children array) in M5
- Window geometry + is_fullscreen persisted per workspace in M5
- Last-workspace-close quits app (no default workspace creation)
- FR-01 workspace reorder via drag-and-drop added to M4

**Why:** Understanding project maturity prevents assuming existing code patterns when none exist yet.

**How to apply:** When implementing, follow the conventions established in the specs. All cross-spec references are now consistent.
