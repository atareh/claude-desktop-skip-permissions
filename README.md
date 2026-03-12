# claude-auto-allow

Auto-accepts Claude Desktop permission notifications so you can walk away from agentic tasks.

## The problem

Claude Desktop asks for permission before running tools (bash commands, file edits, etc.). If you step away, it just sits and waits. Your 10-minute task becomes 40 minutes of babysitting permission dialogs.

> **Note:** Claude Code CLI has `--dangerously-skip-permissions`. Claude Desktop does not. This fills that gap.

## How it works

A small native macOS app watches Notification Center for Claude permission alerts. When one appears, it triggers the "Allow once" action. Polls every 1 second, uses the macOS Accessibility API directly (no AppleScript, no System Events), and doesn't interfere with clipboard or input.

## Requirements

- macOS
- Xcode Command Line Tools (`xcode-select --install`)
- Accessibility permissions (one-time setup)
- Claude Desktop notifications enabled

## Setup

### Option A: Run in a terminal (simple)

```bash
git clone https://github.com/atareh/claude-auto-allow.git
cd claude-auto-allow

# Build
swiftc -O -o claude-auto-allow Sources/main.swift -framework Cocoa

# Run
./claude-auto-allow
```

Runs in the foreground. Ctrl+C to stop.

> You'll need to add the compiled binary to **System Settings > Privacy & Security > Accessibility**.

### Option B: Install as a background service (set and forget)

```bash
git clone https://github.com/atareh/claude-auto-allow.git
cd claude-auto-allow
./install.sh
```

This builds the app, copies it to `/Applications`, and installs a LaunchAgent that:
- Starts automatically on login
- Runs in the background (no terminal needed)
- Restarts if it crashes
- Logs to `/tmp/claude-auto-allow.log`

After install, grant Accessibility permissions:
1. Open **System Settings > Privacy & Security > Accessibility**
2. Click **+** and add `/Applications/ClaudeAutoAllow.app`
3. Toggle it ON

To remove:

```bash
./uninstall.sh
```

## Usage

```bash
./claude-auto-allow           # run in foreground
./claude-auto-allow --verbose # log every poll cycle
./claude-auto-allow --test    # check permissions and exit
```

Check logs (when running as a service):

```bash
tail -f /tmp/claude-auto-allow.log
```

### Configuration

| Environment Variable | Default | Description |
|---|---|---|
| `CLAUDE_AUTO_ALLOW_INTERVAL` | `1` | Poll interval in seconds |

## How it's built

- Native Swift binary — uses the macOS Accessibility API directly
- Watches Notification Center, not Claude's windows — no clipboard interference
- Looks for `AXNotificationCenterAlert` elements with "Claude" in the description
- Triggers the "Allow once" custom action on matching notifications
- ~100 lines of logic

## License

MIT
