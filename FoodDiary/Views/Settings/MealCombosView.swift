import SwiftData
import SwiftUI

struct MealCombosView: View {
    private struct Selection: Identifiable {
        let combo: MealCombo
        let ingredients: [IngredientDraft]
        var id: UUID { combo.id }
    }

    @Query(sort: \MealCombo.updatedAt, order: .reverse) private var combos: [MealCombo]
    @State private var selection: Selection?
    @State private var showError = false

    var body: some View {
        Group {
            if combos.isEmpty {
                DiaryPage {
                    DiaryCard {
                        DiaryEmptyState(title: "combo.empty", message: "combo.emptyHint", symbol: "square.on.square")
                    }
                }
            } else {
                List {
                    ComboRows(combos: combos, onSelect: open)
                }
                .scrollContentBackground(.hidden)
                .background(DiaryTheme.canvas)
            }
        }
        .navigationTitle("combo.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(item: $selection) { selection in
            ComboEditor(combo: selection.combo, ingredients: selection.ingredients)
        }
        .alert("combo.openError", isPresented: $showError) {
            Button("common.done", role: .cancel) {}
        }
    }

    private func open(_ combo: MealCombo) {
        do {
            selection = Selection(combo: combo, ingredients: try combo.ingredientDrafts())
        } catch {
            showError = true
        }
    }
}

struct ComboPicker: View {
    @Environment(\.dismiss) private var dismiss
    let combos: [MealCombo]
    let onSelect: (MealCombo) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ComboRows(combos: combos) { combo in
                        onSelect(combo)
                        dismiss()
                    }
                } header: {
                    Text("combo.useHint")
                        .textCase(nil)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DiaryTheme.canvas)
            .navigationTitle("combo.use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
        .tint(DiaryTheme.accent)
    }
}

private struct ComboRows: View {
    @Environment(\.locale) private var locale
    let combos: [MealCombo]
    let onSelect: (MealCombo) -> Void

    var body: some View {
        ForEach(combos) { combo in
            Button {
                onSelect(combo)
            } label: {
                let names = combo.ingredientNames
                VStack(alignment: .leading, spacing: 5) {
                    Text(combo.name).font(.headline)
                    let summary = names.formatted(.list(type: .and).locale(locale))
                    if !summary.isEmpty && summary != combo.name {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(DiaryTheme.secondaryText)
                            .lineLimit(2)
                    }
                }
                .frame(minHeight: 44, alignment: .leading)
            }
            .accessibilityIdentifier("combo.record")
        }
    }
}

private struct ComboEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name: String
    @State private var ingredients: [IngredientDraft]
    @State private var confirmDelete = false
    @State private var errorTitle: LocalizedStringKey = "common.saveError"
    @State private var showError = false

    let combo: MealCombo

    init(combo: MealCombo, ingredients: [IngredientDraft]) {
        self.combo = combo
        _name = State(initialValue: combo.name)
        _ingredients = State(initialValue: ingredients)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("intake.basics") {
                    TextField("intake.mealName", text: $name)
                }
                IngredientFields(ingredients: $ingredients) { field, _, value in
                    TextField(field.title, text: value).frame(minHeight: 44)
                }
                Button("combo.delete", role: .destructive) { confirmDelete = true }
                    .frame(minHeight: 44)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(DiaryTheme.canvas)
            .navigationTitle("combo.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save)
                        .fontWeight(.semibold)
                        .disabled(DiaryName.text(name) == nil || !ingredients.allSatisfy(\.isValid))
                }
            }
            .confirmationDialog("combo.confirmDelete", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("common.delete", role: .destructive, action: delete)
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text(combo.name)
            }
            .alert(errorTitle, isPresented: $showError) {
                Button("common.done", role: .cancel) {}
            }
        }
        .tint(DiaryTheme.accent)
    }

    private func save() {
        do {
            try DiaryStore(context: context).saveCombo(name: name, ingredients: ingredients, editing: combo)
            dismiss()
        } catch {
            errorTitle = "common.saveError"
            showError = true
        }
    }

    private func delete() {
        do {
            try DiaryStore(context: context).deleteCombo(combo)
            dismiss()
        } catch {
            errorTitle = "common.deleteError"
            showError = true
        }
    }
}
