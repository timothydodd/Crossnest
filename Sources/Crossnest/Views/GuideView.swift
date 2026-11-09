import AppKit
import SwiftUI

struct GuideView: View {
    @State private var query = ""

    var body: some View {
        Page {
            PageHeader(title: "Where is it on Mac?",
                       subtitle: "The Mac name for things you know from Windows.",
                       symbol: "map")

            let matches = Guide.entries.filter { $0.matches(query) }
            if matches.isEmpty {
                ContentUnavailableView.search(text: query)
            }
            ForEach(GuideEntry.Section.allCases) { section in
                let rows = matches.filter { $0.section == section }
                if !rows.isEmpty {
                    Text(section.rawValue).font(.title3.weight(.semibold)).padding(.top, 4)
                    Card {
                        VStack(spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                                GuideRow(entry: entry)
                                if index < rows.count - 1 {
                                    Divider().padding(.vertical, 10)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $query, placement: .toolbar, prompt: "Search, e.g. Task Manager")
    }
}

private struct GuideRow: View {
    let entry: GuideEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.windows)
                .font(.headline)
                .frame(width: 190, alignment: .leading)
            Image(systemName: "arrow.right")
                .foregroundStyle(Theme.accent)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.mac).font(.headline).foregroundStyle(Theme.accent)
                Text(entry.how)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let action = entry.action {
                Button(action.label) { perform(action) }
            }
        }
    }

    private func perform(_ action: GuideEntry.Action) {
        let workspace = NSWorkspace.shared
        switch action {
        case .openApp(let bundleID):
            if let url = workspace.urlForApplication(withBundleIdentifier: bundleID) {
                workspace.openApplication(at: url, configuration: .init())
            }
        case .openURL(let string):
            if let url = URL(string: string) { workspace.open(url) }
        }
    }
}
