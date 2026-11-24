import SwiftData
import SwiftUI

struct SymptomEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \IntakeEvent.eventTime, order: .reverse) private var intakes: [IntakeEvent]
    @State private var draft: SymptomDraft
    @State private var showError = false
    @State private var savedEvent: SymptomEvent?

    private let editing: SymptomEvent?
    private let suggestedMeal: IntakeEvent?
    private let onSave: () -> Void

    init(event: SymptomEvent? = nil, suggestedMeal: IntakeEvent? = nil, onSave: @escaping () -> Void = {}) {
        _draft = State(initialValue: event.map { SymptomDraft(event: $0) } ?? SymptomDraft())
        editing = event
        self.suggestedMeal = suggestedMeal
        self.onSave = onSave
    }

    private var meals: [IntakeEvent] { intakes.filter { $0.intakeType == .meal } }

    var body: some View {
        NavigationStack {
            if let savedEvent {
                SymptomDetail(event: savedEvent, onDelete: { dismiss() })
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("common.done") { dismiss() }
                        }
                    }
            } else {
                editorForm
            }
        }
        .tint(DiaryTheme.accent)
    }

    private var editorForm: some View {
        Form {
            Section {
                DatePicker("symptom.started", selection: $draft.symptomTime)
            }
            if !meals.isEmpty {
                mealAssociation
            }
            feelingChoices
            Section("symptom.list") {
                ForEach(Symptom.allCases) { symptom in
                    Toggle(isOn: selection(for: symptom)) {
                        Text(symptom.title)
                    }
                    .frame(minHeight: 44)
                    if symptom == .diarrhea && draft.symptoms.contains(.diarrhea) {
                        Stepper(value: $draft.diarrheaCount, in: 0...Int.max) {
                            LabeledContent("symptom.diarrheaCount") {
                                Text(draft.diarrheaCount, format: .number)
                            }
                        }
                        .accessibilityIdentifier("symptom.diarrheaCount")
                    }
                }
            }
            DisclosureGroup("symptom.more") {
                Picker("symptom.severity", selection: $draft.severity) {
                    Text("common.unspecified").tag(Optional<SymptomSeverity>.none)
                    ForEach(SymptomSeverity.allCases) { severity in
                        Text(severity.title).tag(Optional(severity))
                    }
                }
                Picker("symptom.duration", selection: $draft.duration) {
                    Text("common.unspecified").tag(Optional<SymptomDuration>.none)
                    ForEach(SymptomDuration.allCases) { duration in
                        Text(duration.title).tag(Optional(duration))
                    }
                }
                TextField("intake.notePrompt", text: $draft.note, axis: .vertical)
                    .lineLimit(3...7)
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(DiaryTheme.canvas)
        .navigationTitle(editing == nil ? "home.action.symptom" : "symptom.edit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("common.save", action: save).fontWeight(.semibold)
            }
        }
        .alert("common.saveError", isPresented: $showError) {
            Button("common.done", role: .cancel) {}
        }
    }

    private var mealAssociation: some View {
        Section {
            if let suggestedMeal, draft.linkedMeal == nil {
                Button {
                    draft.linkedMeal = suggestedMeal
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("symptom.linkSuggested", systemImage: "link")
                        mealLabel(suggestedMeal)
                    }
                    .frame(minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier("symptom.linkSuggestedMeal")
            }
            Picker("symptom.linkedMeal", selection: Binding(
                get: { draft.linkedMeal?.id },
                set: { id in draft.linkedMeal = meals.first { $0.id == id } }
            )) {
                Text("symptom.noLinkedMeal").tag(Optional<UUID>.none)
                ForEach(meals) { meal in
                    mealLabel(meal).tag(Optional(meal.id))
                }
            }
            .pickerStyle(.navigationLink)
        }
    }

    private func mealLabel(_ meal: IntakeEvent) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(meal.displayName)
            Text(meal.eventTime, format: .dateTime.year().month().day().hour().minute())
                .font(.footnote)
                .foregroundStyle(DiaryTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    private var feelingChoices: some View {
        Section {
            let layout = typeSize >= .xxxLarge
                ? AnyLayout(VStackLayout(spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
                ForEach(BodyFeeling.allCases) { feeling in
                    let selected = draft.feeling == feeling
                    Button {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                            draft.feeling = selected ? nil : feeling
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text(verbatim: feeling.emoji)
                                .font(.title)
                                .accessibilityHidden(true)
                            Text(feeling.title).font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 62)
                        .padding(.vertical, 6)
                        .foregroundStyle(DiaryTheme.text)
                        .background(DiaryTheme.accentSurface, in: .rect(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(selected ? DiaryTheme.accent : DiaryTheme.border, lineWidth: selected ? 2 : 1)
                                .allowsHitTesting(false)
                        }
                        .scaleEffect(selected && !reduceMotion ? 0.97 : 1)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        } header: {
            Text("feeling.title")
        } footer: {
            if draft.feeling == nil {
                Text("feeling.unknown")
            }
        }
    }

    private func selection(for symptom: Symptom) -> Binding<Bool> {
        Binding {
            draft.symptoms.contains(symptom)
        } set: { selected in
            if selected {
                draft.symptoms.insert(symptom)
            } else {
                draft.symptoms.remove(symptom)
            }
        }
    }

    private func save() {
        do {
            let event = try DiaryStore(context: context).saveSymptom(draft, editing: editing)
            if editing == nil {
                savedEvent = event
            } else {
                dismiss()
            }
            onSave()
        } catch {
            showError = true
        }
    }
}
