import CoreGraphics
import Foundation

/// Turns the jumpy line-by-line scrolling of a regular mouse wheel into smooth pixel scrolling,
/// the way Windows animates it. Trackpads and Magic Mice already scroll smoothly and are left alone.
@MainActor
final class SmoothScroller {
    /// Pixels per wheel "line". macOS reports bigger line counts when the wheel spins fast.
    private let pixelsPerLine = 60.0
    /// Fraction of the remaining distance scrolled each frame: higher is snappier.
    private let easing = 0.2
    private let frameInterval = 1.0 / 120.0

    /// A reverse click this soon after clicks the other way is treated as wheel jitter.
    private let jitterWindow: TimeInterval = 0.12

    /// Tracks one scroll axis: the glide still to do, and the direction filter.
    private struct Axis {
        var remaining = 0.0
        var lastSign = 0.0
        var lastTick = Date.distantPast
        var reverseStreak = 0

        /// Adds a wheel click. A lone click against the current direction, arriving straight after
        /// clicks the other way, is ignored: cheap wheels often send one when flicked, and reversing
        /// on it makes the page bounce. Two in a row, or one after a pause, is a real change of direction.
        mutating func add(_ lines: Double, pixelsPerLine: Double, jitterWindow: TimeInterval, now: Date) {
            guard lines != 0 else { return }
            let sign: Double = lines > 0 ? 1 : -1
            if lastSign != 0, sign != lastSign {
                let recent = now.timeIntervalSince(lastTick) < jitterWindow
                if recent && reverseStreak == 0 {
                    reverseStreak = 1
                    return
                }
                remaining = 0  // genuine reversal: drop the old glide instead of fighting it
            }
            reverseStreak = 0
            lastSign = sign
            lastTick = now
            remaining += lines * pixelsPerLine
        }
    }

    private var x = Axis()
    private var y = Axis()
    private var flags: CGEventFlags = []
    private var timer: Timer?

    /// Returns true when the event was taken over.
    func handle(_ event: CGEvent) -> Bool {
        // Continuous = trackpad or Magic Mouse, which are smooth already.
        guard event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0 else { return false }
        // Cmd/Ctrl/Option + wheel usually means zoom; keep the original behaviour.
        guard event.flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty else { return false }

        let now = Date()
        y.add(Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1)),
              pixelsPerLine: pixelsPerLine, jitterWindow: jitterWindow, now: now)
        x.add(Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2)),
              pixelsPerLine: pixelsPerLine, jitterWindow: jitterWindow, now: now)
        flags = event.flags
        if x.remaining != 0 || y.remaining != 0 { startTimer() }
        // Swallow every wheel event, even ones we ignored, so the original jumpy scroll never mixes in.
        return true
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        x.remaining = 0
        y.remaining = 0
    }

    private func startTimer() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: frameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let dy = step(&y.remaining)
        let dx = step(&x.remaining)
        if dy == 0 && dx == 0 {
            stop()
            return
        }
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                                  wheel1: dy, wheel2: dx, wheel3: 0) else { return }
        event.flags = flags
        event.setIntegerValueField(.eventSourceUserData, value: EventTap.syntheticMarker)
        event.post(tap: .cgSessionEventTap)
    }

    /// Takes the next frame's share of `remaining`, at least one pixel so the glide always finishes.
    private func step(_ remaining: inout Double) -> Int32 {
        guard abs(remaining) >= 1 else {
            remaining = 0
            return 0
        }
        var amount = (remaining * easing).rounded()
        if amount == 0 { amount = remaining > 0 ? 1 : -1 }
        remaining -= amount
        return Int32(amount)
    }
}
