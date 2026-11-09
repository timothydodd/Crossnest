import AppKit
import SwiftUI

/// The floating Alt+Tab overlay. It never takes focus, so the app underneath stays active.
@MainActor
final class SwitcherPanel {
    private final class Model: ObservableObject {
        @Published var windows: [SwitcherWindow] = []
        @Published var selected = 0
    }

    private let model = Model()
    private var panel: NSPanel?
    private var hostingView: NSHostingView<SwitcherView>?

    func show(_ windows: [SwitcherWindow], selected: Int) {
        model.windows = windows
        model.selected = selected
        let panel = self.panel ?? makePanel()
        resizeAndCenter(panel)
        panel.orderFrontRegardless()
    }

    func select(_ index: Int) {
        model.selected = index
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        let hostingView = NSHostingView(rootView: SwitcherView(model: model))
        panel.contentView = hostingView
        self.panel = panel
        self.hostingView = hostingView
        return panel
    }

    /// Centers on the screen with the mouse pointer, like Windows shows Alt+Tab on the active display.
    private func resizeAndCenter(_ panel: NSPanel) {
        guard let hostingView else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        hostingView.rootView = SwitcherView(model: model, maxWidth: visible.width * 0.9)
        let size = hostingView.fittingSize
        panel.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                              width: size.width, height: size.height), display: true)
    }

    private struct SwitcherView: View {
        @ObservedObject var model: Model
        var maxWidth: CGFloat = 1200

        private let tileSize: CGFloat = 132
        private let spacing: CGFloat = 8

        private var columns: Int {
            let fit = Int((maxWidth - 32 + spacing) / (tileSize + spacing))
            return max(1, min(model.windows.count, fit))
        }

        var body: some View {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(tileSize), spacing: spacing), count: columns),
                      spacing: spacing) {
                ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                    tile(window, isSelected: index == model.selected)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.15)))
            .fixedSize()
        }

        private func tile(_ window: SwitcherWindow, isSelected: Bool) -> some View {
            VStack(spacing: 6) {
                Image(nsImage: window.icon)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .opacity(window.isMinimized ? 0.55 : 1)
                Text(window.label)
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(window.appName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(width: tileSize, height: tileSize)
            .background(isSelected ? Theme.accent.opacity(0.35) : .clear, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 2))
        }
    }
}
