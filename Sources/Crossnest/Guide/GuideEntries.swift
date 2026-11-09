import Foundation

/// One row of the "Where is it on Mac?" guide: a Windows thing and its Mac equivalent.
struct GuideEntry: Identifiable {
    enum Section: String, CaseIterable, Identifiable {
        case places = "Apps and places"
        case shortcuts = "Keyboard shortcuts"
        case tasks = "Everyday tasks"
        var id: String { rawValue }
    }

    enum Action {
        case openApp(bundleID: String)
        case openURL(String)

        var label: String {
            switch self {
            case .openApp: "Open"
            case .openURL: "Show me"
            }
        }
    }

    let section: Section
    let windows: String
    let mac: String
    let how: String
    var action: Action? = nil

    var id: String { windows }

    func matches(_ query: String) -> Bool {
        query.isEmpty || [windows, mac, how].contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

enum Guide {
    static let entries: [GuideEntry] = [
        // MARK: Apps and places
        GuideEntry(section: .places, windows: "Control Panel / Settings", mac: "System Settings",
                   how: "Apple menu () › System Settings, or press Cmd+Space and type \"settings\".",
                   action: .openURL("x-apple.systempreferences:")),
        GuideEntry(section: .places, windows: "File Explorer", mac: "Finder",
                   how: "The blue face at the left end of the Dock. Cmd+N opens a new window while Finder is in front.",
                   action: .openApp(bundleID: "com.apple.finder")),
        GuideEntry(section: .places, windows: "Task Manager", mac: "Activity Monitor",
                   how: "Shows what's running and what's using memory or CPU. Find it in Applications › Utilities, or with Cmd+Space.",
                   action: .openApp(bundleID: "com.apple.ActivityMonitor")),
        GuideEntry(section: .places, windows: "Start menu", mac: "Spotlight and the Applications folder",
                   how: "Press Cmd+Space and start typing an app's name, then press Return. All apps live in the Applications folder in Finder."),
        GuideEntry(section: .places, windows: "Taskbar", mac: "Dock",
                   how: "The row of icons at the bottom. A small dot under an icon means the app is open."),
        GuideEntry(section: .places, windows: "System tray / notification area", mac: "Menu bar and Control Center",
                   how: "Status icons sit at the top right of the screen. Wi-Fi, sound and brightness are in Control Center (the two-switch icon)."),
        GuideEntry(section: .places, windows: "Recycle Bin", mac: "Trash",
                   how: "At the right end of the Dock. Cmd+Delete moves a selected file to the Trash."),
        GuideEntry(section: .places, windows: "Program Files", mac: "Applications folder",
                   how: "In the Finder sidebar. Each app is a single item you can move or delete."),
        GuideEntry(section: .places, windows: "This PC", mac: "Computer",
                   how: "In Finder, choose Go › Computer (Cmd+Shift+C) to see your disks and drives."),
        GuideEntry(section: .places, windows: "Command Prompt / PowerShell", mac: "Terminal",
                   how: "Applications › Utilities › Terminal. It runs zsh, which is close to Linux shells.",
                   action: .openApp(bundleID: "com.apple.Terminal")),
        GuideEntry(section: .places, windows: "Notepad", mac: "TextEdit",
                   how: "Choose Format › Make Plain Text, or turn on \"TextEdit starts in plain text\" in Crossnest's General settings.",
                   action: .openApp(bundleID: "com.apple.TextEdit")),
        GuideEntry(section: .places, windows: "Paint / Photos viewer", mac: "Preview",
                   how: "Opens images and PDFs. Use the Markup toolbar (pen icon) to draw, crop and add text.",
                   action: .openApp(bundleID: "com.apple.Preview")),
        GuideEntry(section: .places, windows: "Snipping Tool", mac: "Screenshot",
                   how: "Press Cmd+Shift+5 for the screenshot and screen recording toolbar.",
                   action: .openApp(bundleID: "com.apple.screenshot.launcher")),
        GuideEntry(section: .places, windows: "Device Manager / System Information", mac: "System Information",
                   how: "Hold Option and choose Apple menu () › System Information.",
                   action: .openApp(bundleID: "com.apple.SystemProfiler")),
        GuideEntry(section: .places, windows: "Windows Update", mac: "Software Update",
                   how: "System Settings › General › Software Update.",
                   action: .openURL("x-apple.systempreferences:com.apple.Software-Update-Settings.extension")),

        // MARK: Keyboard shortcuts
        GuideEntry(section: .shortcuts, windows: "Ctrl+C, Ctrl+V, Ctrl+X, Ctrl+Z", mac: "Cmd+C, Cmd+V, Cmd+X, Cmd+Z",
                   how: "Most Ctrl shortcuts use the Command (⌘) key on a Mac, which is where Alt is on a PC keyboard."),
        GuideEntry(section: .shortcuts, windows: "Alt+Tab", mac: "Cmd+Tab",
                   how: "Switches between apps. To switch between windows of the same app, press Cmd+` (the key above Tab)."),
        GuideEntry(section: .shortcuts, windows: "Alt+F4", mac: "Cmd+Q or Cmd+W",
                   how: "Cmd+W closes the window. Cmd+Q quits the whole app; closing a window on a Mac often leaves the app running."),
        GuideEntry(section: .shortcuts, windows: "Ctrl+Alt+Delete / End task", mac: "Cmd+Option+Esc",
                   how: "Opens Force Quit, where you can close an app that has stopped responding."),
        GuideEntry(section: .shortcuts, windows: "Print Screen", mac: "Cmd+Shift+3",
                   how: "Captures the whole screen. Cmd+Shift+4 lets you drag to capture an area; press Space afterwards to capture one window."),
        GuideEntry(section: .shortcuts, windows: "Windows+L (lock)", mac: "Ctrl+Cmd+Q",
                   how: "Locks the screen straight away."),
        GuideEntry(section: .shortcuts, windows: "Windows+D (show desktop)", mac: "Cmd+F3, or spread thumb and three fingers",
                   how: "Pushes all windows aside. On some keyboards press fn+F11 instead."),
        GuideEntry(section: .shortcuts, windows: "Home / End", mac: "Cmd+Left / Cmd+Right",
                   how: "Moves to the start or end of the line. Cmd+Up and Cmd+Down go to the top and bottom. Crossnest can make Home and End work like a PC."),
        GuideEntry(section: .shortcuts, windows: "Ctrl+Left / Ctrl+Right", mac: "Option+Left / Option+Right",
                   how: "Jumps one word at a time. Option+Delete deletes a whole word."),
        GuideEntry(section: .shortcuts, windows: "Delete (forward delete)", mac: "fn+Delete",
                   how: "The Mac's Delete key works like Backspace. Hold fn to delete the character after the cursor."),
        GuideEntry(section: .shortcuts, windows: "F2 (rename)", mac: "Return",
                   how: "In Finder, select a file and press Return to rename it."),
        GuideEntry(section: .shortcuts, windows: "Enter (open file)", mac: "Cmd+O or Cmd+Down",
                   how: "Opens the selected file or folder in Finder. Cmd+Up goes back to the parent folder."),
        GuideEntry(section: .shortcuts, windows: "Ctrl+Shift+Esc", mac: "Cmd+Space, then \"Activity Monitor\"",
                   how: "The quickest way to see what's running."),

        // MARK: Everyday tasks
        GuideEntry(section: .tasks, windows: "Right-click", mac: "Two-finger click or Control+click",
                   how: "On a trackpad, click with two fingers. On a mouse the right button works as usual."),
        GuideEntry(section: .tasks, windows: "Cut and paste a file", mac: "Cmd+C, then Cmd+Option+V",
                   how: "Copy the file as usual. Holding Option when you paste moves it instead of copying it."),
        GuideEntry(section: .tasks, windows: "Properties", mac: "Get Info (Cmd+I)",
                   how: "Shows a file's size, location and which app opens it."),
        GuideEntry(section: .tasks, windows: "Change the default app for a file type", mac: "Get Info › Open with › Change All",
                   how: "Select a file, press Cmd+I, pick an app under \"Open with\", then click Change All."),
        GuideEntry(section: .tasks, windows: "Uninstall a program", mac: "Drag the app to the Trash",
                   how: "Delete it from the Applications folder. A few apps include their own uninstaller."),
        GuideEntry(section: .tasks, windows: "Maximize a window", mac: "Green button or double-click the title bar",
                   how: "The green button makes a window full screen. Hold Option and click it to enlarge the window without going full screen."),
        GuideEntry(section: .tasks, windows: "Snap a window to half the screen", mac: "Drag to an edge, or fn+Ctrl+arrow keys",
                   how: "Or hover over the green button and pick a layout. The Window menu has the same options under Move & Resize."),
        GuideEntry(section: .tasks, windows: "Connect to Wi-Fi", mac: "Wi-Fi icon in the menu bar",
                   how: "At the top right of the screen, or in Control Center."),
        GuideEntry(section: .tasks, windows: "Map a network drive", mac: "Finder › Go › Connect to Server (Cmd+K)",
                   how: "Type smb://server-name/share, the same shares you'd reach with \\\\server\\share on Windows."),
    ]
}
