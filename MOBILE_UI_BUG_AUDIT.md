# Mobile UI Bug Audit

Date: 2026-06-11

Scope: Static audit of Flutter presentation code for small mobile screen issues. This report focuses on layout overflow, clipped content, unsafe fixed sizing, and controls that are likely to degrade on compact phones, high text scale, or landscape.

## Summary

The app has a polished visual direction, but several layouts still rely on fixed heights, fixed card widths, unbounded trailing rows, and non-scrollable vertical compositions. These are most likely to fail on:

- 320 px wide phones such as older iPhone SE / compact Android devices.
- Short screens or landscape orientation.
- Accessibility text scale 1.3x to 2.0x.
- Long real user data such as folder names, profile names, sync error labels, and note titles.

## Implementation Status

Status updated after remediation pass on 2026-06-11.

- Fixed: Editor top action bar and editor metadata footer now constrain long labels and adapt on compact widths.
- Fixed: Auth form card no longer uses fixed tab content heights; active forms size to content inside the page scroll.
- Fixed: Passcode unlock screen is scroll-safe and scales keypad controls on short screens.
- Fixed: Bottom navigation now accounts for bottom safe-area padding, uses a shorter Home label, and hides labels on very narrow widths.
- Fixed: Folder segmented control hides labels on compact/high-text-scale layouts, and folder/collection grids can switch to one column.
- Fixed: Home pinned note and Search top-pick cards adapt text/illustration behavior on compact or high-text-scale screens.
- Fixed: Profile and theme settings trailing labels/focus badges now constrain and ellipsize long text.
- Still recommended: Add constrained-width widget/golden tests and perform manual emulator QA using the matrix below.

## Findings

### 1. Editor top action bar can horizontally overflow on compact phones

Severity: High

Files:
- `lib/features/notes/presentation/screens/note_editor_screen.dart:135`
- `lib/features/notes/presentation/screens/note_editor_screen.dart:150`
- `lib/features/notes/presentation/screens/note_editor_screen.dart:205`
- `lib/features/notes/presentation/screens/note_editor_screen.dart:285`

Problem:
The editor header is a single `Row` containing back button, centered folder selector, popup menu, spacing, and a Save button. The folder selector contains a `Text` without `maxLines` or `overflow`, and the fixed buttons consume much of the available width.

Why it breaks on mobile:
On a 320 px screen, after horizontal page padding and fixed controls, the folder chip has very little remaining width. Long folder names or increased text scale can push the row beyond the screen width.

Expected behavior:
The editor header should never overflow. Long folder names should ellipsize, and actions should collapse into the overflow menu on compact widths.

Recommended fix:
Use a responsive editor app bar. Constrain the folder chip with `Flexible`, add `maxLines: 1` and `TextOverflow.ellipsis`, and move Save into the overflow menu or reduce it to an icon on narrow widths.

### 2. Editor bottom metadata row can overflow with sync/status text

Severity: Medium

Files:
- `lib/features/notes/presentation/screens/note_editor_screen.dart:511`
- `lib/features/notes/presentation/screens/note_editor_screen.dart:516`
- `lib/features/notes/presentation/screens/note_editor_screen.dart:555`

Problem:
The bottom editor status row uses a fixed horizontal `Row` with word count, read time, `Spacer`, and save label.

Why it breaks on mobile:
At high text scale or with longer localized status strings, the metadata chips and save label can exceed the available width.

Expected behavior:
Metadata should wrap or collapse gracefully without clipping the writing area.

Recommended fix:
Use `Wrap` for metadata or hide lower-priority labels on compact widths. Add max-width constraints and ellipsis to the save label.

### 3. Auth form uses fixed tab content heights

Severity: High

Files:
- `lib/features/auth/presentation/screens/auth_gate_screen.dart:85`
- `lib/features/auth/presentation/screens/auth_gate_screen.dart:175`
- `lib/features/auth/presentation/screens/auth_gate_screen.dart:177`

Problem:
The sign-in/sign-up form area is forced to `370` or `450` px using `AnimatedContainer`, while the parent page also scrolls.

Why it breaks on mobile:
Validation errors, startup notices, Firebase error banners, keyboard visibility, and accessibility text scale can make the form taller than the fixed container. This can cause nested scrolling, clipped fields, or submit buttons that are hard to reach.

Expected behavior:
Auth forms should size to content and scroll as one page.

