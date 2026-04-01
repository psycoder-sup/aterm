# SPEC: Workspace Sidebar Redesign

**Based on:** docs/feature/workspace-sidebar/workspace-sidebar-prd.md v1.1
**Author:** CTO Agent
**Date:** 2026-04-01
**Version:** 1.0
**Status:** Draft

---

## 1. Overview

This spec covers the replacement of aterm's three horizontal navigation components (WorkspaceIndicatorView, SpaceBarView, WorkspaceSwitcherOverlay) with a single glassmorphism sidebar that displays the current workspace's spaces in a tree. The sidebar uses a push layout (side-by-side with content, not overlay), supports expanded (200pt) and collapsed icon-rail (48pt) modes, and integrates into the existing view hierarchy by replacing the outer VStack in `WorkspaceWindowContent` with an HStack containing the sidebar and a content column. The tab bar (`TabBarView`) remains horizontal at the top of the content column. The terminal surface freeze-and-reflow strategy ensures clean animations without visual artifacts.

The implementation touches four layers of the codebase: the input system (new `KeyAction` cases and bindings), the view hierarchy (new sidebar views, restructured `WorkspaceWindowContent`), the window controller (new keyboard actions, sidebar focus management), and the removal of legacy components.

---

## 2. State Management

### 2.1 New Observable: SidebarState

A new `@Observable` class manages per-window sidebar state. Each `WorkspaceWindowContent` owns one instance via `@State`.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| mode | SidebarMode (enum: .expanded, .collapsed) | .expanded | Current sidebar display mode |
| isAnimating | Bool | false | True during the toggle animation. Used to freeze terminal surface sizing. |
| isDisclosureExpanded | Bool | true | Whether the workspace's disclosure group is expanded or collapsed. In-memory only; resets on app restart. |
| focusTarget | SidebarFocusTarget (enum: .terminal, .sidebar) | .terminal | Tracks whether keyboard focus should be in the sidebar or the terminal. |
| renamingSpaceID | UUID? | nil | The space currently being renamed inline, if any. |

**SidebarMode enum** has two cases: `.expanded` and `.collapsed`. A computed property `width` returns 200.0 for expanded, 48.0 for collapsed.

**SidebarFocusTarget enum** has two cases: `.terminal` and `.sidebar`. When `.sidebar`, arrow key navigation is active in the sidebar. When `.terminal`, keyboard input goes to the terminal pane.

**Why a separate class instead of inline `@State` properties:** The sidebar state is referenced by the sidebar content views, the toggle animation logic, and the keyboard monitor. Grouping it into a single observable object makes dependency tracking cleaner and avoids prop-drilling multiple bindings.

### 2.2 Existing State (No Changes)

The following existing types are read by the sidebar but not modified:

- `Workspace` (name, spaceCollection) -- read from `WorkspaceManager` via `workspaceID`
- `SpaceCollection` (spaces, activeSpaceID, activateSpace, createSpace, removeSpace, reorderSpace) -- the sidebar calls these existing methods
- `SpaceModel` (id, name) -- displayed in sidebar rows

No new data model types are needed. The sidebar is purely a view-layer change that reads from existing observable models.

---

## 3. Type Definitions

### 3.1 New Types

| Type | Kind | Location | Description |
|------|------|----------|-------------|
| SidebarMode | enum | `aterm/View/Sidebar/SidebarState.swift` | Two cases: `.expanded`, `.collapsed`. Computed `width: CGFloat` property. |
| SidebarFocusTarget | enum | `aterm/View/Sidebar/SidebarState.swift` | Two cases: `.terminal`, `.sidebar`. |
| SidebarState | @Observable class | `aterm/View/Sidebar/SidebarState.swift` | Per-window sidebar state as described in section 2.1. |
| SidebarContainerView | SwiftUI View | `aterm/View/Sidebar/SidebarContainerView.swift` | Top-level HStack wrapping the sidebar panel and content column. |
| SidebarPanelView | SwiftUI View | `aterm/View/Sidebar/SidebarPanelView.swift` | The sidebar itself: header with toggle button, workspace disclosure group, space rows. |
| SidebarExpandedContentView | SwiftUI View | `aterm/View/Sidebar/SidebarExpandedContentView.swift` | Content rendered when sidebar is expanded: workspace header, space list, add button. |
| SidebarCollapsedContentView | SwiftUI View | `aterm/View/Sidebar/SidebarCollapsedContentView.swift` | Content rendered when sidebar is collapsed: workspace initial icon. |
| SidebarSpaceRowView | SwiftUI View | `aterm/View/Sidebar/SidebarSpaceRowView.swift` | A single space row within the expanded sidebar. Handles selection, rename, drag, context menu. |
| SidebarWorkspaceHeaderView | SwiftUI View | `aterm/View/Sidebar/SidebarWorkspaceHeaderView.swift` | The workspace disclosure header row with name, triangle, and context menu. |

### 3.2 Modified Types

| Type | Location | Modification |
|------|----------|-------------|
| KeyAction | `aterm/Input/KeyAction.swift` | Add cases: `.toggleSidebar`, `.focusSidebar` |
| KeyBindingRegistry | `aterm/Input/KeyBindingRegistry.swift` | Add bindings for `.toggleSidebar` (Cmd+Shift+S primary, Cmd+Shift+W secondary) and `.focusSidebar` (Cmd+0). Remove `.toggleWorkspaceSwitcher`. |
| WorkspaceWindowContent | `aterm/View/Workspace/WorkspaceWindowContent.swift` | Replace outer VStack with `SidebarContainerView`. Remove `WorkspaceIndicatorView`, `SpaceBarView`, `WorkspaceSwitcherOverlay`. Remove `showWorkspaceSwitcher` state and `.toggleWorkspaceSwitcher` notification listener. |
| WorkspaceWindowController | `aterm/WindowManagement/WorkspaceWindowController.swift` | Update keyboard monitor: replace `.toggleWorkspaceSwitcher` handling with `.toggleSidebar` and `.focusSidebar`. Add sidebar toggle notification. Add window auto-resize logic for narrow windows. |

### 3.3 Removed Types (Phase 5)

