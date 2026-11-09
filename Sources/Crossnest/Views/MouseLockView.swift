import AppKit
import SwiftUI

/// Opt-in page for Mouse Lock: an on/off switch, then the apps it applies to.
struct MouseLockView: View {
    @EnvironmentObject private var live: LiveFeatures

    var body: some View {
        Page {
            PageHeader(title: "Mouse Lock",
                       subtitle: "Keep the pointer inside an app's window so it can't slide onto another screen. Only for the apps you pick, and only while one of them is in front.",
                       symbol: "cursorarrow.square")

            Card {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Use Mouse Lock").font(.headline)
                        Text("Handy for games and full-window apps on a multi-monitor setup. To get the pointer out, switch to another app with Cmd+Tab or Alt+Tab.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Note(symbol: "pc", text: "Like the \"confine cursor to window\" option in many Windows games.")
                        Note(symbol: "hand.raised", text: "Needs Accessibility permission. Works while Crossnest is running.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("Use Mouse Lock", isOn: Binding(get: { live.isOn(.mouseLock) },
                                                           set: { live.set(.mouseLock, on: $0) }))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .tint(Theme.accent)
                }
            }

            MouseLockAppsCard(lock: live.mouseLock)
                .disabled(!live.isOn(.mouseLock))
                .opacity(live.isOn(.mouseLock) ? 1 : 0.5)
        }
    }
}

private struct MouseLockAppsCard: View {
    @ObservedObject var lock: MouseLock

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Apps", systemImage: "app.badge.checkmark").font(.title2.weight(.semibold))
                    Spacer()
                    addMenu
                }

                if lock.apps.isEmpty {
                    Text("No apps yet. Add the apps you want the pointer locked to. If an app is open, Crossnest detects its window size when you add it.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(Array(lock.apps.enumerated()), id: \.element.id) { index, app in
                    if index > 0 { Divider() }
                    row(app)
                }
            }
        }
    }

    private func row(_ app: MouseLockApp) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(nsImage: icon(for: app.bundleID))
                .resizable()
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 6) {
                Text(app.name).font(.headline)
                Note(symbol: "viewfinder", text: app.detected ?? "Not open right now; the size is detected whenever it's in front.")
                Picker("Lock the pointer to", selection: areaBinding(app)) {
                    ForEach(MouseLockApp.Area.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                Stepper(value: setting(app, \.padding), in: 0...200, step: 5) {
                    Text("Padding: \(app.padding) px").monospacedDigit()
                }
                .help("Keeps the pointer this far inside the edges, for example off the title bar.")
                .fixedSize()
                HStack(spacing: 10) {
                    Text("Sensitivity").foregroundStyle(.secondary)
                    Slider(value: setting(app, \.sensitivity), in: 0.25...3, step: 0.05)
                        .frame(width: 200)
                    Text(String(format: "%.2f×", app.sensitivity)).monospacedDigit()
                        .frame(width: 48, alignment: .leading)
                    Button("Reset") { setting(app, \.sensitivity).wrappedValue = 1 }
                        .controlSize(.small)
                        .disabled(app.sensitivity == 1)
                }
                .help("Pointer speed inside this app, relative to normal. Crossnest matches your usual speed by default.")
                if !lock.isCalibrated {
                    Note(symbol: "info.circle", text: "Move the mouse around normally for a few seconds (outside this app) so Crossnest can learn your pointer speed.")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Detect Size") { lock.detect(app.bundleID) }
            Button {
                lock.remove(app.bundleID)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove \(app.name)")
        }
    }

    private var addMenu: some View {
        Menu("Add App") {
            let running = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
                .filter { app in !lock.apps.contains { $0.bundleID == app.bundleIdentifier } }
                .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
            if !running.isEmpty {
                Section("Open now") {
                    ForEach(running, id: \.processIdentifier) { app in
                        Button(app.localizedName ?? "App") { lock.add(app) }
                    }
                }
            }
            Divider()
            Button("Choose from Applications…") { chooseApp() }
        }
        .fixedSize()
    }

    /// A binding to one setting of one app, saved straight away.
    private func setting<Value>(_ app: MouseLockApp, _ keyPath: WritableKeyPath<MouseLockApp, Value>) -> Binding<Value> {
        Binding(
            get: { lock.apps.first { $0.bundleID == app.bundleID }?[keyPath: keyPath] ?? app[keyPath: keyPath] },
            set: { value in
                guard let index = lock.apps.firstIndex(where: { $0.bundleID == app.bundleID }) else { return }
                lock.apps[index][keyPath: keyPath] = value
            }
        )
    }

    private func areaBinding(_ app: MouseLockApp) -> Binding<MouseLockApp.Area> {
        Binding(
            get: { app.area },
            set: { area in
                guard let index = lock.apps.firstIndex(where: { $0.bundleID == app.bundleID }) else { return }
                lock.apps[index].area = area
                lock.detect(app.bundleID)
            }
        )
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        if panel.runModal() == .OK {
            panel.urls.forEach(lock.add(bundleAt:))
        }
    }

    private func icon(for bundleID: String) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .application)
    }
}