Recommended fix:
Remove fixed heights and let the active form determine its height. Use `AnimatedSize` instead of fixed `AnimatedContainer` heights, and keep a single scrollable parent.

### 4. Passcode unlock screen is not scroll-safe on short screens

Severity: High

Files:
- `lib/features/auth/presentation/screens/app_passcode_unlock_screen.dart:249`
- `lib/features/auth/presentation/screens/app_passcode_unlock_screen.dart:252`
- `lib/features/auth/presentation/screens/app_passcode_unlock_screen.dart:325`
- `lib/features/auth/presentation/screens/app_passcode_unlock_screen.dart:360`
- `lib/features/auth/presentation/screens/app_passcode_unlock_screen.dart:419`
- `lib/features/auth/presentation/screens/app_passcode_unlock_screen.dart:458`

Problem:
The passcode screen uses a centered non-scrollable `Column` with `Spacer`s and a four-row keypad. Each keypad button has a fixed 72 px height plus padding.

Why it breaks on mobile:
On short devices, landscape orientation, or large text scale, the content can exceed the safe viewport and overflow vertically.

Expected behavior:
The passcode screen should remain usable on compact/landscape devices.

Recommended fix:
Wrap the content in a `LayoutBuilder` and `SingleChildScrollView`, or scale keypad button height based on available viewport height. Consider reducing vertical gaps on compact breakpoints.

### 5. Bottom navigation can overflow horizontally and ignore bottom safe-area height

Severity: High

Files:
- `lib/features/shell/presentation/widgets/main_bottom_nav.dart:39`
- `lib/features/shell/presentation/widgets/main_bottom_nav.dart:40`
- `lib/features/shell/presentation/widgets/main_bottom_nav.dart:56`
- `lib/features/shell/presentation/widgets/main_bottom_nav.dart:61`
- `lib/features/shell/presentation/widgets/main_bottom_nav.dart:80`
- `lib/features/shell/presentation/widgets/main_bottom_nav.dart:110`

Problem:
The bottom nav has a fixed 94 px height, fixed 76 px center gap for the FAB, and labels such as `Dashboard` without width-aware handling.

Why it breaks on mobile:
On 320 px screens, each nav item gets a narrow width after the center gap. The `Dashboard` label can exceed its item width. The nav height also does not adapt to `MediaQuery.padding.bottom`, so it may collide with system gesture areas or waste space depending on device.

Expected behavior:
Bottom navigation should respect safe-area padding and keep labels/icons stable at compact widths.

Recommended fix:
Use `SafeArea(top: false)` around the nav content, compute height as base height plus bottom inset, and shorten `Dashboard` to `Home` or hide labels below a compact breakpoint.

### 6. Folder segmented control can overflow at large text scale

Severity: Medium

Files:
- `lib/features/folders/presentation/screens/folders_screen.dart:181`
- `lib/features/folders/presentation/screens/folders_screen.dart:187`
- `lib/features/folders/presentation/screens/folders_screen.dart:205`
- `lib/features/folders/presentation/screens/folders_screen.dart:221`

Problem:
The Folders / Tags / Collections control is a three-column `Row`, and each segment contains an icon plus text. Text has no `maxLines`, `overflow`, or compact variant.

Why it breaks on mobile:
The `Collections` label is relatively long. On narrow screens or high text scale, icon + gap + text can overflow inside its third of the control.

Expected behavior:
The segmented control should remain readable without overflow.

Recommended fix:
Use `FittedBox`, `TextOverflow.ellipsis`, or a compact mode that shows icons only below a width threshold.

### 7. Folder and collection grids are fixed to two columns

Severity: Medium

Files:
- `lib/features/folders/presentation/screens/folders_screen.dart:279`
- `lib/features/folders/presentation/screens/folders_screen.dart:283`
- `lib/features/folders/presentation/screens/folders_screen.dart:492`
- `lib/features/folders/presentation/screens/folders_screen.dart:496`
- `lib/features/folders/presentation/screens/folders_screen.dart:539`
- `lib/features/folders/presentation/screens/folders_screen.dart:591`

Problem:
Folder and collection grids always use two columns with `childAspectRatio: 1.1`. Cards contain a 48 px icon, popup menu, title, note count, padding, and decorative icon.

Why it breaks on mobile:
At 320 px width, each card becomes very narrow and short after padding and spacing. Long folder names are truncated aggressively, and vertical content can become cramped or clipped with larger fonts.

