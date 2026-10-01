<p align="center"><img src="App/Assets/AppIcon.png" width="112" alt="Lilim app icon"></p>

# Lilim

**Browse folders. Run commands. Stay in one macOS window.**

[English](README.md) · [한국어](README.ko.md) · [日本語](README.ja.md)

Lilim brings a Finder-style file browser and a real terminal together. Click a folder to move the **active terminal tab** into that directory, keeping the shell, environment variables and output history. Open another tab explicitly when you need another session.

Built with SwiftUI, AppKit and a native PTY bridge, with no third-party package dependencies. Teal and mint accents accompany a folder-and-terminal icon.

**Status:** early personal-use version, 0.1.0. Development focuses on everyday use and fixes. Sales and Mac App Store release work are on hold. The source repository is public; an open-source license has not been selected. The current **app UI is Korean**. Three README languages do not imply three-language UI support.

![Hierarchical folder columns, favorites and the terminal](docs/screenshots/workspace.png)

`Workspace → Projects → Garden` appears in separate hierarchy columns, with saved locations on the left and one terminal tab on the right. Screenshots were captured from the actual native app on October 1, 2026, using sample files. The shell prompt was simplified for the capture sessions.

## Contents

- [Installation](#installation)
- [Navigation and favorites](#navigation-and-favorites)
- [Terminal behavior](#terminal-behavior)
- [File operations and previews](#file-operations-and-previews)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [Current limits](#current-limits)
- [Development](#development)
- [Sharing a test build](#sharing-a-test-build)
- [Feedback and license](#feedback-and-license)

## Installation

### Requirements

| Use | Requirements |
| --- | --- |
| Run the app | macOS 14 or later |
| Build from source | Swift 6.2 or later, provided by Command Line Tools or Xcode on macOS |
| Create a universal test ZIP | Full Xcode; builds Apple Silicon (`arm64`) and Intel (`x86_64`) |

### Build and launch

```sh
git clone https://github.com/obst2580/lilimdir.git
cd lilimdir
bash scripts/build-app.sh release
```

The result is **`dist/Lilim.app`**. Swift Package Manager builds for your local toolchain's architecture. Use the packaging script below for a universal build. The normal build needs no third-party dependencies or Xcode project generation.

1. Open the repository's `dist` folder in Finder.
2. Drag `Lilim.app` into **Applications**.
3. Double-click the installed app.
4. Right-click its Dock icon → **Options → Keep in Dock**.

For an update, quit Lilim, replace the installed app with the new build and relaunch. Shell sessions are not restored after quitting.

For development, including an optional starting folder:

```sh
bash scripts/run.sh
bash scripts/run.sh --directory "$PWD"
```

These builds have local ad hoc signatures, without Developer ID signing or notarization. A downloaded test build may be blocked on another Mac. See the included installation guide and [Apple's unknown-developer app instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac).

## Navigation and favorites

| Area | Purpose |
| --- | --- |
| Sidebar | Home, Desktop, Documents, Downloads, Applications, available volumes, favorites and recent locations |
| File browser | Folders and files in icons, list, hierarchy columns or gallery view |
| Terminal | Commands in the selected folder using the active shell session |

### Navigate

1. **Click a folder once** to enter it and change the active terminal's directory. In column view, children appear in the next column. Each column represents a parent/child folder; navigation is not limited to three levels.
2. Click a file once to select it; double-click to open it in its default app. Use `⌘`-click and `⇧`-click for multiple selection.
3. Click breadcrumbs to jump to ancestors. `⌘L` / `⌘⇧G` accepts a path; `⌘⇧O` opens the folder picker.
4. `⌘F` searches names in the current folder and descendants, showing parent paths in results.
5. `⌘1`–`⌘4` switches views. Sort by name, kind, size, creation or modification date, with ascending/descending order and folders first.
6. `⌘⇧.` toggles hidden files; `⌘R` refreshes. Drag pane dividers to adjust widths.

Folder symlinks are browsed inside Lilim. **Reveal in Finder** is a separate, explicit context-menu action.

### Save favorites

- Click the toolbar **star** to add or remove the current folder.
- Right-click folders → **Add to Favorites** (`즐겨찾기에 추가`). Multiple selected folders can be added together.
- Click **+** beside the sidebar's Favorites heading to choose one or more folders without navigating away.
- The **Favorites** (`즐겨찾기`) menu also adds folders or opens saved locations.
- Right-click a saved location to remove it. Duplicate paths are filtered out.

Clicking a favorite moves the browser and the **current terminal tab**. Favorites and recent locations survive restarts. Favorites are a flat list; custom groups, aliases and manual reordering are not implemented.

## Terminal behavior

| Action | Result |
| --- | --- |
| Click a folder, breadcrumb or favorite | Move the active tab; do not create or automatically select another tab |
| Click **+**, press `⌘T`, or choose **Open in New Terminal Tab** (`새 터미널 탭에서 열기`) | Create a separate PTY and shell |
| Select a terminal tab | Activate its session and navigate the browser to its location |
| Select a folder during a foreground command | Queue the latest folder change until the command finishes |
| Run `cd` in the terminal | Update the terminal path; click the arrow beside it to move the browser there |
| Close a tab / quit Lilim | End that session's shell and jobs / all app-owned sessions |

Other tabs keep running. The login shell uses an executable `$SHELL`, falling back to `/bin/zsh`. Navigation sends a quoted `builtin cd -- …`, which can appear in terminal output. An unfinished command line is cleared before a browser-triggered directory change.

UTF-8, native input methods, ANSI colors/cursor movement, screen clearing, alternate screens, bracketed paste, text selection/copy and 5,000 lines of scrollback are supported. Decomposed Hangul folder names display as composed syllables occupying two cells, while preserving original paths and copied text.

Mouse-wheel and trackpad scrolling are forwarded to programs that request xterm mouse input, including Codex. Ordinary shell output uses local scrollback. Hold Shift while scrolling to use local history when available. Full-screen applications manage their own history and scroll position. [Scrolling verification](docs/Terminal-Scrolling.md) records the fix and checks in Korean.

The terminal history scrollbar stays visible, including when macOS normally hides scrollbars, and its mint thumb indicates the visible portion and current position. Programs such as Codex keep their transcript inside the application and do not report its length or position to Lilim. In that mode, the right rail shows up/down buttons instead of a position thumb, with “프로그램 내부 스크롤” in the footer. Hold a button to keep scrolling; mouse-wheel and trackpad scrolling still work.

![Explicitly opened tabs and Korean path and text output](docs/screenshots/terminal-tabs.png)

The `문서` tab was explicitly opened from a favorite. The existing `Garden` tab remains, and a real shell prints the sample text file.

## File operations and previews

Right-click selected items or use the folder-options menu. File shortcuts apply when the **file browser has focus**; terminal copy/paste remains terminal input.

| Category | Actions |
| --- | --- |
| Create and open | Folder, text file, new folder with selection, default app and Open With |
| Copy and move | Copy/paste, cut/paste, move-paste, destination picker, drag/drop |
| Rename and duplicate | Single rename, batch prefix/suffix/replacement/numbering with preview, duplicate |
| Delete and recover | System Trash, session-local undo/redo |
| Organize | Finder aliases, ZIP creation, Finder tag names/colors, add/replace/remove tags |
| Inspect | Quick Look, gallery, file info, permissions and lock state |
| Integrate | Reveal in Finder, copy paths, macOS sharing picker, mounted volumes and eject |

### Copy, move and recover

- `⌘C` copies; `⌘V` pastes; `⌘⌥V` moves copied items. `⌘X` also marks items for moving.
- Drag within a volume to move; drag across volumes to copy. Hold Option to copy or Command to move.
- Name collisions offer **keep both, replace, skip or cancel**. Replaced and deleted items go to the system Trash.
- `⌘Z` / `⌘⇧Z` undo/redo supported operations during the current session. External changes and conflicting paths may limit recovery. History is cleared when the app closes.
- Permanent deletion and emptying the Trash are not provided.

The [Finder feature review](docs/Finder-Features.md) records detailed operation and recovery coverage; it is currently Korean.

### Rename and preview

Select several items and press Return for batch rename. Inspect the before/after preview before applying. Extensions are retained, and conflicting target names prevent the operation from starting.

![Batch rename preview for two files](docs/screenshots/batch-rename.png)

Space or `⌘Y` opens Quick Look. Gallery (`⌘4`) previews a selected file above thumbnails. `⌘I` opens file information, including permissions and the locked flag.

![Gallery preview of a sample README alongside the terminal](docs/screenshots/gallery.png)

## Keyboard shortcuts

`⌘` Command · `⌥` Option · `⇧` Shift · `⌃` Control. File operations require browser focus; `⌘⌥Return` focuses the file list.

| Action | Shortcut |
| --- | --- |
| Open selection / choose folder | `⌘O` / `⌘⇧O` |
| New folder / new folder with selection | `⌘⇧N` / `⌘⌃N` |
| Copy / paste / move-paste | `⌘C` / `⌘V` / `⌘⌥V` |
| Cut / duplicate | `⌘X` / `⌘D` |
| Trash / rename | `⌘Delete` / Return |
| Undo / redo | `⌘Z` / `⌘⇧Z` |
| Quick Look / info | Space or `⌘Y` / `⌘I` |
| Focus files / copy selected paths | `⌘⌥Return` / `⌘⌥C` |
| Go to path | `⌘L`, `⌘⇧G` |
| Search current folder | `⌘F` |
| Back / forward / parent | `⌘[` / `⌘]` / `⌘↑` |
| Home | `⌘⇧H` |
| Icons / list / columns / gallery | `⌘1` / `⌘2` / `⌘3` / `⌘4` |
| Hidden files / refresh | `⌘⇧.` / `⌘R` |
| Toggle sidebar | `⌘⌥S` |
| New terminal tab / focus terminal | `⌘T` / `⌘Return` |
| Terminal font larger / smaller / reset | `⌘+` / `⌘-` / `⌘0` |

## Current limits

- Terminal emulation is a VT/xterm subset. Complex TUIs, mouse reporting and emoji sequences are not guaranteed to be fully compatible.
- Search matches **names**, not contents or global Spotlight metadata. It scans up to 25,000 entries and displays up to 200 results, reporting truncation in the status bar. Interiors of `node_modules`, `.git`, `.build`, `Library`, `Pods`, `DerivedData`, `.cache`, symlink directories and application packages are skipped.
- The selected folder is watched for changes. Other columns refresh on re-entry or manual refresh.
- There is one file-browser workspace with terminal tabs. Independent dual file panes, file-browser tabs and multiple browser windows are not implemented.
- ZIP creation is supported; browsing/extraction uses external apps. No virtual archive browser, multi-operation queue, byte-level progress, pause/resume or plugin system.
- Available iCloud files are accessed as ordinary files; provider-specific sync controls are not implemented.
- Favorites, recents, last folder, view and sort settings are saved. Shell sessions and file-operation undo history are not restored after restart.
- The App Store sandbox experiment fails terminal job-control and user CLI execution checks. The Store target is **not ready for release**.

## Development

```sh
bash scripts/build-app.sh release
bash scripts/check.sh
```

Checks build a standalone verification executable and use owned temporary fixtures. Coverage includes file operations, conflicts, recovery, batch rename, aliases, ZIP, tags, clipboard, selection, navigation, history, favorites, UTF-8/ANSI, decomposed Hangul, resize and real PTY input, working-directory changes and Ctrl-C. They verify retained shell/environment, deferred directory changes during foreground jobs and explicit-only tab creation.

| Path | Purpose |
| --- | --- |
| `Sources/Lilim/` | SwiftUI/AppKit UI, navigation, file operations and terminal rendering |
| `Sources/PTYBridge/` | C PTY creation, resize and working-directory lookup |
| `Tests/` | File, browser, terminal and sandbox checks |
| `App/` | Bundle metadata, privacy manifest and icon source |
| `scripts/` | Build, launch, icons, checks and packaging |
| `Lilim.xcodeproj/` | Shared `Lilim` and `Lilim-AppStore` Xcode schemes |
| `docs/` | Feature reviews, comparisons and screenshots |
| `Release/` | Historical readiness notes and unpublished page drafts |
| `dist/`, `.build/` | Generated output, excluded from Git |

`TerminalBuffer`, `TerminalCanvasView` and `PTYProcess` separate parsing, drawing and process management. [Icon notes](App/Assets/README.md) record the generated source asset and palette. `scripts/build-icon.sh` creates the `.icns` and sidebar image.

The ordinary Xcode scheme is **Lilim**. After adding/removing source files, regenerate references with `python3 scripts/generate-xcode-project.py`. **Lilim-AppStore** is a sandbox experiment, not the personal-use build. [Release readiness](Release/Readiness.md), [Store research](docs/Mac-App-Store-Launch.md) and [Marta comparison](docs/Marta-Comparison.md) are dated supporting notes in Korean, not current release promises.

## Sharing a test build

With full Xcode installed:

```sh
bash scripts/package-test-app.sh
```

This archives current source for both Mac architectures, signs locally, includes **`INSTALL.txt`** (currently Korean), and verifies the extracted ZIP's signature, architecture and guide. Output:

```text
dist/Lilim-0.1.0-test-universal-YYYYMMDD-HHMMSS.zip
```

Send the ZIP as a file through KakaoTalk or another service. The recipient downloads it **on a Mac**, extracts it and moves `Lilim.app` to Applications. It remains a test build without Apple distribution signing or notarization. There is currently no published installer attached to a GitHub release; source and screenshots are not installers.

## Feedback and license

Bug reports should include steps, expected/actual results, macOS version, Mac architecture and relevant screenshots or terminal output. Remove private paths, tokens and personal content before sharing. Everyday-use suggestions are welcome in [GitHub Issues](https://github.com/obst2580/lilimdir/issues).

**No open-source license has been selected.** Public source visibility alone does not grant an open-source license for reuse or redistribution. License and contribution policy will be decided separately. The executable and bundle name remain **Lilim**; FindTerm is a naming candidate only.
