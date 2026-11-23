import SwiftUI

enum IngredientTextField {
    case name, source

    var title: LocalizedStringKey {
        switch self {
        case .name: "intake.ingredientName"
        case .source: "intake.ingredientSource"
        }
    }
}

struct IngredientFields<NameField: View>: View {
    @Binding var ingredients: [IngredientDraft]
    @ViewBuilder let nameField: (IngredientTextField, UUID, Binding<String>) -> NameField

    var body: some View {
        Section {
            ForEach($ingredients) { $row in
                VStack(alignment: .leading, spacing: 9) {
                    nameField(.name, row.id, $row.name)
                    if !row.isValid {
                        Text("intake.ingredientRequired")
                            .font(.footnote)
                            .foregroundStyle(DiaryTheme.secondaryText)
                    }
                    nameField(.source, row.id, $row.purchasePlaceName)
                    TextField("intake.amount", text: $row.amountText)
                        .frame(minHeight: 44)
                    TextField("intake.note", text: $row.note, axis: .vertical)
                        .frame(minHeight: 44)
                    Button(role: .destructive) {
                        ingredients.removeAll { $0.id == row.id }
                    } label: {
                        Label("intake.removeIngredient", systemImage: "minus.circle")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                }
            }
            Button {
                ingredients.append(IngredientDraft())
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
}