| Type | Location | Reason |
|------|----------|--------|
| WorkspaceIndicatorView | `aterm/View/Workspace/WorkspaceIndicatorView.swift` | Replaced by sidebar workspace header |
| SpaceBarView | `aterm/View/SpaceBar/SpaceBarView.swift` | Replaced by sidebar space list |
| SpaceBarItemView | `aterm/View/SpaceBar/SpaceBarItemView.swift` | Replaced by SidebarSpaceRowView |
| WorkspaceSwitcherOverlay | `aterm/View/Workspace/WorkspaceSwitcherOverlay.swift` | Removed entirely (PRD FR-35) |
| SwitcherSearchField | `aterm/View/Workspace/WorkspaceSwitcherOverlay.swift` (private) | Removed with overlay |
| WorkspaceSwitcherRow | `aterm/View/Workspace/WorkspaceSwitcherOverlay.swift` (private) | Removed with overlay |
| Notification.Name.toggleWorkspaceSwitcher | `aterm/View/Workspace/WorkspaceWindowContent.swift` | Replaced by sidebar toggle notification |

---

## 4. View Hierarchy Changes

### 4.1 Current View Hierarchy (Before)

```
WorkspaceWindowContent
  VStack(spacing: 0)
    HStack(spacing: 0)                    -- 28pt bar
      WorkspaceIndicatorView
      Divider
      SpaceBarView
    Divider
    TabBarView                            -- 30pt bar
    ZStack                                -- terminal content
      ForEach(spaces) -> ForEach(tabs)
        SplitTreeView
    .overlay
      WorkspaceSwitcherOverlay (conditional)
```

### 4.2 New View Hierarchy (After)

```
WorkspaceWindowContent
  SidebarContainerView
    HStack(spacing: 0)
      SidebarPanelView                    -- 200pt or 48pt, animated
        .ultraThinMaterial background
        VStack
          SidebarToggleButton             -- top of panel
          if mode == .expanded:
            SidebarExpandedContentView
              SidebarWorkspaceHeaderView  -- disclosure triangle + name
              if isDisclosureExpanded:
                ForEach(spaces)
                  SidebarSpaceRowView     -- name, active highlight, drag, context menu
                SidebarAddSpaceButton     -- "+" within disclosure group
          else:
            SidebarCollapsedContentView
              WorkspaceInitialView        -- circle with 1-2 letter initial
      Divider                             -- vertical, between sidebar and content
      VStack(spacing: 0)                  -- content column
        TabBarView                        -- 30pt, unchanged
        ZStack                            -- terminal content, unchanged
          ForEach(spaces) -> ForEach(tabs)
            SplitTreeView
```

### 4.3 Key Structural Change

The current `WorkspaceWindowContent.body` is a `VStack` with horizontal bars stacked vertically. The new structure wraps everything in an `HStack` via `SidebarContainerView`. The sidebar occupies the left portion; the right portion contains a `VStack` with the `TabBarView` on top and the terminal `ZStack` below.

The `WorkspaceWindowContent` itself becomes thinner: it creates a `SidebarContainerView` and passes down the `workspaceID`, `spaceCollection`, and `workspace` references. The sidebar container owns the `@State` for `SidebarState`.

---

## 5. Component Specifications

### 5.1 SidebarContainerView

**File:** `aterm/View/Sidebar/SidebarContainerView.swift`

**Inputs:**
- `workspaceID: UUID`
- `workspace: Workspace`
- `spaceCollection: SpaceCollection`
- Closure `onNewSpace: () -> Void`
- Closure `onNewTab: () -> Void`

**State:**
- `@State private var sidebarState = SidebarState()`
- `@State private var lastContainerSize: CGSize = .zero` (moved from WorkspaceWindowContent)

**Layout:**
- `HStack(spacing: 0)` containing:
  1. `SidebarPanelView` with `.frame(width: sidebarState.isAnimating ? (pre-animation width) : sidebarState.mode.width)`
  2. A vertical `Divider` (`.separator` color, 1pt)
  3. A `VStack(spacing: 0)` containing:
     - `TabBarView(space: activeSpace) { onNewTab() }` (if active space exists)
     - The terminal `ZStack` (identical to current `WorkspaceWindowContent` body, with `GeometryReader` for container size sync)

