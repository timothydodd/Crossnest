import AppKit
import CoreGraphics

/// Windows+L locks the screen. On a PC keyboard the Windows key is Command, so this is Cmd+L.
/// Browsers keep Cmd+L for the address bar.
@MainActor
final class LockShortcut {
    /// The modifier the keyboard's Windows key sends: Command on most PC keyboards, Option in "Mac mode".
    var windowsModifier: CGEventFlags = .maskCommand

    static let browserBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.canary",
        "org.chromium.Chromium",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "company.thebrowser.Browser",
        "company.thebrowser.dia",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
        "com.kagi.kagimacOS",
        "app.zen-browser.zen",
    ]

    func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        guard type == .keyDown, event.keyCode == KeyCode.l, event.hasExactly(windowsModifier) else { return false }
        // Browsers use Cmd+L for the address bar; only matters when the Windows key sends Command.
        if windowsModifier == .maskCommand,
           let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           Self.browserBundleIDs.contains(front) {
            return false
        }
        if !event.isAutorepeat {
            DispatchQueue.main.async { ScreenLock.lockNow() }
        }
        return true
    }
}

enum ScreenLock {
    /// Locks immediately, the same as Ctrl+Cmd+Q.
    static func lockNow() {
        typealias LockFunction = @convention(c) () -> Int32
        if let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY),
           let symbol = dlsym(handle, "SACLockScreenImmediate") {
            _ = unsafeBitCast(symbol, to: LockFunction.self)()
            return
        }
        // Fallback: press Ctrl+Cmd+Q, the built-in lock shortcut.
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCode.q), keyDown: keyDown)
            event?.flags = [.maskCommand, .maskControl]
            event?.setIntegerValueField(.eventSourceUserData, value: EventTap.syntheticMarker)
            event?.post(tap: .cghidEventTap)
        }
    }
}
