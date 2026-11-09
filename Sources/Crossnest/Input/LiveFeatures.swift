import AppKit
import ApplicationServices
import ServiceManagement

/// Features that work by watching the keyboard and mouse while Crossnest runs,
/// as opposed to tweaks that change a macOS setting once.
enum LiveFeature: String, CaseIterable {
    case smoothScrolling
    case altTab
    case lockShortcut
    case ctrlShortcuts

    var menuTitle: String {
        switch self {
        case .smoothScrolling: "Smooth Scrolling"
        case .altTab: "Alt+Tab Window Switcher"
        case .lockShortcut: "Windows+L Locks the Screen"
        case .ctrlShortcuts: "PC Ctrl Shortcuts"
        }
    }
}

/// Which modifier the keyboard's Windows key sends. Many PC keyboards send Command (macOS's default),
/// but keyboards with a "Mac mode" swap Alt and Windows so Alt sends Command and Windows sends Option.
enum WindowsKey: String, CaseIterable, Identifiable {
    case command, option

    var id: String { rawValue }
    var windowsFlag: CGEventFlags { self == .command ? .maskCommand : .maskAlternate }
    var altFlag: CGEventFlags { self == .command ? .maskAlternate : .maskCommand }

    var label: String {
        switch self {
        case .command: "Windows key sends Command, Alt sends Option"
        case .option: "Windows key sends Option, Alt sends Command (Mac mode)"
        }
    }
}

@MainActor
final class LiveFeatures: ObservableObject {
    static let shared = LiveFeatures()

    @Published private(set) var enabled: Set<LiveFeature>
    @Published private(set) var hasPermission = AXIsProcessTrusted()
    @Published private(set) var opensAtLogin = SMAppService.mainApp.status == .enabled
    @Published var windowsKey: WindowsKey {
        didSet {
            UserDefaults.standard.set(windowsKey.rawValue, forKey: "windowsKey")
            applyKeyboardLayout()
        }
    }

    private let tap = EventTap()
    private let scroller = SmoothScroller()
    private let altTab = AltTabController()
    private let lock = LockShortcut()
    private let ctrlShortcuts = CtrlShortcuts()
    private var permissionTimer: Timer?
    private let defaultsKey = "enabledLiveFeatures"

    private init() {
        let saved = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        enabled = Set(saved.compactMap(LiveFeature.init(rawValue:)))
        windowsKey = WindowsKey(rawValue: UserDefaults.standard.string(forKey: "windowsKey") ?? "") ?? .command
        applyKeyboardLayout()
        reconcile()
    }

    var needsPermission: Bool { !enabled.isEmpty && !hasPermission }

    func isOn(_ feature: LiveFeature) -> Bool { enabled.contains(feature) }

    func set(_ feature: LiveFeature, on: Bool) {
        if on { enabled.insert(feature) } else { enabled.remove(feature) }
        UserDefaults.standard.set(enabled.map(\.rawValue).sorted(), forKey: defaultsKey)
        if on && !hasPermission { requestPermission() }
        reconcile()
    }

    /// Shows the macOS prompt that leads to System Settings › Privacy & Security › Accessibility.
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        hasPermission = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func setOpensAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Crossnest: login item change failed: \(error)")
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// Starts or stops the event tap to match what's enabled and permitted.
    private func reconcile() {
        if !enabled.contains(.smoothScrolling) { scroller.stop() }
        if !enabled.contains(.altTab) { altTab.stop() }

        guard !enabled.isEmpty else {
            tap.stop()
            stopWaitingForPermission()
            return
        }
        hasPermission = AXIsProcessTrusted()
        guard hasPermission else {
            waitForPermission()
            return
        }
        stopWaitingForPermission()
        tap.start { [weak self] type, event in
            MainActor.assumeIsolated { self?.handle(type, event) ?? false }
        }
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .scrollWheel {
            return enabled.contains(.smoothScrolling) && scroller.handle(event)
        }
        // First, so a remapped Ctrl+L becomes Cmd+L and isn't mistaken for Windows+L.
        if enabled.contains(.ctrlShortcuts), ctrlShortcuts.handle(type, event) { return false }
        if enabled.contains(.altTab), altTab.handle(type, event) { return true }
        if enabled.contains(.lockShortcut), lock.handle(type, event) { return true }
        return false
    }

    private func applyKeyboardLayout() {
        altTab.altModifier = windowsKey.altFlag
        lock.windowsModifier = windowsKey.windowsFlag
    }

    /// macOS doesn't announce when permission is granted, so check every second until it is.
    private func waitForPermission() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, AXIsProcessTrusted() else { return }
                self.reconcile()
            }
        }
    }

    private func stopWaitingForPermission() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }
}
