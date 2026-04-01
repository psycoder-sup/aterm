---
name: aterm project state
description: Current state of aterm project - M4 workspace features implemented, workspace sidebar redesign spec written.
type: project
---

As of 2026-04-01, aterm has working code through M4 (workspaces). 39 Swift source files across App/, Core/, DragAndDrop/, Input/, Models/, Pane/, Tab/, Utilities/, View/, WindowManagement/ directories. The full ghostty app/surface API migration (WORK-276) is complete.

**Current architecture:** SwiftUI app with NSWindow per workspace. WorkspaceWindowController manages windows with NSEvent keyboard monitor for shortcuts. WorkspaceWindowContent is the main SwiftUI view per window. GhosttyTerminalSurface wraps ghostty_surface_t for terminal rendering. Observable models: WorkspaceManager -> Workspace -> SpaceCollection -> SpaceModel -> TabModel -> PaneViewModel -> SplitTree.

**Workspace sidebar redesign spec written:** docs/feature/workspace-sidebar/workspace-sidebar-spec.md. Replaces WorkspaceIndicatorView + SpaceBarView + WorkspaceSwitcherOverlay with a glassmorphism sidebar. 5 implementation phases. Key technical decisions: per-window SidebarState, terminal surface freeze during toggle animation, multi-binding KeyBindingRegistry, push layout with .ultraThinMaterial.

**Why:** The sidebar consolidates three navigation surfaces into one persistent tree view.

**How to apply:** Future work on navigation should reference the sidebar spec. The sidebar is a view-layer-only change with no data model modifications.
