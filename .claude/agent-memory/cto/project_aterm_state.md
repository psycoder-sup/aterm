---
name: aterm project state
description: Current state of aterm project - M1 code exists, migrating from libghostty-vt to full ghostty app/surface API (WORK-276).
type: project
---

As of 2026-03-26, aterm has working M1 code: a single-window terminal with custom Metal rendering, PTY management, and libghostty-vt bridge. 18 Swift source files exist across App/, Core/, Bridge/, Renderer/, View/, Utilities/ directories.

**Major architectural change in progress (WORK-276):** Migrating from libghostty-vt (low-level VT parsing only) + custom Metal rendering to the full ghostty app/surface API. This replaces ~14 files (PTY, renderer, bridge, font atlas, shaders) with a thin wrapper around ghostty_app_t/ghostty_surface_t. Ghostty handles PTY, VT parsing, Metal rendering, font atlas, cursor, selection, scrollback, and themes internally.

Migration spec written: docs/spec/WORK-276-ghostty-migration.md

Key facts:
- .ghostty-src directory contains a shallow clone of Ghostty source (for building libghostty)
- cmux at /tmp/cmux is the reference implementation for the ghostty app/surface API
- cmux uses GhosttyKit.xcframework for linking
- ghostty.h (single header) replaces the ghostty/vt.h header tree

**Why:** The full ghostty API dramatically simplifies the codebase and provides production-grade rendering quality.

**How to apply:** All future M1 work should target the post-migration architecture (ghostty app/surface API, not libghostty-vt).