**Animation behavior:**
- On toggle, the sidebar width animates via `withAnimation(.easeInOut(duration: 0.2))`.
- During animation (`sidebarState.isAnimating == true`), the terminal `ZStack` frame is pinned to `lastContainerSize` using `.frame(width: lastContainerSize.width, height: lastContainerSize.height)` so the terminal surface does not receive incremental size changes.
- After the animation completes (detected via `DispatchQueue.main.asyncAfter(deadline: .now() + 0.22)` or SwiftUI's `completion:` parameter if available on macOS 26), `isAnimating` is set to `false`, the frame pin is removed, and the terminal surfaces receive their new size via the existing `GeometryReader` -> `syncContainerSize` flow, which triggers `ghostty_surface_set_size`.

**Sidebar toggle notification:**
- Listens for `Notification.Name.toggleSidebar` (scoped to `workspaceID`) to toggle between expanded and collapsed.
- Listens for `Notification.Name.focusSidebar` (scoped to `workspaceID`) to set `sidebarState.focusTarget = .sidebar`.

**Narrow window auto-resize (FR-36):**
- Before expanding the sidebar, check `window.frame.size.width`. If it is less than 600pt, resize the window to 600pt width using `window.setFrame(newFrame, display: true, animate: true)`.
- To access the NSWindow from SwiftUI, use an `NSViewRepresentable` bridge that captures the window reference, or post a notification that `WorkspaceWindowController` handles to perform the resize.
- If the screen cannot accommodate 600pt (check `window.screen?.visibleFrame.width`), the toggle is a no-op and the sidebar remains collapsed.

### 5.2 SidebarPanelView

**File:** `aterm/View/Sidebar/SidebarPanelView.swift`

**Inputs:**
- `workspace: Workspace`
- `spaceCollection: SpaceCollection`
- `@Bindable sidebarState: SidebarState`
- Closure `onNewSpace: () -> Void`

**Layout:**
- `VStack(alignment: .leading, spacing: 0)` with `.background(.ultraThinMaterial)`.
- Top area: toggle button (chevron icon, see section 5.3).
- Below toggle: conditional content based on `sidebarState.mode`:
  - `.expanded`: `SidebarExpandedContentView`
  - `.collapsed`: `SidebarCollapsedContentView`

**Material background:**
- `.background(.ultraThinMaterial)` applied to the VStack.
- The sidebar region should extend under the title bar for a seamless glass effect. Since `titlebarAppearsTransparent` is already `true` in `WorkspaceWindowController` (line 29), the material will blend with the title bar area. The sidebar should use `.edgesIgnoringSafeArea(.top)` (or `.ignoresSafeArea(.container, edges: .top)` on macOS 26) to extend into the title bar.

**Accessibility:**
- Container: `.accessibilityElement(children: .contain)`, `.accessibilityLabel("Workspace sidebar")`

### 5.3 SidebarToggleButton

This is a small view embedded at the top of `SidebarPanelView`, not a separate file.

**Behavior:**
- In expanded mode: shows a left-pointing chevron (`chevron.left`) icon. Clicking collapses the sidebar.
- In collapsed mode: shows a right-pointing chevron (`chevron.right`) icon. Clicking expands the sidebar.
- Positioned at the top-right of the sidebar panel in expanded mode; centered at the top of the icon rail in collapsed mode.

**Dimensions:**
- Frame: 28pt height, full sidebar width.
- Icon: 10pt system font.

**Accessibility:**
- `.accessibilityLabel("Toggle sidebar")`
- `.accessibilityValue(sidebarState.mode == .expanded ? "expanded" : "collapsed")`

### 5.4 SidebarExpandedContentView

**File:** `aterm/View/Sidebar/SidebarExpandedContentView.swift`

**Inputs:**
- `workspace: Workspace`
- `spaceCollection: SpaceCollection`
- `@Bindable sidebarState: SidebarState`
- Closure `onNewSpace: () -> Void`

**Layout:**
- `ScrollView(.vertical, showsIndicators: false)` containing a `VStack(alignment: .leading, spacing: 0)`:
  1. `SidebarWorkspaceHeaderView` (disclosure triangle + workspace name)
  2. If `sidebarState.isDisclosureExpanded`:
     - `ForEach(spaceCollection.spaces)` producing `SidebarSpaceRowView` for each space
     - Add space button ("+") at the bottom of the list

**Keyboard navigation (when focusTarget == .sidebar):**
- Up/Down arrow keys move through the list of items (workspace header + space rows).
- Enter or Space on a space row activates that space and returns focus to terminal.
- Enter or Space on the workspace header toggles disclosure.
- Left arrow on workspace header collapses disclosure. Right arrow expands it.
- Escape returns `sidebarState.focusTarget` to `.terminal`.

This keyboard navigation is implemented by tracking a `@State private var selectedIndex: Int?` within `SidebarExpandedContentView` and handling key events via the keyboard monitor in `WorkspaceWindowController`.

### 5.5 SidebarWorkspaceHeaderView

**File:** `aterm/View/Sidebar/SidebarWorkspaceHeaderView.swift`

**Inputs:**
- `workspace: Workspace`
- `isExpanded: Bool`
- Closure `onToggleDisclosure: () -> Void`
- Closure `onRename: () -> Void`
- Closure `onClose: () -> Void`

**Layout:**
- `HStack(spacing: 6)`:
  1. Disclosure triangle: `Image(systemName: "chevron.right")` rotated 90 degrees when expanded. Animated rotation via `.rotationEffect(.degrees(isExpanded ? 90 : 0))` with `.animation(.easeInOut(duration: 0.15))`.
  2. Workspace name: `Text(workspace.name)` with `.font(.system(size: 12, weight: .semibold))`, `.foregroundStyle(.primary)`, `.lineLimit(1)`.
- Frame height: 28pt.
- Horizontal padding: 12pt.
- Click on the entire row toggles disclosure (calls `onToggleDisclosure`).

**Context menu (FR-28):**
- "Rename" -- triggers workspace rename (sets a renaming state).
- "Close Workspace" -- calls `onClose` which maps to `workspaceManager.deleteWorkspace(id:)`.

**Accessibility:**
- `.accessibilityLabel("\(workspace.name), \(spaceCollection.spaces.count) spaces, \(isExpanded ? "expanded" : "collapsed")")`

### 5.6 SidebarSpaceRowView

**File:** `aterm/View/Sidebar/SidebarSpaceRowView.swift`

**Inputs:**
- `space: SpaceModel`
- `isActive: Bool`
- `isRenaming: Binding<Bool>` (bound to `sidebarState.renamingSpaceID == space.id`)
- Closure `onSelect: () -> Void`
- Closure `onClose: () -> Void`

**Layout:**
- `HStack(spacing: 6)`:
  1. If `isActive`: accent-colored dot (4pt circle, `.accentColor`)
  2. `InlineRenameView(text: space.name, isRenaming: $isRenaming, onCommit: { space.name = $0 })` -- reuses existing component from `aterm/View/Shared/InlineRenameView.swift`.
- Frame height: 26pt.
- Left padding: 28pt (12pt sidebar padding + 16pt disclosure indent).
- Right padding: 12pt.

**Active state highlight (FR-11):**
- When `isActive`, the row background is a `RoundedRectangle(cornerRadius: 4)` filled with `.accentColor.opacity(0.15)`.

**Hover effect:**
- `.onHover` tracks hover state. On hover (when not active), background shows `.quaternary` fill, matching `TabBarItemView` pattern (line 42-45 of `TabBarItemView.swift`).

**Interactions:**
- Single click: calls `onSelect` which maps to `spaceCollection.activateSpace(id: space.id)`. Focus returns to terminal (set `sidebarState.focusTarget = .terminal`). The focus return is handled by `SidebarContainerView` observing `focusTarget` changes.
- Double click: enters rename mode (`isRenaming = true`), following the same double-click detection pattern used in `SpaceBarItemView` (lines 29-36) and `TabBarItemView` (lines 48-55). Uses `lastClickTime` state to detect double-click within 0.3 seconds.
- Click on disclosure triangle (the workspace header): does NOT return focus to terminal (FR-25). This is handled by the header, not the row.

**Context menu (FR-29):**
- "Rename" -- sets `isRenaming = true`.
- "Close Space" -- calls `onClose` which maps to `spaceCollection.removeSpace(id: space.id)`.

**Drag-and-drop (FR-31):**
- `.draggable(SpaceDragItem(spaceID: space.id))` -- uses existing `SpaceDragItem` transferable type from `aterm/DragAndDrop/SpaceDragItem.swift`.
- The parent `ForEach` container has a `.dropDestination(for: SpaceDragItem.self)` that computes the insertion index from the drop location and calls `spaceCollection.reorderSpace(from:to:)`.
- Drop indicator: a thin horizontal line (2pt height, accent color) shown between rows at the computed insertion point.

**Accessibility:**
- `.accessibilityLabel(space.name)`
- `.accessibilityValue(isActive ? "selected" : "not selected")`

### 5.7 SidebarCollapsedContentView

**File:** `aterm/View/Sidebar/SidebarCollapsedContentView.swift`

**Inputs:**
- `workspace: Workspace`
- Closure `onExpand: () -> Void`

**Layout:**
- Centered vertically within the sidebar (or near the top, below the toggle button).
- Workspace initial: first 1-2 letters of `workspace.name`, displayed in `.font(.system(size: 13, weight: .semibold))`, centered within a 32pt circle filled with `.accentColor.opacity(0.2)`.
- The initial extraction logic: take the first character of `workspace.name`. If the name contains a word boundary (space, dash, underscore), also take the first character after the first boundary. Uppercase both. Examples: "proj-a" -> "PA", "default" -> "D", "My Project" -> "MP".

**Interaction:**
- Click on the workspace initial expands the sidebar (calls `onExpand` which toggles `sidebarState.mode` to `.expanded`).

**Accessibility:**
- `.accessibilityLabel("Workspace \(workspace.name), tap to expand sidebar")`

### 5.8 SidebarAddSpaceButton

This is a small view within `SidebarExpandedContentView`, not a separate file.

**Layout:**
- `Button` with `Image(systemName: "plus")`, `.font(.system(size: 9, weight: .medium))`, `.foregroundStyle(.secondary)`.
- Frame height: 26pt, left-padded at 28pt (matching space row indent).
- Positioned as the last item within the disclosure group, below all space rows.

**Behavior:**
- On click: calls `onNewSpace()` which maps to `spaceCollection.createSpace(workingDirectory: ...)`. After creation, the new space becomes active and `sidebarState.renamingSpaceID` is set to the new space's ID to trigger inline rename.

**Accessibility:**
- `.accessibilityLabel("New space in \(workspace.name)")`

---

## 6. Key Binding Changes

### 6.1 New KeyAction Cases

Add to `KeyAction` enum in `aterm/Input/KeyAction.swift`:

| Case | Description |
|------|-------------|
| `.toggleSidebar` | Toggle sidebar between expanded and collapsed modes |
| `.focusSidebar` | Enter keyboard focus into the sidebar (Cmd+0) |

### 6.2 Removed KeyAction Cases

| Case | Replacement |
|------|-------------|
| `.toggleWorkspaceSwitcher` | `.toggleSidebar` (Cmd+Shift+W now toggles sidebar) |

### 6.3 KeyBindingRegistry Changes

In `KeyBindingRegistry.defaults()` at `aterm/Input/KeyBindingRegistry.swift`:

**Remove:**
- The binding for `.toggleWorkspaceSwitcher` (Cmd+Shift+W, line 81-82)

**Add:**
- `.toggleSidebar` bound to Cmd+Shift+S: `KeyBinding(characters: "s", keyCode: nil, modifiers: [.command, .shift])`
- `.focusSidebar` bound to Cmd+0: handled specially in the `action(for:)` method since Cmd+digit is already special-cased for `.goToTab`. Cmd+0 should be checked before the Cmd+1..9 range check. The existing check on line 40-44 tests `digit >= 1 && digit <= 9`, so Cmd+0 falls through to the normal binding lookup. Add: `KeyBinding(characters: "0", keyCode: nil, modifiers: [.command])`

**Repurpose Cmd+Shift+W:**
- Since the PRD specifies Cmd+Shift+W as an alternate sidebar toggle, the `KeyBindingRegistry` needs to support multiple bindings for a single action. The current design is a one-to-one dictionary (`[KeyAction: KeyBinding]`).
- **Approach:** Change the dictionary to `[KeyAction: [KeyBinding]]` (array of bindings per action). Update `action(for:)` to iterate the array. Register two bindings for `.toggleSidebar`: Cmd+Shift+S and Cmd+Shift+W.
- Alternatively, keep the dictionary as-is and add a second entry like `.toggleSidebarAlt` that maps to the same handler. The array approach is cleaner and more extensible for M6 (user-configurable bindings).

### 6.4 WorkspaceWindowController Keyboard Monitor Changes

In `installKeyboardMonitor` at `aterm/WindowManagement/WorkspaceWindowController.swift`:

**Remove:**
- The `.toggleWorkspaceSwitcher` case (lines 119-123)

**Add:**
- `.toggleSidebar`: Post `Notification.Name.toggleSidebar` with `self.workspaceID` as the object. Before posting, check if the window needs auto-resize (FR-36): if expanding and window width < 600pt, resize the window first.
- `.focusSidebar`: Post `Notification.Name.focusSidebar` with `self.workspaceID` as the object.

**Update text field bypass:**
- The existing check on line 84-89 allows `.toggleWorkspaceSwitcher` through when a text field is focused. Change this to allow `.toggleSidebar` and `.focusSidebar` through instead.

---

## 7. Focus Management

### 7.1 Default Focus: Terminal

The terminal pane is the default focus target. After most sidebar interactions, focus returns to the terminal. This is the existing behavior -- `TerminalSurfaceView.becomeFirstResponder()` is called when a pane is focused.

### 7.2 Focus Return After Space Selection (FR-24)

When the user clicks a space row in the sidebar:
1. `spaceCollection.activateSpace(id:)` is called.
2. `sidebarState.focusTarget` is set to `.terminal`.
3. `SidebarContainerView` observes `focusTarget` and, when it changes to `.terminal`, makes the focused pane's `TerminalSurfaceView` first responder by accessing it through the active tab's `PaneViewModel.surfaceView(for: focusedPaneID)` and calling `window.makeFirstResponder(surfaceView)`.
4. The mechanism to access the window from SwiftUI: use a stored `NSWindow?` reference captured via an `NSViewRepresentable` helper that grabs `context.coordinator.view.window` during `updateNSView`.

### 7.3 Focus Stays in Sidebar After Disclosure Toggle (FR-25)

When the user clicks the workspace disclosure triangle, `sidebarState.focusTarget` remains `.sidebar` (if already in sidebar focus) or stays `.terminal` (if the click was a mouse click, not keyboard navigation). Mouse clicks on the disclosure triangle are "fire and forget" for focus -- the responder chain is not changed.

### 7.4 Cmd+0 Enter Sidebar Focus (FR-26)

1. `WorkspaceWindowController` handles `.focusSidebar` by posting a notification.
2. `SidebarContainerView` receives the notification and sets `sidebarState.focusTarget = .sidebar`.
3. When `focusTarget == .sidebar`, the sidebar's selected item index is initialized to 0 (workspace header) and a hidden focusable view within the sidebar becomes first responder. This view intercepts arrow keys and sends them to the sidebar navigation logic.
4. Arrow keys navigate items. Enter activates the selected item (select space or toggle disclosure). Escape sets `focusTarget = .terminal`.

**Implementation of sidebar keyboard focus:** Use a hidden `NSViewRepresentable` containing a custom `NSView` subclass that accepts first responder and overrides `keyDown(with:)` to handle arrow/enter/escape. This is similar to the `SwitcherSearchField` pattern in `WorkspaceSwitcherOverlay.swift` (lines 173-239) but without a text field. The custom view forwards key events to a callback closure that updates `selectedIndex` and handles activation.

### 7.5 Inline Rename Focus (FR-27)

`InlineRenameView` already handles focus correctly:
- On appear, it sets `isFocused = true` (line 23 of `InlineRenameView.swift`).
- On submit (`onSubmit`), it calls `commit()` which sets `isRenaming = false`.
- On escape (`onExitCommand`), it calls `cancel()` which sets `isRenaming = false`.
- When `isRenaming` becomes false, the `InlineRenameView` is replaced by a `Text`, causing the text field to resign first responder.

After rename completes (commit or cancel), `sidebarState.renamingSpaceID` is set to nil, and `sidebarState.focusTarget` is set to `.terminal`, triggering the focus return mechanism from section 7.2.

---

## 8. Animation and Layout

### 8.1 Toggle Animation (FR-19)

The sidebar toggle between expanded and collapsed follows this sequence:

1. **Pre-animation:** Set `sidebarState.isAnimating = true`. Record `lastContainerSize` (the current terminal area size).
2. **Animation:** `withAnimation(.easeInOut(duration: 0.2)) { sidebarState.mode = (mode == .expanded ? .collapsed : .expanded) }`. The sidebar width property is derived from `mode`, so SwiftUI animates the width change.
3. **During animation:** The terminal `ZStack` frame is pinned to `lastContainerSize` via a conditional `.frame()` modifier that is only applied when `isAnimating == true`. This prevents the `GeometryReader` from reporting intermediate sizes, so `ghostty_surface_set_size` is not called during the transition.
4. **Post-animation:** After the animation duration (0.22 seconds, slightly more than the 0.2s animation to account for timing), set `isAnimating = false`. The frame pin is removed, the `GeometryReader` reports the new size, and `syncContainerSize` calls `ghostty_surface_set_size` on all visible surfaces. This results in a single SIGWINCH with the final dimensions.

### 8.2 Debounce Rapid Toggle

If the user presses Cmd+Shift+S while `sidebarState.isAnimating == true`, the toggle is ignored. This prevents overlapping animations. The check is in `SidebarState` method `toggle()`:

```
If isAnimating, return immediately without changing mode.
```

### 8.3 Terminal Surface Freeze Detail

The freeze works by controlling when `syncContainerSize` fires:
- `syncContainerSize` is called from a `GeometryReader.onChange(of: size)` callback.
- During animation, the terminal ZStack's frame is explicitly set to `lastContainerSize`, so the `GeometryReader` inside it reports the same size throughout.
- After animation, the explicit frame is removed, the ZStack fills the available space, and `GeometryReader` reports the new size, triggering one `syncContainerSize` -> one `ghostty_surface_set_size` -> one SIGWINCH.

### 8.4 Window Auto-Resize (FR-36)

When toggling from collapsed to expanded, the content area needs at least ~400pt of width (for a usable terminal). With a 200pt sidebar, the minimum window width is ~600pt.

The auto-resize logic lives in `WorkspaceWindowController` and is triggered by the `.toggleSidebar` notification handler:

1. Check current sidebar mode (passed in notification userInfo or queried via a shared reference).
2. If expanding (current mode is collapsed):
   a. Let `minWidth = 600.0`
   b. Let `windowWidth = window.frame.size.width`
   c. If `windowWidth < minWidth`:
      - Let `screenWidth = window.screen?.visibleFrame.width ?? 0`
      - If `screenWidth >= minWidth`: resize window to `minWidth`, keeping the origin or adjusting to stay on screen.
      - Else: do not toggle (sidebar remains collapsed).
3. Post the toggle notification to the view layer.

---

## 9. Navigation

### 9.1 Sidebar Toggle (FR-17, FR-18)

| Trigger | Action |
|---------|--------|
| Cmd+Shift+S | Toggle sidebar expanded/collapsed |
| Cmd+Shift+W | Toggle sidebar expanded/collapsed (alternate, repurposed) |
| Toggle button click | Toggle sidebar expanded/collapsed |
| Click workspace icon in collapsed rail | Expand sidebar |

### 9.2 Space Selection (FR-20)

| Trigger | Action |
|---------|--------|
| Click space row | `spaceCollection.activateSpace(id:)`, return focus to terminal |
| Enter on space row (sidebar keyboard focus) | Same as click |

### 9.3 Existing Shortcuts (FR-22)

All existing keyboard shortcuts continue to work. The sidebar's visual state (active space highlight) automatically updates because it reads from the observable `spaceCollection.activeSpaceID`.

| Shortcut | Action | Sidebar effect |
|----------|--------|----------------|
| Cmd+Shift+Right | `spaceCollection.nextSpace()` | Active highlight moves to next space |
| Cmd+Shift+Left | `spaceCollection.previousSpace()` | Active highlight moves to previous space |
| Cmd+Shift+T | `spaceCollection.createSpace(...)` | New space row appears in sidebar |
| Cmd+Shift+N | `workspaceManager.createWorkspace(...)` | New window opens (no sidebar effect in current window) |
| Cmd+Shift+Backspace | `workspaceManager.deleteWorkspace(...)` | Window closes |

### 9.4 Sidebar Keyboard Navigation (FR-26)

| Shortcut | Action |
|----------|--------|
| Cmd+0 | Enter sidebar keyboard focus |
| Up arrow (in sidebar focus) | Move selection up |
| Down arrow (in sidebar focus) | Move selection down |
| Enter/Space (in sidebar focus on space row) | Activate space, return focus to terminal |
| Enter/Space (in sidebar focus on workspace header) | Toggle disclosure |
| Left arrow (in sidebar focus on workspace header) | Collapse disclosure |
| Right arrow (in sidebar focus on workspace header) | Expand disclosure |
| Escape (in sidebar focus) | Return focus to terminal |

---

## 10. Context Menu Implementation

### 10.1 Workspace Header Context Menu (FR-28)

Applied to `SidebarWorkspaceHeaderView` via `.contextMenu`:

| Item | Action |
|------|--------|
| Rename | Enter inline rename mode for the workspace name. Use `InlineRenameView` with the workspace name. On commit: `workspaceManager.renameWorkspace(id:newName:)`. |
| Close Workspace | Call `workspaceManager.deleteWorkspace(id: workspace.id)`. |

### 10.2 Space Row Context Menu (FR-29)

Applied to `SidebarSpaceRowView` via `.contextMenu`:

| Item | Action |
|------|--------|
| Rename | Set `sidebarState.renamingSpaceID = space.id`, triggering `InlineRenameView` in the row. |
| Close Space | Call `spaceCollection.removeSpace(id: space.id)`. |

---

## 11. Drag-and-Drop Implementation

### 11.1 Space Reorder (FR-31, FR-32)

**Drag source:** Each `SidebarSpaceRowView` is marked as `.draggable(SpaceDragItem(spaceID: space.id))`, reusing the existing `SpaceDragItem` transferable type from `aterm/DragAndDrop/SpaceDragItem.swift`.

**Drop target:** The space list container (the `ForEach` within `SidebarExpandedContentView`) uses `.dropDestination(for: SpaceDragItem.self)` to accept drops. The drop handler:

1. Extracts the `spaceID` from the dropped `SpaceDragItem`.
2. Finds the source index in `spaceCollection.spaces`.
3. Computes the destination index from the drop location (Y position relative to row positions).
4. Calls `spaceCollection.reorderSpace(from: sourceIndex, to: destinationIndex)`.

**Drop indicator:** A thin insertion line (2pt height, accent color) rendered between rows at the computed drop position. This can be implemented with a `@State private var dropIndex: Int?` that is set during the drop targeting phase and cleared on drop or exit.

**Cross-workspace prevention (FR-32):** Since the sidebar only shows the current workspace's spaces, and `SpaceDragItem` only carries a `spaceID` (no workspace context), the drop handler validates that the `spaceID` exists in the current `spaceCollection.spaces` before accepting.

### 11.2 Cancel Drag on Sidebar Toggle

If a drag-and-drop is in progress when the sidebar toggle is triggered, the drag must be cancelled. SwiftUI does not provide a direct API to cancel an in-progress drag. The pragmatic approach is to guard the toggle: if `dropIndex != nil` (indicating an active drop session), ignore the toggle request.

---

## 12. Notifications

### 12.1 New Notification Names

These replace `Notification.Name.toggleWorkspaceSwitcher`:

| Name | Object | Purpose |
|------|--------|---------|
| `.toggleSidebar` | `UUID` (workspaceID) | Tells the SidebarContainerView for the given workspace to toggle sidebar mode. |
| `.focusSidebar` | `UUID` (workspaceID) | Tells the SidebarContainerView for the given workspace to enter sidebar keyboard focus. |

### 12.2 Removed Notification Names

| Name | Removed In |
|------|-----------|
| `.toggleWorkspaceSwitcher` | Phase 5 (replaced by `.toggleSidebar`) |

---

## 13. Accessibility

### 13.1 Labels and Roles

| Element | Label | Role / Value |
|---------|-------|------|
| Sidebar container | "Workspace sidebar" | `.contain` children |
| Workspace header row | "[name], [N] spaces, [expanded/collapsed]" | Activates on click |
| Space row | "[name]" | Value: "selected" or "not selected" |
| Toggle button | "Toggle sidebar" | Value: "expanded" or "collapsed" |
| Add space button | "New space in [workspace name]" | Button |
| Collapsed workspace icon | "Workspace [name], tap to expand sidebar" | Button |

### 13.2 Keyboard Accessibility

All sidebar items reachable via Cmd+0 + arrow keys. All actions available via context menu. Escape always returns to terminal.

### 13.3 VoiceOver

The sidebar list should use `List` semantics or explicitly set `.accessibilityElement(children: .contain)` on the scroll view. Each row should be an individual accessibility element. The disclosure state should be communicated via the workspace header's label.

---

## 14. Performance Considerations

### 14.1 Terminal Reflow

The most performance-sensitive aspect is the sidebar toggle animation. By freezing the terminal surface during animation and sending a single SIGWINCH after completion, we avoid:
- Multiple ghostty_surface_set_size calls during the 200ms animation
- Multiple terminal reflows (each reflow re-renders the entire visible buffer)
- Visible text "jumping" as the terminal width changes incrementally

### 14.2 Observable Updates

The sidebar reads from `spaceCollection.spaces` and `spaceCollection.activeSpaceID`, both of which are `@Observable` properties. SwiftUI will efficiently diff the space list. Since workspaces typically have fewer than 10 spaces, there is no need for lazy loading or virtualization.

### 14.3 Material Background

`.ultraThinMaterial` uses a `CABackdropLayer` under the hood, which composites in the window server. This is hardware-accelerated and has negligible CPU cost. However, it may cause slight frame drops on very old hardware during sidebar toggle animation. This is acceptable for a macOS 26 target.

### 14.4 Drag-and-Drop

The existing `SpaceDragItem` is a lightweight `Codable` struct containing only a UUID. No performance concerns.

---

## 15. File Organization

### 15.1 New Directory

```
aterm/View/Sidebar/
  SidebarState.swift              -- SidebarMode, SidebarFocusTarget, SidebarState
  SidebarContainerView.swift      -- HStack layout: sidebar + content column
  SidebarPanelView.swift          -- Sidebar panel with material background
  SidebarExpandedContentView.swift -- Expanded mode: workspace tree
  SidebarCollapsedContentView.swift -- Collapsed mode: icon rail
  SidebarSpaceRowView.swift       -- Individual space row
  SidebarWorkspaceHeaderView.swift -- Workspace disclosure header
```

### 15.2 Modified Files

```
aterm/Input/KeyAction.swift               -- Add .toggleSidebar, .focusSidebar; remove .toggleWorkspaceSwitcher
aterm/Input/KeyBindingRegistry.swift       -- Update bindings (multi-binding support, new actions)
aterm/View/Workspace/WorkspaceWindowContent.swift -- Replace VStack with SidebarContainerView
aterm/WindowManagement/WorkspaceWindowController.swift -- Update keyboard monitor, add window resize logic
```

### 15.3 Deleted Files (Phase 5)

```
aterm/View/Workspace/WorkspaceIndicatorView.swift
aterm/View/SpaceBar/SpaceBarView.swift
aterm/View/SpaceBar/SpaceBarItemView.swift
aterm/View/Workspace/WorkspaceSwitcherOverlay.swift  (entire file, includes SwitcherSearchField and WorkspaceSwitcherRow)
```

---

## 16. Implementation Phases

### Phase 1: Sidebar Shell and Layout

**Goal:** Establish the sidebar container, push layout, toggle, and material background. No workspace/space content yet.

**Files to create:**
1. `aterm/View/Sidebar/SidebarState.swift` -- `SidebarMode` enum, `SidebarFocusTarget` enum, `SidebarState` class with `mode`, `isAnimating`, `isDisclosureExpanded`, `focusTarget`, `renamingSpaceID`.
2. `aterm/View/Sidebar/SidebarContainerView.swift` -- `HStack` layout with sidebar panel (colored placeholder) and content column. Terminal freeze/unfreeze during animation. Notification listeners for `.toggleSidebar` and `.focusSidebar`.
3. `aterm/View/Sidebar/SidebarPanelView.swift` -- Material background panel with toggle button. Placeholder content.

**Files to modify:**
4. `aterm/Input/KeyAction.swift` -- Add `.toggleSidebar` and `.focusSidebar` cases. Keep `.toggleWorkspaceSwitcher` for now (removed in Phase 5).
5. `aterm/Input/KeyBindingRegistry.swift` -- Change dictionary type to `[KeyAction: [KeyBinding]]`. Add `.toggleSidebar` bindings (Cmd+Shift+S, Cmd+Shift+W). Add `.focusSidebar` binding (Cmd+0). Remove `.toggleWorkspaceSwitcher` binding.
6. `aterm/View/Workspace/WorkspaceWindowContent.swift` -- Replace the outer `VStack` body with `SidebarContainerView`. Move the `lastContainerSize` state and `syncContainerSize` logic into `SidebarContainerView`. Remove the `showWorkspaceSwitcher` state and the `.overlay` for `WorkspaceSwitcherOverlay`. Remove the `.onReceive` for `.toggleWorkspaceSwitcher`. Keep `WorkspaceIndicatorView` and `SpaceBarView` temporarily (they will live inside the content column until Phase 5 removes them, but for Phase 1 they can be removed from the layout since the sidebar placeholder replaces them).
7. `aterm/WindowManagement/WorkspaceWindowController.swift` -- Update the keyboard monitor switch statement: replace `.toggleWorkspaceSwitcher` with `.toggleSidebar` (post `.toggleSidebar` notification) and add `.focusSidebar` (post `.focusSidebar` notification). Add the window auto-resize logic (FR-36) before posting the toggle notification. Update the text-field bypass check.

**Validation:** Sidebar panel visible with material blur. Toggle animates between 200pt and 48pt. Terminal reflows correctly after toggle (check with `tput cols` before and after). Narrow window auto-resizes on expand. Keyboard shortcut Cmd+Shift+S and Cmd+Shift+W both work.

### Phase 2: Sidebar Content -- Expanded Mode

**Goal:** Populate the sidebar with workspace and space tree. Space selection and disclosure toggle.

**Files to create:**
1. `aterm/View/Sidebar/SidebarExpandedContentView.swift` -- `ScrollView` with workspace header and space rows. Disclosure state toggle. Add space button.
2. `aterm/View/Sidebar/SidebarWorkspaceHeaderView.swift` -- Disclosure triangle, workspace name, click-to-toggle.
3. `aterm/View/Sidebar/SidebarSpaceRowView.swift` -- Space name, active highlight, click-to-select, hover effect.

**Files to modify:**
4. `aterm/View/Sidebar/SidebarPanelView.swift` -- Replace placeholder with `SidebarExpandedContentView` / `SidebarCollapsedContentView` (collapsed content can be a placeholder for now).
5. `aterm/View/Sidebar/SidebarContainerView.swift` -- Wire focus return: observe `sidebarState.focusTarget` changes and make the terminal first responder when it changes to `.terminal`.

**Validation:** Workspace header with disclosure triangle. Space rows with active highlight. Clicking a space activates it and updates the tab bar. Disclosure toggle works. "+" creates a new space. Focus returns to terminal after space selection. Cmd+0 enters sidebar keyboard focus, arrow keys navigate, Escape returns to terminal.

### Phase 3: Context Menus, Rename, Drag-and-Drop

**Goal:** Full interaction parity with the components being replaced.

**Files to modify:**
1. `aterm/View/Sidebar/SidebarWorkspaceHeaderView.swift` -- Add `.contextMenu` with Rename and Close Workspace. Add `InlineRenameView` for workspace rename.
2. `aterm/View/Sidebar/SidebarSpaceRowView.swift` -- Add `.contextMenu` with Rename and Close Space. Add double-click-to-rename. Wire `InlineRenameView` to `sidebarState.renamingSpaceID`.
3. `aterm/View/Sidebar/SidebarExpandedContentView.swift` -- Add `.dropDestination` for space reorder. Implement drop indicator rendering.

**Validation:** Right-click workspace header shows Rename + Close. Right-click space row shows Rename + Close Space. Double-click space name enters rename mode. Enter commits, Escape cancels. Rename focus returns to terminal. Drag-and-drop reorders spaces correctly. Drop indicator visible during drag.

### Phase 4: Collapsed Icon Rail Mode

**Goal:** Implement the icon-rail collapsed state.

**Files to create:**
1. `aterm/View/Sidebar/SidebarCollapsedContentView.swift` -- Workspace initial in an accent-colored circle. Click to expand.

**Files to modify:**
2. `aterm/View/Sidebar/SidebarPanelView.swift` -- Conditional rendering between expanded and collapsed content.

**Validation:** Collapsed mode shows workspace initial (e.g., "PA" for "proj-a"). Clicking the initial expands the sidebar. Toggle button visual updates for both modes.

### Phase 5: Cleanup and Removal of Old Components

**Goal:** Remove legacy components. This phase should be a single commit for easy revert.

**Files to delete:**
1. `aterm/View/Workspace/WorkspaceIndicatorView.swift`
2. `aterm/View/SpaceBar/SpaceBarView.swift`
3. `aterm/View/SpaceBar/SpaceBarItemView.swift`
4. `aterm/View/Workspace/WorkspaceSwitcherOverlay.swift`

**Files to modify:**
5. `aterm/Input/KeyAction.swift` -- Remove `.toggleWorkspaceSwitcher` case if it was kept as a transitional alias.
6. `aterm/View/Workspace/WorkspaceWindowContent.swift` -- Remove any remaining references to removed components. Remove `Notification.Name.toggleWorkspaceSwitcher` extension.
7. `aterm/App/WorkspaceCommands.swift` -- No changes needed (workspace commands are independent of the sidebar).

**Validation:** Build succeeds with no references to removed types. All keyboard shortcuts work (Cmd+Shift+W toggles sidebar, not switcher). All navigation works through the sidebar. Run accessibility audit (VoiceOver walkthrough).

---

## 17. Testing Strategy

### 17.1 Unit Tests

| Test | What to Verify |
|------|---------------|
| SidebarMode.width | `.expanded` returns 200.0, `.collapsed` returns 48.0 |
| SidebarState.toggle() | Mode toggles. Returns early if `isAnimating == true`. |
| Workspace initial extraction | "proj-a" -> "PA", "default" -> "D", "My Project" -> "MP", "" -> "", "x" -> "X" |
| KeyBindingRegistry multi-binding | `.toggleSidebar` matches both Cmd+Shift+S and Cmd+Shift+W events |
| KeyBindingRegistry Cmd+0 | `.focusSidebar` matches Cmd+0 event, does not interfere with Cmd+1..9 |

### 17.2 Integration Tests (Manual)

| Test | Steps | Expected |
|------|-------|----------|
| Sidebar toggle | Press Cmd+Shift+S | Sidebar animates from expanded to collapsed (or vice versa). Terminal reflows once after animation. `tput cols` shows correct column count. |
| Space selection | Click a space in sidebar | Tab bar updates, terminal content changes, focus returns to terminal (can type immediately). |
| Disclosure toggle | Click workspace disclosure triangle | Space list appears/disappears. Focus does not leave terminal. |
| Create space from sidebar | Click "+" in sidebar | New space created, inline rename active, type name, press Enter. Terminal shows in new space. |
| Rename space | Double-click space name | Inline text field appears. Type new name, Enter. Name updates. Focus returns to terminal. |
| Context menu | Right-click space row | Menu shows "Rename" and "Close Space". Both work. |
| Drag-and-drop reorder | Drag a space row to a new position | Drop indicator shows. On drop, space list reorders. |
| Collapsed mode | Toggle to collapsed | Icon rail shows workspace initial. Click initial expands sidebar. |
| Cmd+0 sidebar focus | Press Cmd+0 | Sidebar items navigable with arrow keys. Enter selects. Escape returns to terminal. |
| Narrow window expand | Resize window to 500pt width, press Cmd+Shift+S to expand | Window auto-resizes to 600pt. |
| Rapid toggle | Press Cmd+Shift+S rapidly 5 times | No crash, no overlapping animations, sidebar ends in a clean state. |
| Material blur | Move aterm window over desktop wallpaper | Sidebar shows blurred wallpaper through the material. Works in both light and dark mode. |

### 17.3 Edge Cases to Test

| Case | Expected Behavior |
|------|-------------------|
| Single workspace, single space | Sidebar shows one workspace with one space. "+" is visible. |
| Very long space name | Truncated with ellipsis at 200pt sidebar width. Full name in tooltip. |
| 15+ spaces in one workspace | Sidebar scrolls vertically. All spaces accessible. |
| Toggle during inline rename | Rename is committed (or cancelled) before animation starts. |
| Close active space from context menu | Next space becomes active. Sidebar highlight updates. |
| Close last space (cascading close) | Workspace closes, window closes. |
| Full-screen mode | Sidebar behaves identically to windowed mode. |

---

## 18. Technical Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| Terminal surface receives intermediate sizes during animation despite freeze | Visual artifacts (text reflow stutter) | Medium | Pin the terminal ZStack frame to a fixed size during animation. Test thoroughly with split panes. If GeometryReader still fires, use an explicit NSView frame override. |
| `.ultraThinMaterial` does not show blur when window background is opaque | Sidebar appears solid instead of glass | Medium | The window's `backgroundColor` is `.terminalBackground` (line 30 of WorkspaceWindowController). If this color is opaque, the material may not blur. Set the window background to `.clear` for the sidebar region, or use `NSVisualEffectView` directly for more control. Test with dark and light themes. |
| SwiftUI animation completion timing is not exact | `isAnimating` flag cleared too early or late, causing brief terminal reflow glitch | Low | Use `DispatchQueue.main.asyncAfter(deadline: .now() + 0.22)` with a small margin. On macOS 26, SwiftUI's `withAnimation(.easeInOut(duration: 0.2)) { } completion: { }` may be available and is preferable. |
| Multi-binding KeyBindingRegistry breaks existing shortcuts | Tab shortcuts or other bindings stop working | Low | The change from `[KeyAction: KeyBinding]` to `[KeyAction: [KeyBinding]]` must update all existing binding registrations to wrap single bindings in arrays. Unit test all existing bindings. |
| Focus management conflict between sidebar and terminal | Keyboard input goes to wrong target after sidebar interaction | Medium | Explicit `window.makeFirstResponder(surfaceView)` calls after every sidebar interaction that should return focus. Test with split panes (multiple TerminalSurfaceViews). |
| Sidebar toggle from collapsed with many split panes causes layout thrash | All pane surfaces resize simultaneously | Low | The freeze mechanism prevents this. The single SIGWINCH after animation is unavoidable but happens in a single frame. |

---

## 19. Open Technical Questions

| # | Question | Context | Impact if Unresolved |
|---|----------|---------|---------------------|
| 1 | Should sidebar state (expanded/collapsed) be per-window or global? | PRD Open Question #1. Per-window means each workspace can have its own preference. Global means toggling in one window toggles all. | If per-window: `SidebarState` is `@State` in `SidebarContainerView` (current design). If global: `SidebarState` becomes a property on `WorkspaceManager` or a shared singleton. The current design is per-window. Switch to global by moving `SidebarState` to `WorkspaceManager` and passing it as environment. |
| 2 | Should the workspace disclosure group auto-collapse when sidebar collapses? | PRD Open Question #3. If auto-collapse, expanding sidebar always shows collapsed workspace. If remember, user sees the space list immediately on expand. | Current spec preserves disclosure state across toggles (does not auto-collapse). This matches user expectation: "I collapsed the sidebar to save space, not to hide the space list." |
| 3 | Does macOS 26 SwiftUI provide `withAnimation completion:` for reliable post-animation callbacks? | The spec uses `asyncAfter` as a fallback. A completion handler would be more reliable. | If available, use it instead of `asyncAfter`. If not, the 20ms margin on `asyncAfter` is sufficient. |
| 4 | Does `.ultraThinMaterial` compose correctly over `.terminalBackground` window background? | The window background is set to `.terminalBackground` (a dynamic NSColor). If it is fully opaque, the material blur may not show through. | Test during Phase 1. If the blur does not work, either make the window background transparent in the sidebar region (using a split content view approach) or use `NSVisualEffectView` as a fallback. |
| 5 | How to make the terminal pane first responder from SwiftUI after a sidebar click? | SwiftUI does not directly expose `window.makeFirstResponder`. The current `TerminalContentView` handles this via `updateNSView`, but that requires the `isFocused` prop to change. | Use the existing pattern: when `sidebarState.focusTarget` changes to `.terminal`, update the `isFocused` flag on the visible `PaneView`, which triggers `TerminalContentView.updateNSView` to call `window.makeFirstResponder`. Alternatively, post a notification that `WorkspaceWindowController` handles. |
