import Cocoa

// Configuration
let pollInterval: TimeInterval = {
    if let env = ProcessInfo.processInfo.environment["CLAUDE_AUTO_ALLOW_INTERVAL"],
       let val = TimeInterval(env) {
        return val
    }
    return 1.0
}()

let cooldown: TimeInterval = 0.8
let verbose = CommandLine.arguments.contains("--verbose")

// The action name as it appears in Notification Center's AX tree
let allowAction = "Allow once"

// MARK: - Helpers

func getStringAttr(_ element: AXUIElement, _ attr: String) -> String? {
    var value: CFTypeRef?
    let err = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
    if err == .success, let str = value as? String {
        return str
    }
    return nil
}

func checkAccessibility() -> Bool {
    let trusted = AXIsProcessTrustedWithOptions(
        [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
    )
    if trusted { return true }

    // Fallback: try an actual AX call
    for app in NSWorkspace.shared.runningApplications {
        if app.localizedName == "Finder" {
            let el = AXUIElementCreateApplication(app.processIdentifier)
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(el, kAXWindowsAttribute as CFString, &value)
            if result == .success || result == .noValue {
                return true
            }
        }
    }
    return false
}

func timestamp() -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f.string(from: Date())
}

// MARK: - Notification Center scanning

func findNotificationCenter() -> AXUIElement? {
    for app in NSWorkspace.shared.runningApplications {
        if app.localizedName == "Notification Center" {
            return AXUIElementCreateApplication(app.processIdentifier)
        }
    }
    return nil
}

// Result type to distinguish between "allowed" and "expanded a stack"
enum ScanResult {
    case allowed(String)
    case expandedStack
}

// Click ONE notification and return immediately so Notification Center can re-render.
// If notifications are stacked, expand the stack first, then allow on the next cycle.
func scanAndAllowOne(_ element: AXUIElement, depth: Int = 0) -> ScanResult? {
    if depth > 10 { return nil }

    let subrole = getStringAttr(element, kAXSubroleAttribute as String) ?? ""
    let desc = getStringAttr(element, kAXDescriptionAttribute as String) ?? ""

    if subrole == "AXNotificationCenterAlert" && desc.contains("Claude") {
        var actions: CFArray?
        AXUIElementCopyActionNames(element, &actions)

        if let actionList = actions as? [String] {
            // First, try to find and click "Allow once"
            for action in actionList {
                if action.contains(allowAction) {
                    let err = AXUIElementPerformAction(element, action as CFString)
                    if err == .success {
                        let parts = desc.components(separatedBy: ", ")
                        let shortDesc = parts.count > 2 ? parts[2] : desc
                        return .allowed(shortDesc)
                    }
                }
            }

            // No "Allow once" found — this is likely a stacked notification group.
            // Try "Show Details" first (expands the stack), then fall back to "AXPress".
            for expandAction in ["Show Details", "AXPress"] {
                for action in actionList {
                    if action.contains(expandAction) {
                        let err = AXUIElementPerformAction(element, action as CFString)
                        if err == .success {
                            if verbose { print("[\(timestamp())] Expanding stacked notifications via \(expandAction)") }
                            return .expandedStack
                        }
                    }
                }
            }
        }
    }

    var children: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
    if let children = children as? [AXUIElement] {
        for child in children {
            if let result = scanAndAllowOne(child, depth: depth + 1) {
                return result
            }
        }
    }

    return nil
}

func checkNotifications() -> ScanResult? {
    guard let nc = findNotificationCenter() else { return nil }

    var windows: CFTypeRef?
    AXUIElementCopyAttributeValue(nc, kAXWindowsAttribute as CFString, &windows)

    guard let windowList = windows as? [AXUIElement] else { return nil }

    for window in windowList {
        if let result = scanAndAllowOne(window) {
            return result
        }
    }

    return nil
}

// MARK: - Commands

if CommandLine.arguments.contains("--test") {
    print("Checking accessibility permissions...")
    if checkAccessibility() {
        print("OK — accessibility permissions granted.")
    } else {
        print("ERROR: Accessibility access required.")
        print("  System Settings > Privacy & Security > Accessibility")
        exit(1)
    }
    print("")
    print("Checking Notification Center...")
    if findNotificationCenter() != nil {
        print("OK — Notification Center found.")
    } else {
        print("WARNING — Notification Center not found.")
    }
    print("")
    print("Checking for Claude notifications...")
    if let result = checkNotifications() {
        switch result {
        case .allowed(let desc):
            print("Found and clicked: \(desc)")
        case .expandedStack:
            print("Found stacked notifications — expanded them.")
        }
    } else {
        print("No pending Claude permission notifications.")
    }
    exit(0)
}

if CommandLine.arguments.contains("--help") || CommandLine.arguments.contains("-h") {
    print("Usage: claude-auto-allow [--test] [--verbose]")
    print("")
    print("  --test     Check permissions and click any pending notification")
    print("  --verbose  Log every poll cycle to stdout")
    print("")
    print("Environment variables:")
    print("  CLAUDE_AUTO_ALLOW_INTERVAL  Poll interval in seconds (default: 1)")
    exit(0)
}

// MARK: - Main loop

if !checkAccessibility() {
    print("ERROR: Accessibility access required.")
    print("  System Settings > Privacy & Security > Accessibility")
    print("  Enable access for this app, then re-run.")
    exit(1)
}

print("claude-auto-allow is running")
print("  Watching: Notification Center for Claude permission alerts")
print("  Action:   \(allowAction)")
print("  Interval: \(pollInterval)s (\(cooldown)s cooldown after clicks)")
print("")
print("Press Ctrl+C to stop.")
print("")

setbuf(stdout, nil)

while true {
    if let result = checkNotifications() {
        switch result {
        case .allowed(let desc):
            print("[\(timestamp())] Allowed: \(desc)")
            Thread.sleep(forTimeInterval: cooldown)
        case .expandedStack:
            // Short pause to let Notification Center re-render expanded stack
            Thread.sleep(forTimeInterval: 0.3)
        }
    } else {
        if verbose { print("[\(timestamp())] No notifications") }
        Thread.sleep(forTimeInterval: pollInterval)
    }
}
