import SwiftData
import SwiftUI

struct IntakeEditor: View {
    private enum NameField: Hashable, Identifiable {
        case food, merchant, ingredient(UUID), source(UUID)

        var id: Self { self }
        var kind: SavedKind {
            switch self {
            case .food, .ingredient: .food
            case .merchant, .source: .place
            }
        }
    }

    private struct FavoriteRequest {
        let kind: SavedKind
        let name: String
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(sort: \IntakeEvent.eventTime, order: .reverse) private var events: [IntakeEvent]
    @Query private var foods: [SavedFood]
    @Query private var places: [SavedPlace]
    @State private var draft: IntakeDraft
    @State private var tag = ""
    @State private var lookup: NameField?
    @State private var pendingFavorite: FavoriteRequest?
    @State private var showFavoriteConfirmation = false
    @State private var showError = false
    @State private var errorTitle: LocalizedStringKey = "common.saveError"
    @State private var loadingPhoto = false

    private let editing: IntakeEvent?
    private let showsLatest: Bool
    private let onSave: () -> Void

    init(type: IntakeType, onSave: @escaping () -> Void) {
        _draft = State(initialValue: IntakeDraft(type: type))
        editing = nil
        showsLatest = true
        self.onSave = onSave
    }

    init(event: IntakeEvent, copying: Bool = false, onSave: @escaping () -> Void = {}) {
        _draft = State(initialValue: IntakeDraft(event: event, copying: copying))
        editing = copying ? nil : event
        showsLatest = false
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                if showsLatest, let latest = events.first(where: { $0.intakeType == draft.intakeType }) {
                    Section {
                        Button {
                            draft = IntakeDraft(event: latest, copying: true)
                            tag = ""
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(draft.intakeType.repeatTitle, systemImage: "arrow.counterclockwise")
                                Text(latest.displayName)
                                    .font(.footnote)
                                    .foregroundStyle(DiaryTheme.secondaryText)
                            }
                            .frame(minHeight: 44, alignment: .leading)
                        }
                        .disabled(loadingPhoto)
                    }
                }

                if draft.intakeType == .meal {
                    mealChoices
                }

                Section("intake.basics") {
                    nameField(.food, title: draft.intakeType == .snack ? "intake.snackName" : "intake.mealName")
                    DatePicker("intake.time", selection: $draft.eventTime)

                    if !draft.isHomemade {
                        nameField(.merchant, title: draft.intakeType == .snack ? "intake.purchasePlace" : "intake.merchant")
                    }
                    if draft.intakeType == .snack {
                        TextField("intake.brand", text: $draft.brandName)
                        TextField("intake.amount", text: $draft.amountText)
                    }
                }

                if draft.isHomemade {
                    ingredientFields
                }

