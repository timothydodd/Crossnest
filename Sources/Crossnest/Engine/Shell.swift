import Foundation

enum Shell {
    /// Runs a tool and waits for it. Output is discarded; returns the exit code (-1 if it couldn't start).
    @discardableResult
    static func run(_ path: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }

    /// Asks macOS to reload settings written behind its back (what System Settings does after a change).
    static func activateSettings() {
        run("/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings", ["-u"])
    }

    static func killAll(_ processName: String) {
        run("/usr/bin/killall", [processName])
    }

    /// Shows the standard "Are you sure you want to log out?" dialog.
    static func requestLogOut() {
        run("/usr/bin/osascript", ["-e", #"tell application "System Events" to log out"#])
    }
}
