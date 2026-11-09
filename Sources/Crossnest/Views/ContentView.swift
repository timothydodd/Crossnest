import SwiftUI

enum SidebarItem: Hashable {
    case home
    case category(TweakCategory)
    case mouseLock
    case guide
}

struct ContentView: View {
    @EnvironmentObject private var engine: TweakEngine
    @EnvironmentObject private var live: LiveFeatures
    @State private var selection: SidebarItem? = .home

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                // In a section so the first row sits below the title bar, which swallows clicks.
                Section("Crossnest") {
                    Label("Welcome", systemImage: "house").tag(SidebarItem.home)
                }

                Section("Settings") {
                    ForEach(TweakCategory.allCases) { category in
                        Label(category.title, systemImage: category.symbol)
                            .badge(onCount(category))
                            .tag(SidebarItem.category(category))
                    }
                }

                Section("Optional") {
                    Label("Mouse Lock", systemImage: "cursorarrow.square")
                        .badge(live.isOn(.mouseLock) ? live.mouseLock.apps.count : 0)
                        .tag(SidebarItem.mouseLock)
                }

                Section("Help") {
                    Label("Where is it on Mac?", systemImage: "map").tag(SidebarItem.guide)
                }
            }
            .navigationSplitViewColumnWidth(min: 210, ideal: 230)
        } detail: {
            detail
                .safeAreaInset(edge: .bottom) {
                    if live.needsPermission || !engine.pendingRestarts.isEmpty {
                        VStack(spacing: 8) {
                            if live.needsPermission {
                                PermissionBanner()
                            }
                            if !engine.pendingRestarts.isEmpty {
                                PendingRestartBanner()
                            }
                        }
                        .padding(12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.easeOut(duration: 0.2), value: engine.pendingRestarts)
                .animation(.easeOut(duration: 0.2), value: live.needsPermission)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            engine.refresh()
        }
        .alert("Something went wrong", isPresented: errorShown) {
            Button("OK") { engine.errorMessage = nil }
        } message: {
            Text(engine.errorMessage ?? "")
        }
    }

    @ViewBuilder private var detail: some View {
        switch selection ?? .home {
        case .home: HomeView(selection: $selection)
        case .category(let category): CategoryView(category: category)
        case .mouseLock: MouseLockView()
        case .guide: GuideView()
        }
    }

    private func onCount(_ category: TweakCategory) -> Int {
        engine.tweaks(in: category).filter(engine.isOn).count
    }

    private var errorShown: Binding<Bool> {
        Binding(get: { engine.errorMessage != nil }, set: { if !$0 { engine.errorMessage = nil } })
    }
}
