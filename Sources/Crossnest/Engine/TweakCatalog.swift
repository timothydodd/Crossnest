import Foundation

/// Every switch Crossnest offers. Each `defaults` key belongs to exactly one tweak,
/// so turning one switch off never undoes part of another.
enum TweakCatalog {
    private static let global = Preferences.globalDomain
    private static let finder = "com.apple.finder"
    private static let dock = "com.apple.dock"
    private static let trackpad = "com.apple.AppleMultitouchTrackpad"
    private static let bluetoothTrackpad = "com.apple.driver.AppleBluetoothMultitouch.trackpad"
    private static let home = FileManager.default.homeDirectoryForCurrentUser
    private static let screenshotsFolder = home.appending(path: "Pictures/Screenshots", directoryHint: .isDirectory)

    private static func pref(_ domain: String, _ key: String, _ value: PrefValue) -> PrefChange {
        PrefChange(domain, key, value)
    }

    static let all: [Tweak] = keyboard + mouse + finderTweaks + windows + system

    // MARK: - Keyboard

    private static let keyboard: [Tweak] = [
        Tweak(
            id: "key-repeat", category: .keyboard,
            title: "Faster key repeat",
            detail: "Holding a key starts repeating sooner and repeats faster.",
            onWindows: "Close to the Windows default repeat speed.",
            kind: .preferences([
                pref(global, "KeyRepeat", .int(2)),
                pref(global, "InitialKeyRepeat", .int(15)),
            ]),
            restart: .logOut
        ),
        Tweak(
            id: "press-and-hold", category: .keyboard,
            title: "Holding a key repeats it",
            detail: "By default, holding a letter on a Mac shows a menu of accented letters instead of repeating it.",
            onWindows: "Holding a key always repeats it.",
            kind: .preferences([pref(global, "ApplePressAndHoldEnabled", .bool(false))]),
            restart: .reopenApps
        ),
        Tweak(
            id: "home-end", category: .keyboard,
            title: "Home and End keys work like a PC",
            detail: "Home and End go to the start and end of the line; Ctrl+Home and Ctrl+End go to the top and bottom. Ctrl+arrows jump by word and Ctrl+Backspace deletes a word. Works in standard Mac apps such as Notes, Mail and TextEdit.",
            onWindows: "On a Mac, Home and End normally scroll the page without moving the cursor.",
            kind: .keyBindings,
            restart: .reopenApps
        ),
        Tweak(
            id: "ctrl-shortcuts", category: .shortcuts,
            title: "Ctrl+C, Ctrl+V and other Ctrl shortcuts work like a PC",
            detail: "Ctrl+C copies, Ctrl+V pastes, and Ctrl+X, Z, Y, A, S, F, N, T, W, P, R and L do what they do on Windows. In Terminal and other terminal apps, Ctrl+C still stops the running command; use Ctrl+Shift+C and Ctrl+Shift+V to copy and paste there.",
            onWindows: "On a Mac these use the Command key instead of Ctrl.",
            kind: .live(.ctrlShortcuts),
            recommended: false
        ),
        Tweak(
            id: "lock-shortcut", category: .shortcuts,
            title: "Windows+L locks the screen",
            detail: "Press the Windows key and L to lock the screen. If your Windows key sends Command, Cmd+L keeps working as the address bar in web browsers.",
            onWindows: "Windows+L locks the PC.",
            kind: .live(.lockShortcut),
            recommended: false
        ),
        Tweak(
            id: "full-keyboard-access", category: .keyboard,
            title: "Tab moves between all buttons in dialogs",
            detail: "Tab reaches every button and control, not just text boxes, and Space presses the highlighted button.",
            onWindows: "Tab always cycles through every control in a dialog.",
            kind: .preferences([pref(global, "AppleKeyboardUIMode", .int(2))]),
            restart: .reopenApps
        ),
        Tweak(
            id: "fn-keys", category: .keyboard,
            title: "Use F1–F12 as standard function keys",
            detail: "F5 refreshes, F2 renames in apps that support it, and so on. Hold fn to use the brightness and volume keys.",
            onWindows: "Most desktop keyboards send F1–F12 by default.",
            kind: .preferences([pref(global, "com.apple.keyboard.fnState", .bool(true))]),
            restart: .logOut,
            recommended: false
        ),
        Tweak(
            id: "smart-punctuation", category: .keyboard,
            title: "Turn off smart quotes and dashes",
            detail: "Stops the Mac turning \" into curly quotes, -- into a dash, and two spaces into a full stop.",
            kind: .preferences([
                pref(global, "NSAutomaticQuoteSubstitutionEnabled", .bool(false)),
                pref(global, "NSAutomaticDashSubstitutionEnabled", .bool(false)),
                pref(global, "NSAutomaticPeriodSubstitutionEnabled", .bool(false)),
            ]),
            restart: .reopenApps,
            recommended: false
        ),
        Tweak(
            id: "autocorrect", category: .keyboard,
            title: "Turn off auto-correct and auto-capitalization",
            detail: "macOS corrects spelling and capitalizes words in every app, not just word processors.",
            onWindows: "Auto-correct is usually limited to apps such as Word.",
            kind: .preferences([
                pref(global, "NSAutomaticSpellingCorrectionEnabled", .bool(false)),
                pref(global, "NSAutomaticCapitalizationEnabled", .bool(false)),
            ]),
            restart: .reopenApps,
            recommended: false
        ),
    ]

