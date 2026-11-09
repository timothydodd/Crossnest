import Foundation

enum TweakCategory: String, CaseIterable, Identifiable {
    case keyboard, shortcuts, mouse, finder, windows, system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keyboard: "Keyboard"
        case .shortcuts: "Keyboard Shortcuts"
        case .mouse: "Mouse & Trackpad"
        case .finder: "Finder"
        case .windows: "Dock & Windows"
        case .system: "General"
        }
    }

    var subtitle: String {
        switch self {
        case .keyboard: "Key repeat, Home and End, function keys and typing help."
        case .shortcuts: "Windows shortcuts such as Alt+Tab and Windows+L. These work while Crossnest is running."
        case .mouse: "Scroll direction, pointer speed and clicking."
        case .finder: "Make Finder work more like File Explorer."
        case .windows: "Make the Dock act like a taskbar and windows snap like they do on a PC."
        case .system: "Screenshots, Save dialogs, scroll bars and the menu bar clock."
        }
    }

    var symbol: String {
        switch self {
        case .keyboard: "keyboard"
        case .shortcuts: "command"
        case .mouse: "computermouse"
        case .finder: "folder"
        case .windows: "macwindow.on.rectangle"
        case .system: "gearshape"
        }
    }
}

/// What has to happen before a change shows up.
enum Restart: String, CaseIterable, Comparable {
    case finder, dock, menuBar, windowManager, reopenApps, logOut

    /// Restarted by Crossnest itself from the banner.
    var isService: Bool { ![.reopenApps, .logOut].contains(self) }

    var processNames: [String] {
        switch self {
        case .finder: ["Finder"]
        case .dock: ["Dock"]
        case .menuBar: ["SystemUIServer", "ControlCenter"]
        case .windowManager: ["WindowManager"]
        case .reopenApps, .logOut: []
        }
    }

    var displayName: String {
        switch self {
        case .finder: "Finder"
        case .dock: "the Dock"
        case .menuBar: "the menu bar"
        case .windowManager: "window management"
        case .reopenApps, .logOut: ""
        }
    }

    /// Shown under each switch.
    var hint: String {
        switch self {
        case .finder: "Finder restarts to apply this."
        case .dock: "The Dock restarts to apply this."
        case .menuBar: "The menu bar refreshes to apply this."
        case .windowManager: "Window management restarts to apply this."
        case .reopenApps: "Applies to apps you open after the change."
        case .logOut: "Takes full effect after you log out and back in."
        }
    }

    static func < (lhs: Restart, rhs: Restart) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

enum TweakKind {
    case preferences([PrefChange])
    case keyBindings
    /// Works only while Crossnest is running, and needs Accessibility permission.
    case live(LiveFeature)
}

/// One switch in the app.
struct Tweak: Identifiable {
    let id: String
    let category: TweakCategory
    let title: String
    let detail: String
    /// How this works on Windows, so the switch makes sense to someone coming from a PC.
    var onWindows: String? = nil
    let kind: TweakKind
    var restart: Restart? = nil
    /// Part of the one-click "Make my Mac feel like Windows" preset.
    var recommended = true
    /// Runs before the preferences are written (e.g. create a folder they point at).
    var prepare: (() -> Void)? = nil
}