Expected behavior:
Grid cards should adapt to width and text scale.

Recommended fix:
Use a responsive `SliverGridDelegateWithMaxCrossAxisExtent` or switch to one-column cards on compact widths / high text scale.

### 8. Home pinned note card reserves too much fixed illustration space

Severity: Medium

Files:
- `lib/features/home/presentation/screens/home_screen.dart:376`
- `lib/features/home/presentation/screens/home_screen.dart:385`
- `lib/features/home/presentation/screens/home_screen.dart:389`
- `lib/features/home/presentation/screens/home_screen.dart:426`
- `lib/features/home/presentation/screens/home_screen.dart:489`
- `lib/features/home/presentation/screens/home_screen.dart:505`

Problem:
The pinned card has a fixed 156 px height and reserves 110 px on the right for a fixed-size illustration. The metadata row is inside the same fixed-height card.

Why it breaks on mobile:
On compact screens, the text area becomes narrow and the metadata can wrap into the fixed card height. High text scale can cause vertical clipping.

Expected behavior:
Pinned notes should remain readable and not have decorative art compete with content on compact screens.

Recommended fix:
Hide or reduce the illustration below a compact breakpoint, or allow the card height to grow with content.

### 9. Profile/settings rows can overflow with long trailing text

Severity: Medium

Files:
- `lib/features/profile/presentation/screens/profile_screen.dart:143`
- `lib/features/profile/presentation/screens/profile_screen.dart:217`
- `lib/features/profile/presentation/screens/profile_screen.dart:227`
- `lib/features/profile/presentation/screens/profile_screen.dart:687`
- `lib/features/profile/presentation/screens/profile_screen.dart:723`
- `lib/features/profile/presentation/screens/theme_settings_screen.dart:268`
- `lib/features/profile/presentation/screens/theme_settings_screen.dart:305`

Problem:
Profile and settings rows use horizontal `Row`s with leading icon, expanded text, and trailing content. The trailing text rows are not constrained. The profile focus badge uses `mainAxisSize: MainAxisSize.min` with text but no ellipsis.

Why it breaks on mobile:
Long display names, long focus labels, sync error labels, or localized theme labels can exceed the available row width.

Expected behavior:
Long account/settings labels should truncate or wrap predictably.

Recommended fix:
Constrain trailing rows, add `maxLines: 1` and ellipsis to focus/trailing labels, and allow settings subtitle to wrap while keeping trailing content compact.

### 10. Search top-pick cards use fixed height and width

Severity: Low to Medium

Files:
- `lib/features/search/presentation/screens/search_screen.dart:290`
- `lib/features/search/presentation/screens/search_screen.dart:291`
- `lib/features/search/presentation/screens/search_screen.dart:713`
- `lib/features/search/presentation/screens/search_screen.dart:714`
- `lib/features/search/presentation/screens/search_screen.dart:738`
- `lib/features/search/presentation/screens/search_screen.dart:746`
- `lib/features/search/presentation/screens/search_screen.dart:755`

Problem:
Top-pick cards are fixed at 220 px tall and 220 px wide, with title, excerpt, and folder chip.

Why it breaks on mobile:
At larger text scale or with long real note/folder names, the folder chip and text stack can exceed the fixed height.

Expected behavior:
Top-pick cards should adapt to content or reduce displayed text at compact breakpoints.

Recommended fix:
Use responsive heights, reduce excerpt lines at high text scale, and add ellipsis to the folder chip text.

## Recommended Mobile QA Matrix

- Width 320, height 568, text scale 1.0.
- Width 320, height 568, text scale 1.3.
- Width 360, height 640, text scale 1.3.
- Width 393, height 852, text scale 2.0.
- Small Android landscape.
- iOS device with home indicator / gesture navigation.

## Priority Fix Order

1. Editor top bar and bottom metadata row.
2. Auth form fixed heights.
3. Passcode unlock vertical overflow.
4. Bottom navigation safe-area and label overflow.
5. Folder segmented control and grids.
6. Profile/settings row trailing overflow.
7. Pinned/top-pick card fixed decorative layouts.

## Verification Needed After Fixes

- Run `dart analyze lib`.
- Run focused widget tests for auth, shell, editor, folders, search, and profile if available.
- Add golden or layout-smoke tests with constrained widths around 320 px.
- Manually test keyboard-open editor and auth flows on a compact emulator.
