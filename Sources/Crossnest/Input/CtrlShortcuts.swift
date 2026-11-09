import AppKit
import CoreGraphics

/// PC-style Ctrl shortcuts: Ctrl+C becomes Cmd+C, Ctrl+V becomes Cmd+V, and so on, by rewriting the
/// key event in place. Terminals keep Ctrl+C (stop the running command); there, Ctrl+Shift+C/V copy
/// and paste, as in Windows Terminal.
@MainActor
final class CtrlShortcuts {
    /// Key codes are physical positions on a US (ANSI) layout.
    private static let remappedKeys: Set<Int64> = [
        0,   // A  select all
        11,  // B  bold
        8,   // C  copy
        3,   // F  find
        34,  // I  italic
        37,  // L  address bar
        45,  // N  new
        31,  // O  open
        35,  // P  print
        15,  // R  reload
        1,   // S  save
        17,  // T  new tab
        32,  // U  underline
        9,   // V  paste
        13,  // W  close tab/window
        7,   // X  cut
        6,   // Z  undo
        16,  // Y  redo (becomes Cmd+Shift+Z)
    ]
    private static let yKey: Int64 = 16
    private static let cKey: Int64 = 8
    private static let vKey: Int64 = 9

    static let terminalBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "org.alacritty",
        "com.github.wez.wezterm",
        "co.zeit.hyper",
        "com.microsoft.VSCode.terminal",
    ]

    /// Rewrites the event if it's a PC Ctrl shortcut. Returns true when it changed the event
    /// (the event should then go on to the app, not be swallowed).
    func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        guard type == .keyDown || type == .keyUp else { return false }
        let key = event.keyCode
        guard Self.remappedKeys.contains(key) else { return false }
        let withShift = event.hasExactly([.maskControl, .maskShift])
        guard event.hasExactly(.maskControl) || withShift else { return false }

        let inTerminal = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            .map(Self.terminalBundleIDs.contains) ?? false
        var flags = event.flags.subtracting([.maskControl, .maskShift])

        if inTerminal {
            // Only Ctrl+Shift+C / Ctrl+Shift+V, becoming Cmd+C / Cmd+V.
            guard withShift, key == Self.cKey || key == Self.vKey else { return false }
            flags.insert(.maskCommand)
        } else {
            flags.insert(.maskCommand)
            if withShift || key == Self.yKey { flags.insert(.maskShift) }
            if key == Self.yKey { event.setIntegerValueField(.keyboardEventKeycode, value: 6) }  // Z
        }
        event.flags = flags
        return true
    }
}
