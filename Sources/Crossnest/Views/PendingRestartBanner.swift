import SwiftUI

/// Shown at the bottom of the window after changes that need something restarted.
struct PendingRestartBanner: View {
    @EnvironmentObject private var engine: TweakEngine

    private var services: [Restart] { engine.pendingRestarts.filter(\.isService).sorted() }
    private var needsLogOut: Bool { engine.pendingRestarts.contains(.logOut) }
    private var needsReopen: Bool { engine.pendingRestarts.contains(.reopenApps) }

    var body: some View {
        Banner(symbol: "arrow.clockwise.circle.fill",
               title: "Some changes aren't showing yet",
               message: message,
               onDismiss: engine.dismissPending) {
            if !services.isEmpty {
                Button("Restart Now") { engine.restartServicesNow() }
                    .buttonStyle(.borderedProminent)
            }
            if needsLogOut {
                Button("Log Out…") { engine.logOut() }
            }
        }
    }

    private var message: String {
        var parts: [String] = []
        if !services.isEmpty {
            parts.append("Restart \(ListFormatter.localizedString(byJoining: services.map(\.displayName))) to see them.")
        }
        if needsLogOut {
            parts.append("Keyboard and mouse changes take full effect after you log out.")
        }
        if needsReopen {
            parts.append("Apps that are already open pick up changes when you reopen them.")
        }
        return parts.joined(separator: " ")
    }
}