    // MARK: - Mouse & trackpad

    private static let mouse: [Tweak] = [
        Tweak(
            id: "scroll-direction", category: .mouse,
            title: "Scroll like a PC",
            detail: "Rolling the wheel down moves the page down. Turns off what Apple calls \"natural\" scrolling, for both mouse and trackpad.",
            onWindows: "Scrolling down always moves the page down.",
            kind: .preferences([pref(global, "com.apple.swipescrolldirection", .bool(false))]),
            restart: .logOut
        ),
        Tweak(
            id: "smooth-scrolling", category: .mouse,
            title: "Smooth scrolling for mouse wheels",
            detail: "Each click of the wheel glides the page instead of jumping it a few lines. Trackpads and Apple mice already scroll smoothly and aren't affected.",
            onWindows: "Windows animates wheel scrolling in most apps.",
            kind: .live(.smoothScrolling),
            recommended: false
        ),
        Tweak(
            id: "mouse-acceleration", category: .mouse,
            title: "Turn off mouse acceleration",
            detail: "The pointer moves the same distance however fast you move the mouse, which many PC users and gamers prefer.",
            onWindows: "Like unticking \"Enhance pointer precision\".",
            kind: .preferences([pref(global, "com.apple.mouse.linear", .bool(true))]),
            restart: .logOut
        ),
        Tweak(
            id: "tap-to-click", category: .mouse,
            title: "Tap to click on the trackpad",
            detail: "A light tap counts as a click, so you don't have to press the trackpad down.",
            onWindows: "Most laptop touchpads have tap to click on.",
            kind: .preferences([
                pref(trackpad, "Clicking", .bool(true)),
                pref(bluetoothTrackpad, "Clicking", .bool(true)),
                pref(global, "com.apple.mouse.tapBehavior", .int(1)),
            ]),
            restart: .logOut
        ),
        Tweak(
            id: "two-finger-right-click", category: .mouse,
            title: "Two-finger click is right-click",
            detail: "Click or tap with two fingers on the trackpad to open the right-click menu.",
            kind: .preferences([
                pref(trackpad, "TrackpadRightClick", .bool(true)),
                pref(bluetoothTrackpad, "TrackpadRightClick", .bool(true)),
            ]),
            restart: .logOut
        ),
        Tweak(
            id: "magic-mouse-right-click", category: .mouse,
            title: "Right side of a Magic Mouse is right-click",
            detail: "Only matters if you use an Apple Magic Mouse. Other mice already right-click.",
            kind: .preferences([
                pref("com.apple.driver.AppleBluetoothMultitouch.mouse", "MouseButtonMode", .string("TwoButton")),
                pref("com.apple.AppleMultitouchMouse", "MouseButtonMode", .string("TwoButton")),
            ]),
            restart: .logOut,
            recommended: false
        ),
    ]

    // MARK: - Finder

