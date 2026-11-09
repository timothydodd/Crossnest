import AppKit
import ApplicationServices

/// A window that can appear in the Alt+Tab switcher.
struct SwitcherWindow: Identifiable {
    let id = UUID()
    let app: NSRunningApplication
    let element: AXUIElement
    let title: String
    let isMinimized: Bool

    var appName: String { app.localizedName ?? "App" }
    var icon: NSImage { app.icon ?? NSWorkspace.shared.icon(for: .application) }
    /// Shown under the icon: the window title, or the app name for untitled windows.
    var label: String { title.isEmpty ? appName : title }

    /// Brings the window to the front, un-minimizing or un-hiding it if needed.
    func focus() {
        if app.isHidden { app.unhide() }
        if isMinimized {
            AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(appElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        app.activate()
    }
}

enum WindowList {
    /// Every standard window of every regular app, most recently used first (front-to-back screen order),
    /// then hidden apps' windows, then minimized windows.
    /// Talks to every app over Accessibility, so call it off the main thread.
    static func current() -> [SwitcherWindow] {
        // Default limit for every Accessibility call in this process (otherwise ~6s per call),
        // so one busy app can't stall the switcher.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.2)
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != ownPID && !$0.isTerminated
        }

        var screenOrder: [CGWindowID: Int] = [:]
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        for (index, window) in info.enumerated() where (window[kCGWindowLayer as String] as? Int) == 0 {
            if let number = window[kCGWindowNumber as String] as? CGWindowID { screenOrder[number] = index }
        }

        var ranked: [(window: SwitcherWindow, rank: Int)] = []
        for (appIndex, app) in apps.enumerated() {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            let windows: [AXUIElement] = appElement.attribute(kAXWindowsAttribute) ?? []
            for element in windows {
                let subrole: String? = element.attribute(kAXSubroleAttribute)
                guard subrole == kAXStandardWindowSubrole || subrole == kAXDialogSubrole else { continue }
                let minimized: Bool = element.attribute(kAXMinimizedAttribute) ?? false
                let window = SwitcherWindow(app: app, element: element,
                                            title: element.attribute(kAXTitleAttribute) ?? "",
                                            isMinimized: minimized)
                let rank: Int
                if let id = element.windowID, let order = screenOrder[id] {
                    rank = order
                } else {
                    rank = (minimized ? 200_000 : 100_000) + appIndex
                }
                ranked.append((window, rank))
            }
        }
        return ranked.sorted { $0.rank < $1.rank }.map(\.window)
    }
}

extension AXUIElement {
    func attribute<T>(_ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    var windowID: CGWindowID? {
        var id: CGWindowID = 0
        return _AXUIElementGetWindow(self, &id) == .success ? id : nil
    }
}

/// Private but long-standing API that maps an accessibility window to its window-server ID.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError
