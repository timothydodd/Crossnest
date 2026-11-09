import SwiftUI

/// Shown while a live feature is on but Crossnest hasn't been given Accessibility permission yet.
struct PermissionBanner: View {
    @EnvironmentObject private var live: LiveFeatures

    var body: some View {
        Banner(symbol: "hand.raised.circle.fill",
               title: "Crossnest needs Accessibility permission",
               message: "Keyboard shortcuts, smooth scrolling and Mouse Lock need to see your keyboard and mouse. In System Settings › Privacy & Security, open Accessibility (on newer macOS it's inside Device Control and Data Access) and turn on Crossnest. The features start as soon as you do.") {
            Button("Open System Settings") {
                // Prompting first adds this build to the Accessibility list, so there's a switch to turn on.
                live.requestPermission()
                live.openAccessibilitySettings()
            }
                .buttonStyle(.borderedProminent)
        }
    }
}
