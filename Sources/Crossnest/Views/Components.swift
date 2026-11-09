import SwiftUI

/// Shared look for Crossnest. Screens should build from these rather than styling inline.
enum Theme {
    static let accent = Color(red: 0.11, green: 0.55, blue: 0.53)
    static let warm = Color(red: 0.95, green: 0.55, blue: 0.25)
    static let cornerRadius: CGFloat = 12
    static let pagePadding: CGFloat = 24
    static let contentMaxWidth: CGFloat = 760
}

/// Title block at the top of each detail screen.
struct PageHeader: View {
    let title: String
    let subtitle: String
    var symbol: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 36)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.largeTitle.weight(.semibold))
                Text(subtitle).font(.title3).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Rounded panel used for cards and grouped lists.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(.separator.opacity(0.6)))
    }
}

/// Small capsule label, e.g. "Recommended".
struct Pill: View {
    let text: String
    var color: Color = Theme.accent

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: Capsule())
    }
}

/// A grey note with an icon, e.g. "On Windows: …" or a restart hint.
struct Note: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol).frame(width: 14)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}

/// Notice pinned to the bottom of the window (permission needed, restart needed…).
/// The text takes the width first and buttons sit underneath it, so long messages never squeeze
/// into a narrow column and blow up the banner's height.
struct Banner<Actions: View>: View {
    let symbol: String
    let title: String
    let message: String
    var onDismiss: (() -> Void)? = nil
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(Theme.warm)
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(message).font(.callout).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) { actions }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let onDismiss {
                Button(action: onDismiss) { Image(systemName: "xmark") }
                    .buttonStyle(.borderless)
                    .help("Dismiss")
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(.separator))
    }
}

/// Scrollable page with Crossnest's standard padding and reading width.
struct Page<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content
            }
            .padding(Theme.pagePadding)
            .frame(maxWidth: Theme.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}
