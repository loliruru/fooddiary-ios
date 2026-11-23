import SwiftData
import SwiftUI

struct IntakeRow: View {
    let event: IntakeEvent
    let onRecordAdded: () -> Void

    private var subtitle: String? {
        if event.mealType == .homemade {
            let names = event.orderedIngredients.prefix(3).map(\.name)
            return names.isEmpty ? nil : names.formatted(.list(type: .and))
        }
        return event.merchantName ?? event.brandName
    }

    var body: some View {
        NavigationLink {
            IntakeDetail(event: event, onRecordAdded: onRecordAdded)
        } label: {
            DiaryCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: event.mealType?.symbol ?? event.intakeType.symbol)
                        .font(.headline)
                        .foregroundStyle(DiaryTheme.accent)
                        .frame(width: 38, height: 38)
                        .background(DiaryTheme.accentSurface, in: .rect(cornerRadius: 10))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.displayName).font(.headline)
                        Text(event.kindTitle)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(DiaryTheme.accent)
                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(DiaryTheme.secondaryText)
                                .lineLimit(2)
                        }
                        Text(event.eventTime, format: .dateTime.hour().minute())
                            .font(.footnote)
                            .foregroundStyle(DiaryTheme.secondaryText)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DiaryTheme.secondaryText)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(DiaryTheme.text)
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("intake.record")
    }
}

struct IntakeDetail: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var copying = false
    @State private var confirmDelete = false
    @State private var showError = false

    let event: IntakeEvent
    let onRecordAdded: () -> Void

    var body: some View {
        DiaryPage {
            DiaryCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label(event.kindTitle, systemImage: event.mealType?.symbol ?? event.intakeType.symbol)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DiaryTheme.accent)
                    Text(event.displayName)
                        .font(.title.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(event.eventTime, format: .dateTime.year().month().day().hour().minute())
                        .foregroundStyle(DiaryTheme.secondaryText)
                    value(event.merchantName, title: event.intakeType == .snack ? "intake.purchasePlace" : "intake.merchant")
                    value(event.brandName, title: "intake.brand")
                    value(event.amountText, title: "intake.amount")
                }
            }

            if !event.ingredients.isEmpty {
                DiaryCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("intake.ingredients").font(.headline).accessibilityAddTraits(.isHeader)
                        ForEach(event.orderedIngredients) { ingredient in
                            VStack(alignment: .leading, spacing: 6) {
                                Divider()
                                Text(ingredient.name).font(.subheadline.weight(.semibold))
                                value(ingredient.purchasePlaceName, title: "intake.ingredientSource")
                                value(ingredient.amountText, title: "intake.amount")
                                value(ingredient.note, title: "intake.note")
                            }
                        }
                    }
                }
            }

            if let path = event.photoPath, let data = DiaryPhotos.local.data(for: path), let image = UIImage(data: data) {
                DiaryCard { DiaryPhotoPreview(image: image) }
            }

            if event.note != nil || !event.tags.isEmpty {
                DiaryCard {
                    VStack(alignment: .leading, spacing: 12) {
                        value(event.tags.isEmpty ? nil : event.tags.formatted(.list(type: .and)), title: "intake.tags")
                        value(event.note, title: "intake.note")
                    }
                }
            }

            Button {
                copying = true
            } label: {
                Label(event.intakeType.repeatTitle, systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(DiaryButtonStyle(kind: .secondary))

            Button("intake.delete", role: .destructive) { confirmDelete = true }
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .navigationTitle("intake.detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("common.edit") { editing = true }
            }
        }
        .sheet(isPresented: $editing) {
            IntakeEditor(event: event)
        }
        .sheet(isPresented: $copying) {
            IntakeEditor(event: event, copying: true, onSave: onRecordAdded)
        }
        .confirmationDialog("intake.confirmDelete", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("common.delete", role: .destructive, action: delete)
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text(event.displayName)
        }
        .alert("common.deleteError", isPresented: $showError) {
            Button("common.done", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func value(_ value: String?, title: LocalizedStringKey) -> some View {
        if let value {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.footnote).foregroundStyle(DiaryTheme.secondaryText)
                Text(value).font(.subheadline)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func delete() {
        do {
            try DiaryStore(context: context).deleteIntake(event)
            dismiss()
        } catch {
            showError = true
        }
    }
}
