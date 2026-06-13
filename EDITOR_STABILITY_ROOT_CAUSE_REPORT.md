# Editor Stability Root Cause Report

## Scope

This report covers the keyboard-induced layout shift, editor jumping, and viewport jank in the note editor screen.

Primary code path:

- [lib/features/notes/presentation/screens/note_editor_screen.dart](/d:/cloned%20projects/THINKNOTE/lib/features/notes/presentation/screens/note_editor_screen.dart)
- [lib/features/notes/presentation/controllers/note_editor_controller.dart](/d:/cloned%20projects/THINKNOTE/lib/features/notes/presentation/controllers/note_editor_controller.dart)

## Root Cause Report

### 1. Full-screen keyboard inset propagation

Location:
- [lib/features/notes/presentation/screens/note_editor_screen.dart](/d:/cloned%20projects/THINKNOTE/lib/features/notes/presentation/screens/note_editor_screen.dart)

Explanation:
- The editor screen used `Scaffold(resizeToAvoidBottomInset: true)` with the entire screen body inside one vertical `Column`.
- When the keyboard opened or closed, the scaffold resized the whole body, so the app bar, metadata card, spacing, editor card, and footer all participated in the same relayout.

Impact:
- Header and editor moved together during keyboard animation.
- The editor height changed as part of a full-screen reflow instead of being the only region that resized.

Severity:
- Critical

### 2. Save and sync state were wired into layout-bearing metadata widgets

Location:
- [lib/features/notes/presentation/screens/note_editor_screen.dart](/d:/cloned%20projects/THINKNOTE/lib/features/notes/presentation/screens/note_editor_screen.dart)

Explanation:
- The metadata section watched `isSaving`, `hasChanges`, `lastSavedAt`, and the full `SyncState`.
- That made title-adjacent layout rebuild on autosave and sync transitions even though the title field itself should remain visually anchored.

Impact:
- `Saving locally...`, `Syncing...`, `Saved ...`, and offline/error transitions could update the same widget subtree that holds the title input and metadata row.

Severity:
- High

### 3. The app bar and metadata card watched the full notes store for folder display

Location:
- [lib/features/notes/presentation/screens/note_editor_screen.dart](/d:/cloned%20projects/THINKNOTE/lib/features/notes/presentation/screens/note_editor_screen.dart)
- [lib/features/notes/presentation/controllers/notes_controller.dart](/d:/cloned%20projects/THINKNOTE/lib/features/notes/presentation/controllers/notes_controller.dart)

Explanation:
- The editor app bar and metadata card were watching `notesControllerProvider` broadly to resolve the active folder.
- Autosave calls `applyLocalNoteUpsert`, which updates the notes store on every save.
- That meant unrelated note-list mutations could rebuild top editor chrome.

Impact:
- Autosave state changes could fan out into header rebuilds even when the selected folder did not change.

Severity:
- High

### 4. Dynamic status labels changed layout footprint

Location:
- [lib/features/notes/presentation/screens/note_editor_screen.dart](/d:/cloned%20projects/THINKNOTE/lib/features/notes/presentation/screens/note_editor_screen.dart)

Explanation:
- Status text such as `Saving locally...`, `Syncing...`, `Offline - will sync later`, and `Saved ...` used different widths.
- The status chip size was not reserved, so the metadata and footer rows had to relayout when the label changed.

Impact:
- Visible micro-shifts during save/sync transitions.

Severity:
- Medium

### 5. The body editor did not own a stable scroll controller and used default scroll padding

Location:
- [lib/features/notes/presentation/screens/note_editor_screen.dart](/d:/cloned%20projects/THINKNOTE/lib/features/notes/presentation/screens/note_editor_screen.dart)

Explanation:
- The body `TextField` relied on its internal scrolling behavior and default `scrollPadding`.
- For a full-surface note editor, the default caret visibility padding is unnecessary once keyboard space is managed explicitly by the viewport.

