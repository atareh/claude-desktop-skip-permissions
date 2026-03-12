#!/bin/bash
# Install claude-auto-allow as a background LaunchAgent
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ClaudeAutoAllow.app"
APP_SRC="$SCRIPT_DIR/$APP_NAME"
APP_DEST="/Applications/$APP_NAME"
PLIST_NAME="com.claude.auto-allow.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME"

echo "Installing claude-auto-allow..."

# Build from source if the .app doesn't contain the binary
if [[ ! -f "$APP_SRC/Contents/MacOS/claude-auto-allow" ]]; then
  echo "  Building from source..."
  if ! command -v swiftc &>/dev/null; then
    echo "ERROR: Xcode Command Line Tools required."
    echo "  Install with: xcode-select --install"
    exit 1
  fi
  mkdir -p "$APP_SRC/Contents/MacOS"
  swiftc -O -o "$APP_SRC/Contents/MacOS/claude-auto-allow" "$SCRIPT_DIR/Sources/main.swift" -framework Cocoa
  codesign --force --sign - "$APP_SRC"
fi

# Copy to /Applications
echo "  Copying to $APP_DEST"
cp -R "$APP_SRC" "$APP_DEST"

# Install LaunchAgent
mkdir -p "$HOME/Library/LaunchAgents"
launchctl unload "$PLIST_DEST" 2>/dev/null || true

cat > "$PLIST_DEST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claude.auto-allow</string>
    <key>ProgramArguments</key>
    <array>
        <string>${APP_DEST}/Contents/MacOS/claude-auto-allow</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/claude-auto-allow.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/claude-auto-allow.log</string>
    <key>ThrottleInterval</key>
    <integer>5</integer>
</dict>
</plist>
EOF

launchctl load "$PLIST_DEST"
echo "  Started background service"

echo ""
echo "Done. claude-auto-allow is running."
echo ""
echo "IMPORTANT — Grant Accessibility permissions (one-time):"
echo "  1. Open System Settings > Privacy & Security > Accessibility"
echo "  2. Click + and add /Applications/ClaudeAutoAllow.app"
echo "  3. Make sure the toggle is ON"
echo ""
echo "Logs: tail -f /tmp/claude-auto-allow.log"
echo "Uninstall: ./uninstall.sh"
