import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var engine: TweakEngine
    @Binding var selection: SidebarItem?
    @State private var confirmPreset = false
    @State private var confirmUndo = false

    var body: some View {
        Page {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                PageHeader(title: "Welcome to Crossnest",
                           subtitle: "Make your Mac feel familiar after years on Windows.")
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Make my Mac feel like Windows", systemImage: "wand.and.stars")
                        .font(.title2.weight(.semibold))
                    Text("Turns on \(engine.recommended.count) recommended changes in one go: PC-style scrolling, Home and End keys, file extensions in Finder, window snapping and more. Each change appears as a switch you can turn off later.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Apply Recommended Settings") { confirmPreset = true }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(engine.recommendedRemaining.isEmpty)
                        if engine.recommendedRemaining.isEmpty {
                            Pill(text: "All recommended settings are on")
                        } else {
                            Text("\(engine.recommendedRemaining.count) of \(engine.recommended.count) not on yet")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Prefer to choose for yourself?", systemImage: "slider.horizontal.3")
                        .font(.title2.weight(.semibold))
                    Text("Browse each area and flip only the switches you want.")
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
                        ForEach(TweakCategory.allCases) { category in
                            Button {
                                selection = .category(category)
                            } label: {
                                Label(category.title, systemImage: category.symbol)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .controlSize(.large)
                        }
                        Button {
                            selection = .guide
                        } label: {
                            Label("Where is it on Mac?", systemImage: "map")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .controlSize(.large)
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Changed your mind?", systemImage: "arrow.uturn.backward")
                        .font(.title2.weight(.semibold))
                    Text("Crossnest remembers how every setting was before it changed it. Undo puts them all back; settings you changed yourself in System Settings are left alone.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Undo Everything Crossnest Changed…", role: .destructive) { confirmUndo = true }
                        .disabled(!engine.hasAnythingToUndo)
                }
            }
        }
        .confirmationDialog("Apply \(engine.recommendedRemaining.count) recommended settings?",
                            isPresented: $confirmPreset) {
            Button("Apply") { engine.applyRecommended() }
        } message: {
            Text("Finder and the Dock may restart, and some changes need you to log out before they take full effect. You can undo everything from this screen.")
        }
        .confirmationDialog("Undo everything Crossnest changed?", isPresented: $confirmUndo) {
            Button("Undo Everything", role: .destructive) { engine.undoEverything() }
        } message: {
            Text("Every setting goes back to how it was before you first used Crossnest.")
        }
    }
}
