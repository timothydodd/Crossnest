import Foundation

/// Applies and undoes tweaks, and tracks which ones are on and what needs restarting.
@MainActor
final class TweakEngine: ObservableObject {
    let tweaks = TweakCatalog.all

    @Published private(set) var applied: Set<String> = []
    /// Restarts still needed for changes made this session.
    @Published private(set) var pendingRestarts: Set<Restart> = []
    @Published var errorMessage: String?

    private let backups = BackupStore()

    init() {
        refresh()
    }

    var recommended: [Tweak] { tweaks.filter(\.recommended) }
    var recommendedRemaining: [Tweak] { recommended.filter { !applied.contains($0.id) } }

    func tweaks(in category: TweakCategory) -> [Tweak] {
        tweaks.filter { $0.category == category }
    }

    func isOn(_ tweak: Tweak) -> Bool { applied.contains(tweak.id) }

    /// Re-reads the real settings, so switches reflect changes made in System Settings too.
    func refresh() {
        applied = Set(tweaks.filter(Self.isApplied).map(\.id))
    }

    func set(_ tweak: Tweak, on: Bool) {
        if on { apply(tweak) } else { revert(tweak, onlyCrossnestChanges: false) }
        finish(touching: [tweak])
    }

    /// The one-click preset.
    func applyRecommended() {
        let todo = recommendedRemaining
        todo.forEach(apply)
        finish(touching: todo)
    }

    /// Puts back everything Crossnest changed. Settings the user had already set themselves are left alone.
    func undoEverything() {
        let touched = tweaks.filter(hasCrossnestChanges)
        for tweak in touched { revert(tweak, onlyCrossnestChanges: true) }
        finish(touching: touched)
    }

    var hasAnythingToUndo: Bool { tweaks.contains(where: hasCrossnestChanges) }

    func restartServicesNow() {
        let services = pendingRestarts.filter(\.isService)
        Task.detached {
            for service in services {
                for name in service.processNames { Shell.killAll(name) }
            }
        }
        pendingRestarts.subtract(services)
    }

    func logOut() {
        Task.detached { Shell.requestLogOut() }
    }

    func dismissPending() {
        pendingRestarts.removeAll()
    }

    // MARK: - Private

    private static func isApplied(_ tweak: Tweak) -> Bool {
        switch tweak.kind {
        case .preferences(let changes):
            changes.allSatisfy { $0.value.matches(Preferences.read($0.domain, $0.key)) }
        case .keyBindings:
            KeyBindings.isInstalled
        case .live(let feature):
            LiveFeatures.shared.isOn(feature)
        }
    }

    private func hasCrossnestChanges(_ tweak: Tweak) -> Bool {
        switch tweak.kind {
        case .preferences(let changes): changes.contains(where: backups.hasOriginal)
        case .keyBindings: KeyBindings.isInstalled
        case .live(let feature): LiveFeatures.shared.isOn(feature)
        }
    }

    private func apply(_ tweak: Tweak) {
        tweak.prepare?()
        switch tweak.kind {
        case .preferences(let changes):
            for change in changes {
                backups.recordIfNeeded(change, current: Preferences.read(change.domain, change.key))
                Preferences.write(change.value, change.domain, change.key)
            }
        case .keyBindings:
            do { try KeyBindings.install() } catch { report("Couldn't install the key bindings file", error) }
        case .live(let feature):
            LiveFeatures.shared.set(feature, on: true)
        }
    }

    /// Restores the saved original for each key. A key with no saved original was set before Crossnest
    /// ever ran: undo-everything leaves it, but switching it off by hand resets it to the macOS default.
    private func revert(_ tweak: Tweak, onlyCrossnestChanges: Bool) {
        switch tweak.kind {
        case .preferences(let changes):
            for change in changes {
                if let original = backups.take(change) {
                    Preferences.write(original.value, change.domain, change.key)
                } else if !onlyCrossnestChanges {
                    Preferences.write(nil, change.domain, change.key)
                }
            }
        case .keyBindings:
            do { try KeyBindings.uninstall() } catch { report("Couldn't remove the key bindings file", error) }
        case .live(let feature):
            LiveFeatures.shared.set(feature, on: false)
        }
    }

    private func finish(touching changed: [Tweak]) {
        guard !changed.isEmpty else { return }
        Task.detached { Shell.activateSettings() }
        pendingRestarts.formUnion(changed.compactMap(\.restart))
        refresh()
    }

    private func report(_ message: String, _ error: Error) {
        errorMessage = "\(message): \(error.localizedDescription)"
    }
}