Impact:
- Extra caret visibility adjustments could add to the perceived jump when the keyboard or save state changed.

Severity:
- Medium

## Existing Architecture Review

### Before

Screen
- App bar
- Metadata card
- Spacer
- Expanded editor card

Rebuild map before:
- Keyboard open/close: whole scaffold body relayout
- Autosave: metadata section rebuilt
- Sync state update: metadata section rebuilt, footer rebuilt
- Notes store upsert after save: app bar and metadata section rebuilt because they watched the full notes state

### Problems

- The keyboard affected the full screen instead of only the editor viewport.
- Status state was mixed into layout-bearing containers.
- Header widgets listened to much broader state than they needed.
- Status pill width was variable.

## Recommended Architecture

Screen
- Fixed app bar
- Fixed metadata card
- Expanded editor viewport
- Keyboard inset applied only to the expanded editor region

Rules implemented:
- Keyboard no longer resizes the scaffold body.
- Only the editor viewport consumes `MediaQuery.viewInsets.bottom`.
- Save/sync status is rendered by isolated status widgets.
- Folder display uses narrow selectors instead of full notes-store watches.
- Body editor owns a stable `ScrollController` and `FocusNode`.

## Fix Plan and Result

Issue:
- Full-screen relayout on keyboard open/close

Root Cause:
- `resizeToAvoidBottomInset: true` on the editor scaffold

Recommended Fix:
- Disable scaffold resize and apply bottom inset only inside the expanded editor viewport

Expected Result:
- Header stays fixed, editor region alone resizes

Status:
- Implemented

Issue:
- Save/sync updates rebuilding title-adjacent layout

Root Cause:
- Metadata card watched editor save state and full sync state directly

Recommended Fix:
- Move save/sync rendering into dedicated status widgets

Expected Result:
- Title field remains visually anchored during status changes

Status:
- Implemented

Issue:
- Autosave causing header rebuilds through notes-store updates

Root Cause:
- App bar and metadata watched the full notes state for folder display

Recommended Fix:
- Select only the active folder and folder list

Expected Result:
- Autosave note upserts no longer churn top editor chrome

Status:
- Implemented

Issue:
- Status labels changing width

Root Cause:
- No reserved width for state text

Recommended Fix:
- Use fixed-width status pills with ellipsis

Expected Result:
- Status transitions do not move surrounding content

Status:
- Implemented

Issue:
- Caret/scroll adjustments adding to jank

Root Cause:
- No explicit editor scroll controller and default scroll padding

Recommended Fix:
- Keep a stable body scroll controller and reduce scroll padding

Expected Result:
- Scroll position and focus behavior stay stable across viewport changes

Status:
- Implemented

## Before and After Rebuild Surface

Before:
- Keyboard inset subscriber count affecting the editor layout: full scaffold body
- Autosave-related top-chrome rebuild surface: app bar, metadata card, footer
- Sync-related rebuild surface: metadata card, footer

After:
- Keyboard inset subscriber count affecting the editor layout: `_EditorViewportInset` only
- Autosave-related top-chrome rebuild surface: header status chip only
- Sync-related rebuild surface: header status chip and footer status chip only
- Notes-store upserts after save: no top-chrome rebuild unless the selected folder actually changes

## Validation

Automated validation added:
- [test/widget/note_editor_viewport_stability_test.dart](/d:/cloned%20projects/THINKNOTE/test/widget/note_editor_viewport_stability_test.dart)

The test verifies:
- Keyboard insets do not move the app bar, metadata card, editor card, or body field top edge
- The body `TextField` keeps the same controller and focus node across keyboard transitions
- Save state transitions do not change the header status chip width
- Sync state transitions do not change the header status chip width

## Remaining Profiling Gap

This headless pass validates geometry stability and rebuild fan-out reduction. Exact frame timing, paint counts, and layout-pass counts still require a device-side Flutter DevTools profile run on Android and iOS hardware.