    private static let finderTweaks: [Tweak] = [
        Tweak(
            id: "show-extensions", category: .finder,
            title: "Show file extensions",
            detail: "Shows \"report.pdf\" instead of just \"report\", so you can tell file types apart.",
            onWindows: "View › Show › File name extensions in File Explorer.",
            kind: .preferences([pref(global, "AppleShowAllExtensions", .bool(true))]),
            restart: .finder
        ),
        Tweak(
            id: "extension-warning", category: .finder,
            title: "Don't warn when changing an extension",
            detail: "Renaming a file to a different extension no longer asks you to confirm.",
            kind: .preferences([pref(finder, "FXEnableExtensionChangeWarning", .bool(false))]),
            restart: .finder
        ),
        Tweak(
            id: "path-bar", category: .finder,
            title: "Show the path bar",
            detail: "A bar at the bottom of each window shows which folder you're in. Double-click any part to jump there.",
            onWindows: "Like the address bar at the top of File Explorer.",
            kind: .preferences([pref(finder, "ShowPathbar", .bool(true))]),
            restart: .finder
        ),
        Tweak(
            id: "status-bar", category: .finder,
            title: "Show the status bar",
            detail: "Shows how many items are in a folder and how much free space is left.",
            onWindows: "Like the status bar at the bottom of File Explorer.",
            kind: .preferences([pref(finder, "ShowStatusBar", .bool(true))]),
            restart: .finder
        ),
        Tweak(
            id: "list-view", category: .finder,
            title: "Use list view by default",
            detail: "New Finder windows show files in a list with size and date columns.",
            onWindows: "Like the Details view in File Explorer.",
            kind: .preferences([pref(finder, "FXPreferredViewStyle", .string("Nlsv"))]),
            restart: .finder
        ),
        Tweak(
            id: "folders-first", category: .finder,
            title: "Keep folders on top",
            detail: "Folders are listed before files when sorting by name, in windows and on the desktop.",
            onWindows: "File Explorer always lists folders first.",
            kind: .preferences([
                pref(finder, "_FXSortFoldersFirst", .bool(true)),
                pref(finder, "_FXSortFoldersFirstOnDesktop", .bool(true)),
            ]),
            restart: .finder
        ),
        Tweak(
            id: "search-current-folder", category: .finder,
            title: "Search the current folder",
            detail: "Typing in a Finder window's search box searches that folder instead of the whole Mac.",
            onWindows: "File Explorer searches the folder you're in.",
            kind: .preferences([pref(finder, "FXDefaultSearchScope", .string("SCcf"))]),
            restart: .finder
        ),
        Tweak(
            id: "new-window-home", category: .finder,
            title: "New windows open your home folder",
            detail: "New Finder windows show your home folder (Desktop, Documents, Downloads and so on) instead of Recents.",
            kind: .preferences([
                pref(finder, "NewWindowTarget", .string("PfHm")),
                pref(finder, "NewWindowTargetPath", .string(home.absoluteString)),
            ]),
            restart: .finder
        ),
        Tweak(
            id: "no-ds-store", category: .finder,
            title: "Don't leave .DS_Store files on shared and USB drives",
            detail: "Stops Finder creating hidden .DS_Store files that Windows users see on network shares and USB sticks.",
            kind: .preferences([
                pref("com.apple.desktopservices", "DSDontWriteNetworkStores", .bool(true)),
                pref("com.apple.desktopservices", "DSDontWriteUSBStores", .bool(true)),
            ]),
            restart: .finder
        ),
        Tweak(
            id: "hidden-files", category: .finder,
            title: "Show hidden files",
            detail: "Shows files whose names start with a dot, plus system files. You can toggle this any time with Cmd+Shift+.",
            onWindows: "View › Show › Hidden items in File Explorer.",
            kind: .preferences([pref(finder, "AppleShowAllFiles", .bool(true))]),
            restart: .finder,
            recommended: false
        ),
        Tweak(
            id: "full-path-title", category: .finder,
            title: "Show the full path in the window title",
            detail: "The title bar shows /Users/you/Documents instead of just Documents.",
            kind: .preferences([pref(finder, "_FXShowPosixPathInTitle", .bool(true))]),
            restart: .finder,
            recommended: false
        ),
        Tweak(
            id: "drives-on-desktop", category: .finder,
            title: "Show drives on the desktop",
            detail: "Your Mac's disk and any plugged-in drives appear as icons on the desktop.",
            onWindows: "Like the drives listed under This PC.",
            kind: .preferences([
                pref(finder, "ShowHardDrivesOnDesktop", .bool(true)),
                pref(finder, "ShowExternalHardDrivesOnDesktop", .bool(true)),
            ]),
            restart: .finder,
            recommended: false
        ),
        Tweak(
            id: "quit-finder", category: .finder,
            title: "Let Cmd+Q quit Finder",
            detail: "Adds Quit Finder to the Finder menu. Finder normally can't be quit.",
            kind: .preferences([pref(finder, "QuitMenuItem", .bool(true))]),
            restart: .finder,
            recommended: false
        ),
    ]

