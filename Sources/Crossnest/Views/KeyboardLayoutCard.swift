import AppKit
import SwiftUI

/// "Your keyboard": which modifier the Windows key sends, so Alt+Tab and Windows+L follow the real keys.
/// Detect listens for the next modifier press inside this window, so it needs no extra permission.
struct KeyboardLayoutCard: View {
    @EnvironmentObject private var live: LiveFeatures
    @State private var monitor: Any?
    @State private var detected: String?

    private var isDetecting: Bool { monitor != nil }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Your keyboard", systemImage: "keyboard")
                    .font(.title2.weight(.semibold))
                Text("Some PC keyboards have a Mac mode that swaps what the Windows and Alt keys send. Tell Crossnest which yours does, so Alt+Tab and Windows+L use the keys you expect.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Picker("Windows key", selection: $live.windowsKey) {
                    ForEach(WindowsKey.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                HStack(spacing: 10) {
                    Button(isDetecting ? "Press your Windows key now…" : "Detect") {
                        isDetecting ? stopDetecting() : startDetecting()
                    }
                    if isDetecting {
                        Button("Cancel") { stopDetecting() }
                    } else if let detected {
                        Note(symbol: "checkmark.circle", text: detected)
                    }
                }
            }
        }
        .onDisappear { stopDetecting() }
    }

    private func startDetecting() {
        detected = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.command) {
                finish(.command)
            } else if flags.contains(.option) {
                finish(.option)
            }
            return event
        }
    }

    private func finish(_ key: WindowsKey) {
        live.windowsKey = key
        detected = key == .command
            ? "Your Windows key sends Command."
            : "Your Windows key sends Option, so Alt sends Command."
        stopDetecting()
    }

    private func stopDetecting() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
