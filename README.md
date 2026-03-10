# ClipboardSaver

A lightweight macOS menu bar utility that saves clipboard images to disk.

## Features

- Global keyboard shortcut (default: `Ctrl+Cmd+G`)
- Finder right-click context menu integration via Finder Sync extension
- Configurable save location (default: `~/Downloads/clipboard-images`)
- Auto-generated timestamp filenames
- Launch at login support
- macOS notifications on save

## Requirements

- macOS 13.0+

## Install from Release

1. Download `ClipboardSaver.dmg` from the [latest release](https://github.com/shivamsupr/ClipboardSaver/releases/latest)
2. Open the DMG
3. Run in Terminal:
   ```bash
   bash /Volumes/ClipboardSaver/install.sh
   ```
4. Grant **Accessibility** access: System Settings → Privacy & Security → Accessibility → enable ClipboardSaver
5. Enable **Finder extension**: System Settings → Privacy & Security → Extensions → Added Extensions → enable ClipboardSaver

## Build from Source

Requires Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/shivamsupr/ClipboardSaver.git
cd ClipboardSaver
bash build.sh
```

This compiles a universal binary (arm64 + x86_64), installs to `~/Applications`, and creates the default save directory.

## Launch

```bash
open ~/Applications/ClipboardSaver.app
```

## Post-Install Setup

1. **Accessibility access** (required for global hotkey):
   System Settings → Privacy & Security → Accessibility → enable ClipboardSaver

2. **Finder extension** (for right-click "Save Clipboard Image"):
   System Settings → Privacy & Security → Extensions → Added Extensions → enable ClipboardSaver Finder extension

## Usage

- **Keyboard shortcut**: Press `Ctrl+Cmd+G` to save the current clipboard image
- **Right-click in Finder**: Select "Save Clipboard Image" from the context menu
- **Menu bar**: Click the clipboard icon in the menu bar for options

## Build DMG for Distribution

```bash
bash distribute.sh
```

Creates `build/ClipboardSaver.dmg`. Recipients install by running:

```bash
bash /Volumes/ClipboardSaver/install.sh
```
