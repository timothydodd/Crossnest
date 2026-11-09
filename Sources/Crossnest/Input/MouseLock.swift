import AppKit
import CoreGraphics

/// An app the pointer is kept inside while it's in front.
struct MouseLockApp: Codable, Identifiable, Equatable {
    enum Area: String, Codable, CaseIterable, Identifiable {
        case window, screen
        var id: String { rawValue }
        var label: String { self == .window ? "Its window" : "The screen it's on" }
    }

    let bundleID: String
    var name: String
    var area: Area = .window
    /// Keeps the pointer this many points inside the edges (e.g. off the title bar).
    var padding: Int = 0
    /// Pointer speed relative to normal (1 = the same).
    var sensitivity: Double = 1
    /// What Crossnest saw when the app was added or last detected, e.g. "1600 × 900 window on DELL U2723QE".
    var detected: String?

    var id: String { bundleID }

    init(bundleID: String, name: String) {
        self.bundleID = bundleID
        self.name = name
    }

    /// Settings saved by older versions lack newer fields; fill in defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = try c.decode(String.self, forKey: .bundleID)
        name = try c.decode(String.self, forKey: .name)
        area = try c.decodeIfPresent(Area.self, forKey: .area) ?? .window
        padding = try c.decodeIfPresent(Int.self, forKey: .padding) ?? 0
        sensitivity = try c.decodeIfPresent(Double.self, forKey: .sensitivity) ?? 1
        detected = try c.decodeIfPresent(String.self, forKey: .detected)
    }
}

/// Keeps the pointer inside the front window of chosen apps, like a game's "confine cursor" option on
/// Windows, so it can't slide onto another monitor. Only active while one of those apps is in front;
/// switching apps (Cmd+Tab / Alt+Tab) releases it.
@MainActor
final class MouseLock: ObservableObject {
    @Published var apps: [MouseLockApp] {
        didSet {
            save()
            refresh()
        }
    }

    /// True while a picked app is in front and the pointer is being held.
    @Published private(set) var isLocking = false

    /// Does the actual clamping, on its own thread.
    private let clampTap = MouseClampTap()

    /// Mouse Lock copies the pointer's normal speed curve, learned from ordinary use while unlocked.
    var isCalibrated: Bool { clampTap.isCalibrated }
    private var isRunning = false
    private var timer: Timer?
    private var observer: NSObjectProtocol?
    private static let defaultsKey = "mouseLockApps"

    init() {
        let data = UserDefaults.standard.data(forKey: Self.defaultsKey)
        apps = data.flatMap { try? JSONDecoder().decode([MouseLockApp].self, from: $0) } ?? []
    }

    func start() {
        guard !isRunning else { return }
        guard clampTap.start() else { return }  // no Accessibility permission yet; LiveFeatures retries
        isRunning = true
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        // Windows move and resize without telling anyone, so re-measure a few times a second.
        let timer = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        refresh()
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observer = nil
        clampTap.stop()
        isLocking = false
    }

    func add(_ app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier, !apps.contains(where: { $0.bundleID == bundleID }) else { return }
        var entry = MouseLockApp(bundleID: bundleID, name: app.localizedName ?? bundleID)
        entry.detected = Self.describe(pid: app.processIdentifier, area: entry.area)
        apps.append(entry)
    }

    func add(bundleAt url: URL) {
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier,
              !apps.contains(where: { $0.bundleID == bundleID }) else { return }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        var entry = MouseLockApp(bundleID: bundleID, name: name)
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            entry.detected = Self.describe(pid: running.processIdentifier, area: entry.area)
        }
        apps.append(entry)
    }

    /// Re-measures an app's window, if it's running.
    func detect(_ bundleID: String) {
        guard let index = apps.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            apps[index].detected = Self.describe(pid: running.processIdentifier, area: apps[index].area)
        } else {
            apps[index].detected = nil
        }
    }

    func remove(_ bundleID: String) {
        apps.removeAll { $0.bundleID == bundleID }
    }

    // MARK: - Measuring

    private func refresh() {
        guard isRunning,
              let front = NSWorkspace.shared.frontmostApplication,
              let app = apps.first(where: { $0.bundleID == front.bundleIdentifier }) else {
            clampTap.setArea(nil)
            isLocking = false
            return
        }
        let rect = Self.area(pid: front.processIdentifier, area: app.area).map { rect in
            // Padding can't shrink the area to nothing.
            let pad = CGFloat(min(app.padding, Int(min(rect.width, rect.height) / 2) - 10))
            return pad > 0 ? rect.insetBy(dx: pad, dy: pad) : rect
        }
        clampTap.setArea(rect, sensitivity: app.sensitivity)
        if isLocking != (rect != nil) { isLocking = rect != nil }
    }

    static func area(pid: pid_t, area: MouseLockApp.Area) -> CGRect? {
        guard let window = frontWindowBounds(pid: pid) else { return nil }
        switch area {
        case .window: return window
        case .screen: return display(containing: window)?.bounds
        }
    }

    /// The app's front-most normal window, from the window server (no extra permission needed for bounds).
    static func frontWindowBounds(pid: pid_t) -> CGRect? {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        for window in info {
            guard (window[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  bounds.width >= 100, bounds.height >= 100 else { continue }
            return bounds
        }
        return nil
    }

    static func describe(pid: pid_t, area: MouseLockApp.Area) -> String {
        guard let window = frontWindowBounds(pid: pid) else {
            return "No window open right now; the size is detected whenever it's in front."
        }
        let display = display(containing: window)
        let screenName = display?.name ?? "a screen"
        switch area {
        case .window:
            return "\(Int(window.width)) × \(Int(window.height)) window on \(screenName)"
        case .screen:
            let size = display.map { "\(Int($0.bounds.width)) × \(Int($0.bounds.height))" } ?? ""
            return "\(screenName) \(size)".trimmingCharacters(in: .whitespaces)
        }
    }

    private static func display(containing rect: CGRect) -> (bounds: CGRect, name: String)? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            else { continue }
            let bounds = CGDisplayBounds(number)  // top-left origin, same as window and event coordinates
            if bounds.contains(center) { return (bounds, screen.localizedName) }
        }
        return nil
    }

    private func save() {
        if let data = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
