import CoreGraphics
import Foundation

/// Alt+Tab (Option+Tab on a Mac keyboard) switches between windows like Windows does.
/// Hold Alt and keep pressing Tab to move along; Shift+Tab or the arrow keys go back;
/// let go of Alt to switch, or press Esc to cancel. A quick tap switches straight to the last window.
///
/// The event tap must answer instantly or macOS turns it off, so the window list (which means asking
/// every app over Accessibility) is built in the background. Keys pressed meanwhile are queued up.
@MainActor
final class AltTabController {
    private let panel = SwitcherPanel()
    /// The modifier the keyboard's Alt key sends: Option on most PC keyboards, Command in "Mac mode".
    var altModifier: CGEventFlags = .maskAlternate
    private var windows: [SwitcherWindow] = []
    private var selected = 0
    private var isActive = false

    // While the window list is loading:
    private var isLoading = false
    private var startBackwards = false
    private var queuedMoves = 0
    private var commitWhenLoaded = false
    private var showWhenLoaded = false

    /// Bumped on every begin/cancel so a slow, outdated window list is thrown away.
    private var generation = 0
    private var pendingShow: DispatchWorkItem?

    func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        switch type {
        case .keyDown:
            if event.keyCode == KeyCode.tab,
               event.hasExactly(altModifier) || event.hasExactly([altModifier, .maskShift]) {
                let backwards = event.flags.contains(.maskShift)
                if isActive { move(backwards ? -1 : 1) } else { begin(backwards: backwards) }
                return true
            }
            guard isActive else { return false }
            switch event.keyCode {
            case KeyCode.escape: cancel()
            case KeyCode.left, KeyCode.up: move(-1)
            case KeyCode.right, KeyCode.down: move(1)
            case KeyCode.returnKey: commit()
            default: break
            }
            return true  // keep other keys away from the app underneath while switching
        case .keyUp:
            return isActive
        case .flagsChanged:
            if isActive, !event.flags.contains(altModifier) { commit() }
            return false
        default:
            return false
        }
    }

    func stop() {
        cancel()
    }

    private func begin(backwards: Bool) {
        isActive = true
        isLoading = true
        startBackwards = backwards
        queuedMoves = 0
        commitWhenLoaded = false
        showWhenLoaded = false
        generation += 1
        let generation = generation

        DispatchQueue.global(qos: .userInteractive).async {
            let list = WindowList.current()
            Task { @MainActor [weak self] in self?.loaded(list, generation: generation) }
        }

        // Wait a moment before showing the panel, so a quick Alt+Tab just flips windows without a flash.
        let show = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.isActive else { return }
                if self.isLoading { self.showWhenLoaded = true } else { self.panel.show(self.windows, selected: self.selected) }
            }
        }
        pendingShow = show
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: show)
    }

    private func loaded(_ list: [SwitcherWindow], generation: Int) {
        guard generation == self.generation, isActive else { return }
        isLoading = false
        windows = list
        guard !windows.isEmpty else {
            cancel()
            return
        }
        // Like Windows: the first Tab goes to the previous window, not the current one.
        selected = startBackwards ? windows.count - 1 : min(1, windows.count - 1)
        if queuedMoves != 0 { move(queuedMoves) }
        if commitWhenLoaded {
            commit()
        } else if showWhenLoaded {
            panel.show(windows, selected: selected)
        }
    }

    private func move(_ delta: Int) {
        if isLoading {
            queuedMoves += delta
            return
        }
        guard !windows.isEmpty else { return }
        selected = ((selected + delta) % windows.count + windows.count) % windows.count
        panel.select(selected)
    }

    private func commit() {
        if isLoading {
            commitWhenLoaded = true
            return
        }
        let target = windows.indices.contains(selected) ? windows[selected] : nil
        cancel()
        // Focusing talks to the target app over Accessibility; keep it off the event tap's path.
        if let target {
            DispatchQueue.global(qos: .userInteractive).async { target.focus() }
        }
    }

    private func cancel() {
        isActive = false
        isLoading = false
        generation += 1
        pendingShow?.cancel()
        pendingShow = nil
        panel.hide()
        windows = []
    }
}
