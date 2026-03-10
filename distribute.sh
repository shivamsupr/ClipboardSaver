#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ClipboardSaver"
BUILD_DIR="${SCRIPT_DIR}/build"
BUNDLE_DIR="${BUILD_DIR}/${APP_NAME}.app"
DMG_DIR="${BUILD_DIR}/dmg-stage"
DMG_OUTPUT="${BUILD_DIR}/${APP_NAME}.dmg"

# Build first if needed
if [ ! -d "${BUNDLE_DIR}" ]; then
    echo "App not built yet, running build.sh first..."
    bash "${SCRIPT_DIR}/build.sh"
fi

echo "=== Creating DMG ==="

# Clean staging area
rm -rf "${DMG_DIR}" "${DMG_OUTPUT}"
mkdir -p "${DMG_DIR}"

# Copy app to staging
cp -R "${BUNDLE_DIR}" "${DMG_DIR}/"

# Create symlink to /Applications for drag-and-drop install
ln -s /Applications "${DMG_DIR}/Applications"

# Create install script that users run via Terminal
# This is the ONLY reliable way to bypass Gatekeeper without notarization
cat > "${DMG_DIR}/install.sh" << 'SCRIPT'
#!/bin/bash
# ClipboardSaver Installer
# Run this script to install and bypass macOS Gatekeeper.
#
# Usage:
#   Open Terminal and run:
#     bash /Volumes/ClipboardSaver/install.sh

set -euo pipefail

APP_NAME="ClipboardSaver"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="${SCRIPT_DIR}/${APP_NAME}.app"
DEST="/Applications/${APP_NAME}.app"

echo ""
echo "=== Installing ${APP_NAME} ==="

if [ ! -d "$SOURCE" ]; then
    echo "Error: ${APP_NAME}.app not found next to this script."
    echo "Make sure you're running this from the mounted DMG."
    exit 1
fi

# Copy to /Applications
echo "Copying to /Applications..."
rm -rf "$DEST"
cp -R "$SOURCE" "$DEST"

# Strip quarantine — bypasses Gatekeeper
echo "Clearing quarantine flag..."
xattr -cr "$DEST"

# Launch
echo "Launching ${APP_NAME}..."
open "$DEST"

echo ""
echo "=== Done! ==="
echo ""
echo "Next step: Grant Accessibility access for global hotkeys:"
echo "  System Settings → Privacy & Security → Accessibility"
echo "  Add and enable ${APP_NAME}"
echo ""
SCRIPT
chmod +x "${DMG_DIR}/install.sh"

# Create README
cat > "${DMG_DIR}/README.txt" << 'README'
ClipboardSaver — Installation
==============================

OPTION 1 — One command (recommended):

  Open Terminal and paste:

    bash /Volumes/ClipboardSaver/install.sh

  This installs to /Applications and clears the
  Gatekeeper warning automatically.


OPTION 2 — Manual drag-and-drop:

  1. Drag ClipboardSaver.app → Applications folder
  2. Open Terminal and paste:
       xattr -cr /Applications/ClipboardSaver.app
  3. Open ClipboardSaver from Applications


After installing, grant Accessibility access:
  System Settings → Privacy & Security → Accessibility
  Add and enable ClipboardSaver
README

# Create DMG
echo "Packaging DMG..."
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_DIR}" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "${DMG_OUTPUT}"

# Clean staging
rm -rf "${DMG_DIR}"

DMG_SIZE=$(du -h "${DMG_OUTPUT}" | cut -f1 | xargs)
echo ""
echo "=== DMG Created ==="
echo "File: ${DMG_OUTPUT}"
echo "Size: ${DMG_SIZE}"
echo ""
echo "Tell your users to open the DMG, then run in Terminal:"
echo ""
echo "  bash /Volumes/ClipboardSaver/install.sh"
echo ""
