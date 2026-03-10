#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ClipboardSaver"
BUNDLE_DIR="${SCRIPT_DIR}/build/${APP_NAME}.app"
INSTALL_DIR="$HOME/Applications/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
CLIPBOARD_DIR="$HOME/Downloads/clipboard-images"

SOURCES=(
    "${SCRIPT_DIR}/main.swift"
    "${SCRIPT_DIR}/PreferencesManager.swift"
    "${SCRIPT_DIR}/ClipboardManager.swift"
    "${SCRIPT_DIR}/HotKeyManager.swift"
    "${SCRIPT_DIR}/ShortcutRecorderWindow.swift"
    "${SCRIPT_DIR}/AppDelegate.swift"
)

echo "=== Building ${APP_NAME} ==="

# Clean previous build
rm -rf "${SCRIPT_DIR}/build"

# Create bundle structure
echo "Creating app bundle structure..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Create default save directory
mkdir -p "${CLIPBOARD_DIR}"

# Compile as universal binary (arm64 + x86_64)
echo "Compiling Swift sources (universal binary)..."

swiftc \
    -o "${MACOS_DIR}/${APP_NAME}-arm64" \
    -framework AppKit \
    -framework Carbon \
    -framework UserNotifications \
    -framework ServiceManagement \
    -framework UniformTypeIdentifiers \
    -target arm64-apple-macos13.0 \
    -swift-version 5 \
    -O \
    "${SOURCES[@]}"

swiftc \
    -o "${MACOS_DIR}/${APP_NAME}-x86_64" \
    -framework AppKit \
    -framework Carbon \
    -framework UserNotifications \
    -framework ServiceManagement \
    -framework UniformTypeIdentifiers \
    -target x86_64-apple-macos13.0 \
    -swift-version 5 \
    -O \
    "${SOURCES[@]}"

# Create universal binary
lipo -create \
    "${MACOS_DIR}/${APP_NAME}-arm64" \
    "${MACOS_DIR}/${APP_NAME}-x86_64" \
    -output "${MACOS_DIR}/${APP_NAME}"

rm "${MACOS_DIR}/${APP_NAME}-arm64" "${MACOS_DIR}/${APP_NAME}-x86_64"

# Copy Info.plist and icon
echo "Installing Info.plist and icon..."
cp "${SCRIPT_DIR}/Info.plist" "${CONTENTS_DIR}/Info.plist"
cp "${SCRIPT_DIR}/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"

# Make executable
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Build Finder Sync Extension
echo "Building Finder Sync Extension..."
EXT_NAME="ClipboardSaverFinder"
EXT_DIR="${CONTENTS_DIR}/PlugIns/${EXT_NAME}.appex"
EXT_MACOS_DIR="${EXT_DIR}/Contents/MacOS"
mkdir -p "${EXT_MACOS_DIR}"

swiftc \
    -parse-as-library \
    -module-name "${EXT_NAME}" \
    -o "${EXT_MACOS_DIR}/${EXT_NAME}-arm64" \
    -framework FinderSync \
    -target arm64-apple-macos13.0 \
    -swift-version 5 \
    -O \
    -Xlinker -e -Xlinker _NSExtensionMain \
    "${SCRIPT_DIR}/FinderSync.swift"

swiftc \
    -parse-as-library \
    -module-name "${EXT_NAME}" \
    -o "${EXT_MACOS_DIR}/${EXT_NAME}-x86_64" \
    -framework FinderSync \
    -target x86_64-apple-macos13.0 \
    -swift-version 5 \
    -O \
    -Xlinker -e -Xlinker _NSExtensionMain \
    "${SCRIPT_DIR}/FinderSync.swift"

lipo -create \
    "${EXT_MACOS_DIR}/${EXT_NAME}-arm64" \
    "${EXT_MACOS_DIR}/${EXT_NAME}-x86_64" \
    -output "${EXT_MACOS_DIR}/${EXT_NAME}"

rm "${EXT_MACOS_DIR}/${EXT_NAME}-arm64" "${EXT_MACOS_DIR}/${EXT_NAME}-x86_64"

cp "${SCRIPT_DIR}/FinderSync-Info.plist" "${EXT_DIR}/Contents/Info.plist"
chmod +x "${EXT_MACOS_DIR}/${EXT_NAME}"

# Sign extension with sandbox entitlements first, then main app (no --deep to preserve extension signature)
echo "Code signing (ad-hoc)..."
codesign --force --sign - --entitlements "${SCRIPT_DIR}/FinderSync.entitlements" "${EXT_DIR}"
codesign --force --sign - "${BUNDLE_DIR}"

# Verify signature
codesign --verify --verbose "${BUNDLE_DIR}" 2>&1 || true

# Install to ~/Applications
echo "Installing to ~/Applications..."
rm -rf "${INSTALL_DIR}"
cp -R "${BUNDLE_DIR}" "${INSTALL_DIR}"

echo ""
echo "=== Build Successful ==="
echo "App bundle: ${INSTALL_DIR}"
echo "Default save dir: ${CLIPBOARD_DIR}"
echo ""
echo "To launch:"
echo "  open '${INSTALL_DIR}'"
echo ""
echo "To create a distributable DMG:"
echo "  bash distribute.sh"