    // MARK: - Dock & windows

    private static let windows: [Tweak] = [
        Tweak(
            id: "alt-tab", category: .shortcuts,
            title: "Alt+Tab switches between windows",
            detail: "Hold Alt and press Tab to see every open window, keep pressing Tab to move along, and let go to switch. Shift+Tab goes back and Esc cancels. If your Alt key sends Command, this replaces the Mac's Cmd+Tab app switcher.",
            onWindows: "Alt+Tab shows every window, not just every app.",
            kind: .live(.altTab),
            recommended: false
        ),
        Tweak(
            id: "edge-snapping", category: .windows,
            title: "Snap windows by dragging them to a screen edge",
            detail: "Drag a window to the left or right edge to fill that half of the screen, or to the top to fill the whole screen.",
            onWindows: "Like Windows Snap.",
            kind: .preferences([
                pref("com.apple.WindowManager", "EnableTilingByEdgeDrag", .bool(true)),
                pref("com.apple.WindowManager", "EnableTopTilingByEdgeDrag", .bool(true)),
            ]),
            restart: .windowManager
        ),
        Tweak(
            id: "no-tile-gaps", category: .windows,
            title: "No gaps between snapped windows",
            detail: "Snapped windows sit edge to edge instead of leaving a margin around them.",
            onWindows: "Snapped windows touch each other and the screen edges.",
            kind: .preferences([pref("com.apple.WindowManager", "EnableTiledWindowMargins", .bool(false))]),
            restart: .windowManager
        ),
        Tweak(
            id: "double-click-maximize", category: .windows,
            title: "Double-click a title bar to maximize",
            detail: "Double-clicking a window's title bar makes it as large as it needs to be, instead of minimizing it.",
            onWindows: "Double-clicking a title bar maximizes the window.",
            kind: .preferences([pref(global, "AppleActionOnDoubleClick", .string("Maximize"))]),
            restart: .reopenApps
        ),
        Tweak(
            id: "minimize-to-app", category: .windows,
            title: "Minimize windows into their app's icon",
            detail: "Minimized windows tuck into the app's icon in the Dock instead of piling up at the right-hand end.",
            onWindows: "Like minimizing to a taskbar button.",
            kind: .preferences([pref(dock, "minimize-to-application", .bool(true))]),
            restart: .dock
        ),
        Tweak(
            id: "dock-recents", category: .windows,
            title: "Hide recent apps in the Dock",
            detail: "The Dock only shows apps you pinned and apps that are open, without an extra recent-apps section.",
            onWindows: "Like a taskbar without suggested apps.",
            kind: .preferences([pref(dock, "show-recents", .bool(false))]),
            restart: .dock
        ),
        Tweak(
            id: "spaces-order", category: .windows,
            title: "Keep desktops in the order you set",
            detail: "Stops macOS reordering your desktops (Spaces) based on which one you used last.",
            onWindows: "Virtual desktops keep their order.",
            kind: .preferences([pref(dock, "mru-spaces", .bool(false))]),
            restart: .dock
        ),
        Tweak(
            id: "clock-date", category: .windows,
            title: "Always show the date in the menu bar",
            detail: "The clock at the top right shows the day and date, not just the time.",
            onWindows: "Like the date under the clock in the taskbar.",
            kind: .preferences([
                pref("com.apple.menuextra.clock", "ShowDate", .int(1)),
                pref("com.apple.menuextra.clock", "ShowDayOfWeek", .bool(true)),
            ]),
            restart: .menuBar
        ),
        Tweak(
            id: "scale-effect", category: .windows,
            title: "Simple minimize animation",
            detail: "Windows shrink straight into the Dock instead of using the Genie effect.",
            kind: .preferences([pref(dock, "mineffect", .string("scale"))]),
            restart: .dock,
            recommended: false
        ),
        Tweak(
            id: "dock-autohide", category: .windows,
            title: "Auto-hide the Dock",
            detail: "The Dock slides away until you move the pointer to the bottom of the screen.",
            onWindows: "Like \"Automatically hide the taskbar\".",
            kind: .preferences([pref(dock, "autohide", .bool(true))]),
            restart: .dock,
            recommended: false
        ),
        Tweak(
            id: "dock-autohide-speed", category: .windows,
            title: "Show the hidden Dock instantly",
            detail: "Removes the pause before an auto-hidden Dock appears, and makes it slide in faster.",
            kind: .preferences([
                pref(dock, "autohide-delay", .float(0)),
                pref(dock, "autohide-time-modifier", .float(0.3)),
            ]),
            restart: .dock,
            recommended: false
        ),
        Tweak(
            id: "group-windows", category: .windows,
            title: "Group windows by app in Mission Control",
            detail: "Mission Control shows each app's windows together, which is easier to scan.",
            onWindows: "Similar to how Task View groups windows.",
            kind: .preferences([pref(dock, "expose-group-apps", .bool(true))]),
            restart: .dock,
            recommended: false
        ),
        Tweak(
            id: "clock-seconds", category: .windows,
            title: "Show seconds in the menu bar clock",
            detail: "Adds seconds to the clock at the top right.",
            kind: .preferences([pref("com.apple.menuextra.clock", "ShowSeconds", .bool(true))]),
            restart: .menuBar,
            recommended: false
        ),
    ]

