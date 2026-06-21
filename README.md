# OsxPaster

A lightweight macOS menu bar app that **types your clipboard contents into other apps** — including places where a normal ⌘V paste doesn't work, such as web-based KVMs, remote desktops, and virtual machine consoles.

## Purpose

Many remote-access tools (IPMI/BMC web KVMs, browser-based remote desktops, VM consoles) don't share your Mac's clipboard, so you can't paste passwords, commands, or config into them. OsxPaster solves this by *simulating the keystrokes* for whatever you copied, so the text is typed character-by-character into the target window as if you had typed it yourself.

It lives in the menu bar (no Dock icon), watches your clipboard, and pastes on demand after a short countdown so you have time to switch to the target window.

### Features

- **Menu bar only** — runs as an accessory app with no Dock icon or main window.
- **Live clipboard preview** — the menu shows the latest copied text.
- **Countdown paste** — click *Paste*, switch to your target app, and the text is typed when the countdown ends. The menu bar icon shows the seconds remaining.
- **Three paste methods** (selectable in Settings):
  - **Unicode (default)** — sends each character as a Unicode key event. Works in most native macOS apps.
  - **Key Codes (US QWERTY)** — sends real US-QWERTY virtual key codes with ~5 ms pacing per character. Use this for **web KVMs and remote desktops** that only understand physical key codes.
  - **Clipboard (⌘V)** — writes to the pasteboard and sends ⌘V, then restores your previous clipboard contents. Requires the target app to accept ⌘V.
- **Configurable** — clipboard scan interval and paste delay are adjustable.

## Requirements

- macOS (built against a recent SDK; see [Compatibility](#compatibility) below)
- Xcode (to build from source)
- **Accessibility permission** — required so the app can post keystrokes to other apps.

## Usage

1. Launch **OsxPaster**. A clipboard icon appears in the menu bar (there is no Dock icon).
2. The first time you paste, macOS will prompt for **Accessibility permission**. Grant it under
   *System Settings → Privacy & Security → Accessibility* and enable OsxPaster.
   You can re-check or open this from the app's **Settings… → Accessibility Permission** section.
3. Copy any text (⌘C) as usual — the menu bar menu shows a preview of what's on the clipboard.
4. Open the menu and click **Paste in N sec**.
5. Click into the target window (the web KVM, remote desktop, terminal, etc.) before the countdown ends.
6. When the countdown finishes, OsxPaster types the copied text into whatever window is focused.

### Choosing a paste method

Open **Settings…** from the menu and pick a **Paste Method**:

| Method | Best for |
| --- | --- |
| Unicode (default) | Normal native macOS apps |
| Key Codes (US QWERTY) | Web KVMs, BMC/IPMI consoles, remote desktops |
| Clipboard (⌘V) | Apps that accept ⌘V and where you want a fast, single paste |

> **Note:** The Key Codes method maps characters using a **US QWERTY** layout. If the target machine uses a different keyboard layout, some symbols may come out wrong.

### Settings

- **Clipboard Scan Interval** — how often the app checks for new clipboard content (0–10 s).
- **Paste Delay** — how long the countdown runs after you click *Paste*, giving you time to switch
  to the target window (0–30 s; 0 pastes immediately).
- **Paste Method** — see the table above.
- **Accessibility Permission** — shows whether permission is granted and links to System Settings.

## Building from source

### Option 1 — Xcode

1. Open `OsxPaster.xcodeproj` in Xcode.
2. Select the **OsxPaster** scheme.
3. Build and run (⌘R), or build a Release with **Product → Archive**.

### Option 2 — Build a distributable DMG

Two helper scripts produce a `.dmg` in `build/`:

```bash
# Standard build (ad-hoc signed, builds against the project's default deployment target)
./build_dmg.sh

# Build targeting macOS 14 (Sonoma) and up
./build_dmg_sonoma.sh
```

Both scripts run a Release `xcodebuild`, ad-hoc sign the app (no Apple Developer
certificate required), and package it into a DMG containing the app plus an
`/Applications` shortcut. Output:

- `build/OsxPaster-1.0.dmg` (from `build_dmg.sh`)
- `build/OsxPaster-1.0-sonoma.dmg` (from `build_dmg_sonoma.sh`)

To install, open the DMG and drag **OsxPaster** onto **Applications**.

> Because the app is only ad-hoc signed (not notarized), on first launch you may
> need to right-click the app → **Open**, or allow it under
> *System Settings → Privacy & Security*.

### Running the tests

```bash
xcodebuild test -project OsxPaster.xcodeproj -scheme OsxPaster -destination 'platform=macOS'
```

The `OsxPasterTests` target covers the keystroke-building logic (Unicode strokes,
US-QWERTY key-code mapping, clipboard paste sequence, and the off-main-thread
paste guarantee).

## Compatibility

The Xcode project's default deployment target is set to a recent macOS version. To
target older systems, use `build_dmg_sonoma.sh`, which builds with
`MACOSX_DEPLOYMENT_TARGET=14.0` (macOS Sonoma). Adjust that value in the script if
you need a different minimum version.

## How it works

- `ClipboardMonitor` polls `NSPasteboard` on a timer and publishes the latest text to the UI.
- `MenuBarView` / `OsxPasterApp` render the `MenuBarExtra` and start the paste countdown.
- `PasteManager` builds and posts the keystrokes via `CGEvent`. The actual event
  posting runs on a detached background task so a long paste never freezes the menu
  or UI. Keystroke building is kept pure (the `build*Strokes` functions) so it can
  be unit-tested independently of the live posting path.
- `SettingsView` exposes the scan interval, paste delay, paste method, and
  Accessibility permission status.

## Project layout

```
OsxPaster/
  OsxPasterApp.swift     # App entry point, MenuBarExtra, dock-icon hiding
  MenuBarView.swift      # Menu bar dropdown UI + paste trigger
  ClipboardMonitor.swift # Polls the pasteboard, runs the paste countdown
  PasteManager.swift     # Keystroke building + CGEvent posting (3 methods)
  SettingsView.swift     # Settings window
OsxPasterTests/          # Unit tests for keystroke logic
build_dmg.sh             # Build + package a DMG (ad-hoc signed)
build_dmg_sonoma.sh      # Same, targeting macOS 14+
```
