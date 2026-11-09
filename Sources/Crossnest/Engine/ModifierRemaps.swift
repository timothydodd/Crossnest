import Foundation
import IOKit
import IOKit.hid

/// The per-keyboard modifier key remapping set in System Settings › Keyboard › Modifier Keys.
/// macOS stores it in the current-host global preferences as
/// `com.apple.keyboard.modifiermapping.<vendor>-<product>-0`, an array of
/// { HIDKeyboardModifierMappingSrc, HIDKeyboardModifierMappingDst } usage codes.
struct ModifierRemap: Identifiable {
    let prefKey: String
    let vendorID: Int
    let productID: Int
    let pairs: [(from: Int, to: Int)]

    var id: String { prefKey }

    /// The keyboard's name if it's plugged in right now.
    var connectedName: String? { ModifierRemaps.connectedKeyboards()[deviceID] }
    var deviceID: String { "\(vendorID)-\(productID)" }

    var summary: String {
        pairs.map { "\(ModifierRemaps.name(of: $0.from)) → \(ModifierRemaps.name(of: $0.to))" }
            .joined(separator: ", ")
    }
}

enum ModifierRemaps {
    private static let prefix = "com.apple.keyboard.modifiermapping."
    private static let srcKey = "HIDKeyboardModifierMappingSrc"
    private static let dstKey = "HIDKeyboardModifierMappingDst"
    private static let backupURL = BackupStore.directory.appending(path: "modifier-mappings.plist")

    static func current() -> [ModifierRemap] {
        let app = kCFPreferencesAnyApplication
        CFPreferencesSynchronize(app, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        let keys = CFPreferencesCopyKeyList(app, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost) as? [String] ?? []
        return keys.filter { $0.hasPrefix(prefix) }.sorted().compactMap { key in
            guard let raw = CFPreferencesCopyValue(key as CFString, app, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
                    as? [[String: Any]] else { return nil }
            let pairs = raw.compactMap { entry -> (Int, Int)? in
                guard let from = (entry[srcKey] as? NSNumber)?.intValue,
                      let to = (entry[dstKey] as? NSNumber)?.intValue,
                      from != to else { return nil }
                return (from, to)
            }
            guard !pairs.isEmpty else { return nil }
            let ids = key.dropFirst(prefix.count).split(separator: "-").compactMap { Int($0) }
            return ModifierRemap(prefKey: key, vendorID: ids.first ?? 0,
                                 productID: ids.count > 1 ? ids[1] : 0,
                                 pairs: pairs.map { (from: $0.0, to: $0.1) })
        }
    }

    static var hasBackup: Bool { FileManager.default.fileExists(atPath: backupURL.path) }

    /// Saves every remap to a backup file, removes them, and applies standard keys to plugged-in keyboards.
    static func resetAll() throws {
        let remaps = current()
        guard !remaps.isEmpty else { return }
        var backup: [String: Any] = [:]
        for remap in remaps {
            backup[remap.prefKey] = read(remap.prefKey)
        }
        try FileManager.default.createDirectory(at: BackupStore.directory, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: backup, format: .xml, options: 0)
        try data.write(to: backupURL, options: .atomic)

        for remap in remaps {
            write(nil, remap.prefKey)
            applyLive(vendorID: remap.vendorID, productID: remap.productID, mappings: [])
        }
    }

    /// Puts back the remaps saved by `resetAll()`.
    static func restore() throws {
        let data = try Data(contentsOf: backupURL)
        guard let backup = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return }
        for (key, value) in backup {
            write(value, key)
            let ids = key.dropFirst(prefix.count).split(separator: "-").compactMap { Int($0) }
            if ids.count > 1, let mappings = value as? [[String: Any]] {
                applyLive(vendorID: ids[0], productID: ids[1], mappings: mappings)
            }
        }
        try FileManager.default.removeItem(at: backupURL)
    }

    /// Keyboards plugged in now, keyed by "vendor-product".
    static func connectedKeyboards() -> [String: String] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard,
        ] as CFDictionary)
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [:] }
        var result: [String: String] = [:]
        for device in devices {
            let vendor = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? 0
            let product = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0
            let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Keyboard"
            result["\(vendor)-\(product)"] = name
        }
        return result
    }

    /// Key names as printed on a PC keyboard, with the Mac name alongside.
    static func name(of usage: Int) -> String {
        switch usage {
        case 0x7_0000_00E0: "Ctrl"
        case 0x7_0000_00E1: "Shift"
        case 0x7_0000_00E2: "Alt/Option"
        case 0x7_0000_00E3: "Windows/Command"
        case 0x7_0000_00E4: "Right Ctrl"
        case 0x7_0000_00E5: "Right Shift"
        case 0x7_0000_00E6: "Right Alt/Option"
        case 0x7_0000_00E7: "Right Windows/Command"
        case 0x7_0000_0039: "Caps Lock"
        case 0xFF_0000_0003, 0xFF00_0000_0003: "fn"
        case 0x7_0000_0029: "Esc"
        case 0: "Nothing"
        default: String(format: "key 0x%llX", usage)
        }
    }

    // MARK: - Private

    private static func read(_ key: String) -> Any? {
        CFPreferencesCopyValue(key as CFString, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
    }

    private static func write(_ value: Any?, _ key: String) {
        CFPreferencesSetValue(key as CFString, value as CFPropertyList?, kCFPreferencesAnyApplication,
                              kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
    }

    /// Applies a mapping to a plugged-in keyboard straight away, as System Settings does.
    /// Keyboards that aren't plugged in pick up the saved preference next time they connect.
    private static func applyLive(vendorID: Int, productID: Int, mappings: [[String: Any]]) {
        let pairs = mappings.map { entry in
            "{\"\(srcKey)\":\((entry[srcKey] as? NSNumber)?.int64Value ?? 0),\"\(dstKey)\":\((entry[dstKey] as? NSNumber)?.int64Value ?? 0)}"
        }.joined(separator: ",")
        Shell.run("/usr/bin/hidutil", [
            "property",
            "--matching", "{\"VendorID\":\(vendorID),\"ProductID\":\(productID)}",
            "--set", "{\"HIDKeyboardModifierMappingPairs\":[\(pairs)]}",
        ])
    }
}