    // MARK: - General

    private static let system: [Tweak] = [
        Tweak(
            id: "screenshot-folder", category: .system,
            title: "Save screenshots to Pictures › Screenshots",
            detail: "Screenshots go into their own folder instead of covering your desktop.",
            onWindows: "Windows saves screenshots to Pictures › Screenshots.",
            kind: .preferences([pref("com.apple.screencapture", "location", .string(screenshotsFolder.path))]),
            restart: .menuBar,
            prepare: {
                try? FileManager.default.createDirectory(at: screenshotsFolder, withIntermediateDirectories: true)
            }
        ),
        Tweak(
            id: "expanded-dialogs", category: .system,
            title: "Show full Save and Print dialogs",
            detail: "Save and Print dialogs open fully expanded, showing all folders and options straight away.",
            onWindows: "Save As always shows the full folder browser.",
            kind: .preferences([
                pref(global, "NSNavPanelExpandedStateForSaveMode", .bool(true)),
                pref(global, "NSNavPanelExpandedStateForSaveMode2", .bool(true)),
                pref(global, "PMPrintingExpandedStateForPrint", .bool(true)),
                pref(global, "PMPrintingExpandedStateForPrint2", .bool(true)),
            ]),
            restart: .reopenApps
        ),
        Tweak(
            id: "save-to-disk", category: .system,
            title: "Save new documents to this Mac, not iCloud",
            detail: "Save dialogs start in a folder on this Mac instead of iCloud Drive.",
            kind: .preferences([pref(global, "NSDocumentSaveNewDocumentsToCloud", .bool(false))]),
            restart: .reopenApps
        ),
        Tweak(
            id: "scroll-bars", category: .system,
            title: "Always show scroll bars",
            detail: "Scroll bars stay visible instead of appearing only while you scroll.",
            onWindows: "Scroll bars are always visible.",
            kind: .preferences([pref(global, "AppleShowScrollBars", .string("Always"))]),
            restart: .reopenApps
        ),
        Tweak(
            id: "textedit-plain", category: .system,
            title: "TextEdit starts in plain text",
            detail: "New TextEdit documents are plain text, so TextEdit works like Notepad.",
            onWindows: "Like Notepad.",
            kind: .preferences([pref("com.apple.TextEdit", "RichText", .int(0))]),
            restart: .reopenApps
        ),
        Tweak(
            id: "screenshot-shadow", category: .system,
            title: "No shadow on window screenshots",
            detail: "Screenshots of a single window (Cmd+Shift+4, then Space) are saved without the large drop shadow.",
            kind: .preferences([pref("com.apple.screencapture", "disable-shadow", .bool(true))]),
            restart: .menuBar,
            recommended: false
        ),
    ]
}
