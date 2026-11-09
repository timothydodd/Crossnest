import Foundation

/// Remembers what each preference was before Crossnest first changed it, so it can be put back.
/// Stored in ~/Library/Application Support/Crossnest/originals.json.
final class BackupStore {
    /// `value == nil` means the key did not exist (macOS default).
    struct Original: Codable {
        var value: PrefValue?
    }

    static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Crossnest", directoryHint: .isDirectory)
    }()

    private let fileURL = BackupStore.directory.appending(path: "originals.json")
    private var originals: [String: Original] = [:]

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: Original].self, from: data) {
            originals = decoded
        }
    }

    func hasOriginal(_ change: PrefChange) -> Bool {
        originals[Self.id(change)] != nil
    }

    /// Saves the current value the first time Crossnest touches a key. Later changes keep the first one.
    func recordIfNeeded(_ change: PrefChange, current: Any?) {
        let id = Self.id(change)
        guard originals[id] == nil else { return }
        originals[id] = Original(value: PrefValue(propertyList: current))
        save()
    }

    /// Returns and forgets the saved original.
    func take(_ change: PrefChange) -> Original? {
        guard let original = originals.removeValue(forKey: Self.id(change)) else { return nil }
        save()
        return original
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(originals).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Crossnest: could not save originals: \(error)")
        }
    }

    private static func id(_ change: PrefChange) -> String {
        "\(change.domain) \(change.key)"
    }
}
