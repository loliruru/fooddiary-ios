import SwiftUI

struct IntakeNameField: View {
    let title: LocalizedStringKey
    let kind: SavedKind
    @Binding var text: String
    let isFavorite: Bool
    let onLookup: () -> Void
    let onFavorite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(DiaryTheme.secondaryText)
                .accessibilityHidden(true)

            HStack {
                TextField(title, text: $text)
                    .autocorrectionDisabled()
                    .frame(minHeight: 44)
                Button(action: onLookup) {
                    Image(systemName: "magnifyingglass")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("lookup.title")
                .accessibilityHint(title)
            }
            if isFavorite {
                Label("favorites.saved", systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(DiaryTheme.accent)
            } else if DiaryName.text(text) != nil {
                Button(action: onFavorite) {
                    Label(kind.addTitle, systemImage: "star")
                        .font(.subheadline)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

struct NameLookupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    let favorites: [SavedName]
    let history: [String]
    let kind: SavedKind
    let onSelect: (String) -> Void

    private func matches(_ name: String) -> Bool {
        let key = DiaryName.normalized(search)
        return key.isEmpty || DiaryName.normalized(name).contains(key)
    }

    var body: some View {
        NavigationStack {
            List {
                Section(kind.title) {
                    let visible = favorites.filter { matches($0.name) }
                    if visible.isEmpty {
                        Text("lookup.noFavorites").foregroundStyle(.secondary)
                    }
                    ForEach(visible) { item in
                        choice(item.name)
                    }
                }
                Section("lookup.history") {
                    let visible = history.filter(matches)
                    if visible.isEmpty {
                        Text("lookup.noHistory").foregroundStyle(.secondary)
                    }
                    ForEach(visible, id: \.self) { name in
                        choice(name)
                    }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "lookup.search")
            .navigationTitle("lookup.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
    }

    private func choice(_ value: String) -> some View {
        Button {
            onSelect(value)
            dismiss()
        } label: {
            Text(value)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .foregroundStyle(DiaryTheme.text)
    }
}
