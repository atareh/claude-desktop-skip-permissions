#!/bin/bash
# Uninstall claude-auto-allow
set -euo pipefail

APP_DEST="/Applications/ClaudeAutoAllow.app"
PLIST_DEST="$HOME/Library/LaunchAgents/com.claude.auto-allow.plist"

echo "Uninstalling claude-auto-allow..."

launchctl unload "$PLIST_DEST" 2>/dev/null || true
echo "  Stopped background service"

rm -f "$PLIST_DEST"
echo "  Removed LaunchAgent"

rm -rf "$APP_DEST"
echo "  Removed $APP_DEST"

rm -f /tmp/claude-auto-allow.log
echo "  Removed log file"

echo ""
echo "Done. You can also remove it from System Settings > Accessibility."
