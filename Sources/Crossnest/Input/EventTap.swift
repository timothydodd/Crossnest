import CoreGraphics
import Foundation

/// A single system-wide event tap on the main run loop. The handler returns true to swallow an event.
/// Needs Accessibility permission.
final class EventTap {
    typealias Handler = (CGEventType, CGEvent) -> Bool

    /// Stamped on events Crossnest posts itself, so the tap lets them through untouched.
    static let syntheticMarker: Int64 = 0x4352_4E53  // "CRNS"

    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var handler: Handler?
    private var mask: CGEventMask = 0

    var isRunning: Bool { port != nil }

    /// Returns false if macOS refused to create the tap (usually: no Accessibility permission).
    @discardableResult
    func start(types: [CGEventType], _ handler: @escaping Handler) -> Bool {
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        if port != nil && mask != self.mask { stop() }  // listening for different events: rebuild
        self.handler = handler
        guard port == nil else { return true }

        guard let port = CGEvent.tapCreate(
            // HID level: sees keys before macOS handles its own shortcuts such as Cmd+Tab.
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        self.port = port
        self.source = source
        self.mask = mask
        return true
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let port { CFMachPortInvalidate(port) }
        port = nil
        source = nil
        handler = nil
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS switches a tap off if it is slow or the user does something sensitive; turn it back on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticMarker {
            return Unmanaged.passUnretained(event)
        }
        return handler?(type, event) == true ? nil : Unmanaged.passUnretained(event)
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    return Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
}

enum KeyCode {
    static let tab: Int64 = 48
    static let escape: Int64 = 53
    static let returnKey: Int64 = 36
    static let l: Int64 = 37
    static let q: Int64 = 12
    static let left: Int64 = 123
    static let right: Int64 = 124
    static let down: Int64 = 125
    static let up: Int64 = 126
}

extension CGEvent {
    var keyCode: Int64 { getIntegerValueField(.keyboardEventKeycode) }
    var isAutorepeat: Bool { getIntegerValueField(.keyboardEventAutorepeat) != 0 }

    /// Only these modifiers held (ignores Caps Lock, fn and device bits).
    func hasExactly(_ modifiers: CGEventFlags) -> Bool {
        let relevant: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
        return flags.intersection(relevant) == modifiers
    }
}