                Section("photo.title") {
                    DiaryPhotoField(previousPath: editing?.photoPath, photo: $draft.photo, isLoading: $loadingPhoto)
                }
                tagFields
                Section("intake.note") {
                    TextField("intake.notePrompt", text: $draft.note, axis: .vertical)
                        .lineLimit(3...7)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(DiaryTheme.canvas)
            .navigationTitle(editing == nil ? draft.intakeType.addTitle : "intake.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!draft.canSave || loadingPhoto)
                }
            }
            .sheet(item: $lookup) { field in
                NameLookupView(
                    favorites: SavedName.sorted(favoriteNames(for: field.kind)),
                    history: historyNames(for: field),
                    kind: field.kind
                ) { value in
                    binding(for: field).wrappedValue = value
                }
            }
            .confirmationDialog(
                pendingFavorite?.kind.addTitle ?? "favorites.title", isPresented: $showFavoriteConfirmation,
                titleVisibility: .visible, presenting: pendingFavorite
            ) { request in
                Button("common.save") { saveFavorite(request) }
                Button("common.cancel", role: .cancel) {}
            } message: { request in
                Text(request.name)
            }
            .alert(errorTitle, isPresented: $showError) {
                Button("common.done", role: .cancel) {}
            }
        }
        .tint(DiaryTheme.accent)
    }

    private var mealChoices: some View {
        Section("intake.mealType") {
            let layout = typeSize >= .xxxLarge ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
            layout {
                ForEach(MealType.allCases) { type in
                    Button {
                        draft.mealType = type
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: type.symbol).accessibilityHidden(true)
                            Text(type.title)
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(draft.mealType == type ? DiaryTheme.onAccent : DiaryTheme.accent)
                        .background(
                            draft.mealType == type ? DiaryTheme.accent : DiaryTheme.accentSurface,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                    .buttonStyle(.borderless)
                    .accessibilityAddTraits(draft.mealType == type ? .isSelected : [])
                }
            }
        }
    }

    private var ingredientFields: some View {
        Section {
            ForEach($draft.ingredients) { $row in
                VStack(alignment: .leading, spacing: 9) {
                    nameField(.ingredient(row.id), title: "intake.ingredientName")
                    if !row.isEmpty && DiaryName.text(row.name) == nil {
                        Text("intake.ingredientRequired")
                            .font(.footnote)
                            .foregroundStyle(DiaryTheme.secondaryText)
                    }
                    nameField(.source(row.id), title: "intake.ingredientSource")
                    TextField("intake.amount", text: $row.amountText)
                        .frame(minHeight: 44)
                    TextField("intake.note", text: $row.note, axis: .vertical)
                        .frame(minHeight: 44)
                    Button(role: .destructive) {
                        draft.ingredients.removeAll { $0.id == row.id }
                    } label: {
                        Label("intake.removeIngredient", systemImage: "minus.circle")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                }
            }
            Button {
                draft.ingredients.append(IngredientDraft())
            } label: {
                Label("intake.addIngredient", systemImage: "plus.circle")
                    .frame(minHeight: 44)
            }
        } header: {
            Text("intake.ingredients")
        } footer: {
            Text("intake.ingredientHint")
        }
    }

    private var tagFields: some View {
        Section("intake.tags") {
            ForEach(draft.tags, id: \.self) { name in
                HStack {
                    Text(name)
                    Spacer()
                    Button(role: .destructive) {
                        draft.tags.removeAll { $0 == name }
                    } label: {
                        Image(systemName: "minus.circle")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("intake.removeTag")
                    .accessibilityHint(Text(name))
                }
            }
            HStack {
                TextField("intake.tagName", text: $tag)
                    .submitLabel(.done)
                    .onSubmit(addTag)
                Button(action: addTag) {
                    Image(systemName: "plus.circle")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.borderless)
                .disabled(DiaryName.text(tag) == nil)
                .accessibilityLabel("intake.addTag")
            }
        }
    }

    private func nameField(_ field: NameField, title: LocalizedStringKey) -> some View {
        let text = binding(for: field)
        let key = DiaryName.normalized(text.wrappedValue)
        let isFavorite = favoriteNames(for: field.kind).contains { DiaryName.normalized($0.name) == key }

        return IntakeNameField(
            title: title, kind: field.kind, text: text, isFavorite: isFavorite,
            onLookup: { lookup = field },
            onFavorite: {
                guard let name = DiaryName.text(text.wrappedValue) else { return }
                pendingFavorite = FavoriteRequest(kind: field.kind, name: name)
                showFavoriteConfirmation = true
            }
        )
    }

    private func binding(for field: NameField) -> Binding<String> {
        switch field {
        case .food: $draft.displayName
        case .merchant: $draft.merchantName
        case .ingredient(let id): ingredientBinding(id, keyPath: \.name)
        case .source(let id): ingredientBinding(id, keyPath: \.purchasePlaceName)
        }
    }

    private func ingredientBinding(_ id: UUID, keyPath: WritableKeyPath<IngredientDraft, String>) -> Binding<String> {
        Binding {
            draft.ingredients.first { $0.id == id }?[keyPath: keyPath] ?? ""
        } set: { value in
            guard let index = draft.ingredients.firstIndex(where: { $0.id == id }) else { return }
            draft.ingredients[index][keyPath: keyPath] = value
        }
    }

    private func favoriteNames(for kind: SavedKind) -> [SavedName] {
        switch kind {
        case .food: foods.map(SavedName.food)
        case .place: places.map(SavedName.place)
        }
    }

    private func historyNames(for field: NameField) -> [String] {
        switch field {
        case .food:
            DiaryName.distinct(events.map(\.displayName))
        case .ingredient:
            DiaryName.distinct(events.flatMap { $0.orderedIngredients.map(\.name) })
        case .merchant, .source:
            DiaryName.distinct(events.flatMap {
                [$0.merchantName].compactMap { $0 } + $0.orderedIngredients.compactMap(\.purchasePlaceName)
            })
        }
    }

    private func addTag() {
        draft.tags = DiaryName.distinct(draft.tags + [tag])
        tag = ""
    }

    private func saveFavorite(_ request: FavoriteRequest) {
        do {
            try DiaryStore(context: context).saveFavorite(request.kind, name: request.name)
        } catch DiaryStore.InputError.duplicateFavorite {
            errorTitle = "favorites.duplicate"
            showError = true
        } catch {
            errorTitle = "common.saveError"
            showError = true
        }
    }

    private func save() {
        addTag()
        do {
            try DiaryStore(context: context).saveIntake(draft, editing: editing)
            dismiss()
            onSave()
        } catch {
            errorTitle = "common.saveError"
            showError = true
        }
    }
}
