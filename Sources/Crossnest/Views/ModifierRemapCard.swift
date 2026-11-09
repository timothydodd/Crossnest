import SwiftUI

/// Shows any modifier-key remapping set in System Settings and offers to reset it to standard keys.
/// Remapping Ctrl to Command at the system level stops Crossnest's Ctrl shortcuts from ever seeing Ctrl.
struct ModifierRemapCard: View {
    @EnvironmentObject private var engine: TweakEngine
    @State private var remaps = ModifierRemaps.current()
    @State private var hasBackup = ModifierRemaps.hasBackup
    @State private var confirmReset = false

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Modifier key remapping", systemImage: "arrow.left.arrow.right")
                    .font(.title2.weight(.semibold))
                Text("Remapping set in System Settings › Keyboard › Modifier Keys. Crossnest's shortcuts work best with standard keys: if Ctrl is remapped to Command, the Ctrl shortcuts never see a Ctrl press.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if remaps.isEmpty {
                    Note(symbol: "checkmark.circle", text: "None. Every keyboard uses standard modifier keys.")
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(remaps) { remap in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(remap.connectedName ?? "Keyboard \(remap.deviceID) (not plugged in)")
                                    .font(.headline)
                                Text(remap.summary).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                HStack(spacing: 10) {
                    if !remaps.isEmpty {
                        Button("Reset All to Standard Keys…") { confirmReset = true }
                    }
                    if hasBackup {
                        Button("Restore Previous Remapping") { run(ModifierRemaps.restore) }
                    }
                }
            }
        }
        .confirmationDialog("Reset modifier keys on every keyboard to standard?", isPresented: $confirmReset) {
            Button("Reset") { run(ModifierRemaps.resetAll) }
        } message: {
            Text("Crossnest saves the current remapping first, so you can restore it from here. Plugged-in keyboards change straight away; if one doesn't, unplug it and plug it back in.")
        }
    }

    private func run(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            engine.errorMessage = "Couldn't change the modifier keys: \(error.localizedDescription)"
        }
        remaps = ModifierRemaps.current()
        hasBackup = ModifierRemaps.hasBackup
    }
}
