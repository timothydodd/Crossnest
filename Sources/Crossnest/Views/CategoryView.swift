import SwiftUI

struct CategoryView: View {
    @EnvironmentObject private var engine: TweakEngine
    let category: TweakCategory

    var body: some View {
        Page {
            PageHeader(title: category.title, subtitle: category.subtitle, symbol: category.symbol)

            if category == .shortcuts {
                KeyboardLayoutCard()
            }

            Card {
                VStack(spacing: 0) {
                    let tweaks = engine.tweaks(in: category)
                    ForEach(Array(tweaks.enumerated()), id: \.element.id) { index, tweak in
                        TweakRow(tweak: tweak)
                        if index < tweaks.count - 1 {
                            Divider().padding(.vertical, 12)
                        }
                    }
                }
            }

            if category == .shortcuts {
                ModifierRemapCard()
            }
        }
    }
}

struct TweakRow: View {
    @EnvironmentObject private var engine: TweakEngine
    let tweak: Tweak

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(tweak.title).font(.headline)
                    if tweak.recommended { Pill(text: "Recommended") }
                }
                Text(tweak.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let onWindows = tweak.onWindows {
                    Note(symbol: "pc", text: onWindows)
                }
                if let restart = tweak.restart {
                    Note(symbol: "arrow.clockwise", text: restart.hint)
                }
                if case .live = tweak.kind {
                    Note(symbol: "hand.raised", text: "Needs Accessibility permission. Works while Crossnest is running; it stays in the menu bar when you close this window.")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(tweak.title, isOn: Binding(
                get: { engine.isOn(tweak) },
                set: { engine.set(tweak, on: $0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .tint(Theme.accent)
        }
    }
}
