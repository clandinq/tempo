#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# build.sh - builds Tempo.app using swiftc directly (no Xcode required)
# Tested with macOS Command Line Tools (Swift 5.8) on macOS Ventura
# ---------------------------------------------------------------------------
set -euo pipefail

PROJ_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$PROJ_DIR/Tempo/Sources/Tempo"
RESOURCES="$PROJ_DIR/Tempo/Resources"
OUT_DIR="$PROJ_DIR/.build"
APP="$OUT_DIR/Tempo.app"

# Pick the best available macOS SDK
SDK="$(xcrun --show-sdk-path 2>/dev/null || echo /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk)"
# Prefer macOS 13.x SDK if available
for v in 13.3 13.1 13.0 14.0 12.3; do
    candidate="/Library/Developer/CommandLineTools/SDKs/MacOSX${v}.sdk"
    if [ -d "$candidate" ]; then SDK="$candidate"; break; fi
done

echo "SDK: $SDK"
echo "Building Tempo..."

# Create app bundle layout
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

# Compile all Swift sources
swiftc \
    -sdk "$SDK" \
    -target x86_64-apple-macos13.0 \
    -framework AppKit \
    -framework SwiftUI \
    -framework Charts \
    -framework Combine \
    -framework UserNotifications \
    -O \
    "$SRC/Models.swift" \
    "$SRC/Formatters.swift" \
    "$SRC/Settings.swift" \
    "$SRC/NotificationManager.swift" \
    "$SRC/Store.swift" \
    "$SRC/InsightsView.swift" \
    "$SRC/HistoryView.swift" \
    "$SRC/ManageProjectsView.swift" \
    "$SRC/SettingsView.swift" \
    "$SRC/MenuBarController.swift" \
    "$SRC/AppDelegate.swift" \
    "$SRC/main.swift" \
    -o "$APP/Contents/MacOS/Tempo"

# Copy Info.plist and assets
cp "$RESOURCES/Info.plist" "$APP/Contents/"
cp "$RESOURCES/tempo_logo.png" "$APP/Contents/Resources/"

echo ""
echo "Build succeeded: $APP"
echo ""

# Install to /Applications if --install flag is passed
if [[ "${1:-}" == "--install" ]]; then
    DEST="/Applications/Tempo.app"
    echo "Installing to $DEST ..."
    rm -rf "$DEST"
    cp -r "$APP" "$DEST"
    # Remove quarantine flag so Gatekeeper doesn't block unsigned binary
    xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
    echo "Installed. Launch from Spotlight or: open '$DEST'"
else
    echo "To run:    open '$APP'"
    echo "To install: $0 --install"
fi
