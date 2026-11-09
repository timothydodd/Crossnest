import CoreGraphics
import Foundation
import os

/// The part of Mouse Lock that touches every pointer movement. It runs its own event tap on its own
/// high-priority thread, so nothing on the main thread (drawing, timers, other features) can delay it.
///
/// It works the way games capture the mouse: while locked, the pointer is detached from the mouse
/// (`CGAssociateMouseAndMouseCursorPosition(0)`), Crossnest keeps its own pointer position that is
/// always clamped inside the area, and draws the pointer there on every movement. The pointer can
/// never leave the area, so there is nothing to pull back and no jitter at edges or corners. Movement
/// is scaled by the user's normal speed curve, learned from ordinary use while unlocked.
final class MouseClampTap {
    private struct State {
        var rect: CGRect
        /// Where the pointer is, in global display coordinates (top-left origin).
        var position: CGPoint
        /// Extra multiplier on top of the learned curve (1 = same as normal pointer movement).
        var sensitivity: Double
    }

    private struct Shared {
        var lock: State?
        var calibration = PointerCalibration()
        /// Where the attached pointer was at the previous movement, for learning.
        var lastAttachedLocation: CGPoint?
    }

    private let state = OSAllocatedUnfairLock<Shared>(initialState: Shared())
    private var port: CFMachPort?
    private var runLoop: CFRunLoop?
    private var thread: Thread?

    var isRunning: Bool { port != nil }

    /// Sets the area to keep the pointer in (nil = no lock). Safe to call from any thread.
    func setArea(_ rect: CGRect?, sensitivity: Double = 1) {
        state.withLock { shared in
            guard let rect else {
                if shared.lock != nil { Self.attachPointer() }
                shared.lock = nil
                return
            }
            let inside = rect.insetBy(dx: 1, dy: 1)
            // Keep our position if already locked, otherwise start from the real pointer.
            let start = shared.lock?.position ?? Self.pointerLocation()
            let position = Self.clamp(start, to: inside)
            if shared.lock == nil { Self.detachPointer() }
            if position != start { CGWarpMouseCursorPosition(position) }
            shared.lock = State(rect: inside, position: position, sensitivity: sensitivity)
            shared.lastAttachedLocation = nil
        }
    }

    /// True once normal use has taught it the pointer speed curve.
    var isCalibrated: Bool { state.withLock { $0.calibration.hasLearnedAnything } }

    @discardableResult
    func start() -> Bool {
        guard port == nil else { return true }
        let types: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let port = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: clampCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.port = port

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [weak self] in
            let loop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(loop, source, .commonModes)
            self?.runLoop = loop
            CGEvent.tapEnable(tap: port, enable: true)
            ready.signal()
            CFRunLoopRun()
        }
        thread.name = "Crossnest Mouse Lock"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        self.thread = thread
        return true
    }

    func stop() {
        setArea(nil)
        state.withLock { $0.calibration.save() }
        if let port {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        if let runLoop { CFRunLoopStop(runLoop) }
        port = nil
        runLoop = nil
        thread = nil
    }

    deinit {
        Self.attachPointer()
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let dx = event.getDoubleValueField(.mouseEventDeltaX)
        let dy = event.getDoubleValueField(.mouseEventDeltaY)
        let rawDistance = (dx * dx + dy * dy).squareRoot()
        let location = event.location

        let position: CGPoint? = state.withLock { shared in
            guard let current = shared.lock else {
                // Not locked, pointer attached: learn how far it really moved for this raw count.
                if let last = shared.lastAttachedLocation {
                    let actual = ((location.x - last.x) * (location.x - last.x)
                                  + (location.y - last.y) * (location.y - last.y)).squareRoot()
                    shared.calibration.learn(raw: rawDistance, actual: actual)
                }
                shared.lastAttachedLocation = location
                return nil
            }
            // Locked, pointer detached, so this movement hasn't moved it. Apply the distance ourselves,
            // scaled by the learned speed curve so it feels like the normal pointer, times the sensitivity.
            let scale = shared.calibration.scale(forRaw: rawDistance) * current.sensitivity
            let moved = CGPoint(x: current.position.x + dx * scale, y: current.position.y + dy * scale)
            let position = Self.clamp(moved, to: current.rect)
            shared.lock?.position = position
            return position
        }

        guard let position else { return Unmanaged.passUnretained(event) }
        event.location = position
        CGWarpMouseCursorPosition(position)
        return Unmanaged.passUnretained(event)
    }

    // MARK: - Helpers

    private static func clamp(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, rect.minX), rect.maxX - 1),
                y: min(max(point.y, rect.minY), rect.maxY - 1))
    }

    private static func pointerLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    /// Stops mouse movement from moving the pointer; Crossnest positions it instead.
    private static func detachPointer() {
        CGAssociateMouseAndMouseCursorPosition(0)
    }

    /// Back to normal: the mouse moves the pointer.
    private static func attachPointer() {
        CGAssociateMouseAndMouseCursorPosition(1)
    }
}

private func clampCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    return Unmanaged<MouseClampTap>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
}
