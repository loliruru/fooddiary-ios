import SwiftUI

struct HistoryFilters: View {
    @Environment(\.dismiss) private var dismiss
    @Binding private var applied: TimelineFilter
    @State private var draft: TimelineFilter

    init(applied: Binding<TimelineFilter>) {
        _applied = applied
        _draft = State(initialValue: applied.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("history.kind", selection: $draft.kind) {
                        ForEach(TimelineFilter.Kind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    Picker("feeling.title", selection: $draft.feeling) {
                        ForEach(TimelineFilter.Feeling.allCases) { feeling in
                            Text(feeling.title).tag(feeling)
                        }
                    }
                    Picker("symptom.list", selection: $draft.symptom) {
                        Text("common.all").tag(Optional<Symptom>.none)
                        ForEach(Symptom.allCases) { symptom in
                            Text(symptom.title).tag(Optional(symptom))
                        }
                    }
                }
                Section {
                    Toggle("history.dateRange", isOn: Binding {
                        draft.days != nil
                    } set: { enabled in
                        let today = Calendar.autoupdatingCurrent.startOfDay(for: .now)
                        draft.days = enabled ? today...today : nil
                    })
                    if let days = draft.days {
                        DatePicker("history.startDate", selection: Binding {
                            draft.days?.lowerBound ?? days.lowerBound
                        } set: { day in
                            let end = draft.days?.upperBound ?? days.upperBound
                            draft.days = day...max(day, end)
                        }, displayedComponents: .date)
                        DatePicker("history.endDate", selection: Binding {
                            draft.days?.upperBound ?? days.upperBound
                        } set: { day in
                            let start = draft.days?.lowerBound ?? days.lowerBound
                            draft.days = min(start, day)...day
                        }, displayedComponents: .date)
                    }
                }
                Button("history.resetFilters") { draft = TimelineFilter() }
                    .disabled(draft == TimelineFilter())
            }
            .scrollContentBackground(.hidden)
            .background(DiaryTheme.canvas)
            .navigationTitle("history.filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("history.applyFilters") {
                        applied = draft
                        dismiss()
                    }
                }
            }
        }
    }
}

private extension TimelineFilter.Kind {
    var title: LocalizedStringKey {
        switch self {
        case .all: "common.all"
        case .meals: "intake.meal"
        case .takeout: "intake.takeout"
        case .dineIn: "intake.dineIn"
        case .homemade: "intake.homemade"
        case .snacks: "intake.snack"
        case .symptoms: "history.kind.symptoms"
        }
    }
}

private extension TimelineFilter.Feeling {
    var title: LocalizedStringKey {
        switch self {
        case .all: "common.all"
        case .unknown: "feeling.unknown"
        case .good: "feeling.good"
        case .neutral: "feeling.neutral"
        case .bad: "feeling.bad"
        }
    }
}
