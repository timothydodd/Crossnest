import Foundation

/// A scalar preference value, the same kinds `defaults write -bool/-int/-float/-string` takes.
enum PrefValue: Codable, Equatable {
    case bool(Bool)
    case int(Int)
    case float(Double)
    case string(String)

    /// Converts a value read from CFPreferences. Returns nil for types Crossnest never writes
    /// (arrays, dictionaries, dates, data).
    init?(propertyList raw: Any?) {
        guard let raw else { return nil }
        if let string = raw as? String {
            self = .string(string)
        } else if let number = raw as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
            } else if CFNumberIsFloatType(number) {
                self = .float(number.doubleValue)
            } else {
                self = .int(number.intValue)
            }
        } else {
            return nil
        }
    }

    var propertyList: CFPropertyList {
        switch self {
        case .bool(let value): NSNumber(value: value)
        case .int(let value): NSNumber(value: value)
        case .float(let value): NSNumber(value: value)
        case .string(let value): value as CFString
        }
    }

    /// True when a stored value means the same thing as this one. Loose on purpose:
    /// macOS sometimes stores booleans as 0/1 integers or "YES"/"NO" strings.
    func matches(_ raw: Any?) -> Bool {
        switch self {
        case .bool(let expected):
            if let number = raw as? NSNumber { return number.boolValue == expected }
            if let string = raw as? String { return ["1", "yes", "true"].contains(string.lowercased()) == expected }
            return false
        case .int(let expected):
            return (raw as? NSNumber)?.intValue == expected
        case .float(let expected):
            guard let number = raw as? NSNumber else { return false }
            return abs(number.doubleValue - expected) < 0.0001
        case .string(let expected):
            return (raw as? String) == expected
        }
    }
}

/// One `defaults` key that a tweak sets.
struct PrefChange {
    let domain: String
    let key: String
    let value: PrefValue

    init(_ domain: String, _ key: String, _ value: PrefValue) {
        self.domain = domain
        self.key = key
        self.value = value
    }
}
