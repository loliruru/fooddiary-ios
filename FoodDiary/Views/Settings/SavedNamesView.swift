import SwiftData
import SwiftUI

struct SavedNamesView: View {
    let kind: SavedKind
    @Query private var foods: [SavedFood]
    @Query private var places: [SavedPlace]
    @State private var adding = false
    @State private var selected: SavedName?

    private var entries: [SavedName] {
        SavedName.sorted(kind == .food ? foods.map(SavedName.food) : places.map(SavedName.place))
    }

    var body: some View {
        List {
            if entries.isEmpty {
                DiaryEmptyState(title: "favorites.empty", message: "favorites.emptyHint", symbol: kind.symbol)
            }
            ForEach(entries) { entry in
                Button {
                    selected = entry
                } label: {
                    HStack(spacing: 12) {
                        if let path = entry.photoPath, let data = DiaryPhotos.local.data(for: path),
                           let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 36, height: 36)
                                .clipShape(.rect(cornerRadius: 9))
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: kind.symbol)
                                .foregroundStyle(DiaryTheme.accent)
                                .accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.name)
                            if let category = entry.category {
                                Text(category).font(.footnote).foregroundStyle(DiaryTheme.secondaryText)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(DiaryTheme.secondaryText)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .foregroundStyle(DiaryTheme.text)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DiaryTheme.canvas)
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("common.add", systemImage: "plus") { adding = true }
            }
        }
        .sheet(isPresented: $adding) { SavedNameEditor(kind: kind) }
        .sheet(item: $selected) { entry in SavedNameEditor(kind: kind, entry: entry) }
    }
}

private struct SavedNameEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var category: String
    @State private var note: String
    @State private var photo: PhotoChange = .keep
    @State private var loadingPhoto = false
    @State private var confirmDelete = false
    @State private var showError = false
    @State private var errorTitle: LocalizedStringKey = "common.saveError"

    let kind: SavedKind
    let entry: SavedName?

    init(kind: SavedKind, entry: SavedName? = nil) {
        self.kind = kind
        self.entry = entry
        _name = State(initialValue: entry?.name ?? "")
        _category = State(initialValue: entry?.category ?? "")
        if case .place(let place)? = entry {
            _note = State(initialValue: place.note ?? "")
        } else {
            _note = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("favorites.name", text: $name)
                    TextField("favorites.category", text: $category)
                    if kind == .place {
                        TextField("intake.note", text: $note, axis: .vertical)
                            .lineLimit(2...5)
                    }
                }
                if kind == .place {
                    Section("favorites.avatar") {
                        DiaryPhotoField(previousPath: entry?.photoPath, photo: $photo, isLoading: $loadingPhoto)
                    }
                }
                if entry != nil {
                    Section {
                        Button("favorites.delete", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(DiaryTheme.canvas)
            .navigationTitle(entry == nil ? kind.addTitle : "favorites.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save)
                        .fontWeight(.semibold)
                        .disabled(DiaryName.text(name) == nil || loadingPhoto)
                }
            }
            .confirmationDialog("favorites.confirmDelete", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("common.delete", role: .destructive, action: delete)
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("favorites.deleteHint")
            }
            .alert(errorTitle, isPresented: $showError) {
                Button("common.done", role: .cancel) {}
            }
        }
    }

    private func save() {
        do {
            try DiaryStore(context: context).saveFavorite(kind, name: name, category: category, note: note, photo: photo, editing: entry)
            dismiss()
        } catch DiaryStore.InputError.duplicateFavorite {
            errorTitle = "favorites.duplicate"
            showError = true
        } catch {
            errorTitle = "common.saveError"
            showError = true
        }
    }

    private func delete() {
        guard let entry else { return }
        do {
            try DiaryStore(context: context).deleteFavorite(entry)
            dismiss()
        } catch {
            errorTitle = "common.deleteError"
            showError = true
        }
    }
}
