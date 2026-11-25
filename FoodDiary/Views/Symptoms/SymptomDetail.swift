import SwiftData
import SwiftUI

struct SymptomRow: View {
    let event: SymptomEvent
    var showsDate = false
    var showsDiarrheaCount = false

    var body: some View {
        NavigationLink {
            SymptomDetail(event: event)
        } label: {
            DiaryCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "heart.text.square")
                        .font(.headline)
                        .foregroundStyle(DiaryTheme.observation)
                        .frame(width: 38, height: 38)
                        .background(DiaryTheme.observationSurface, in: .rect(cornerRadius: 10))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("symptom.detail").font(.headline)
                        Text(event.feeling?.title ?? "feeling.unknown")
                            .font(.footnote)
                            .foregroundStyle(DiaryTheme.secondaryText)
                        if !event.symptoms.isEmpty {
                            SymptomNames(symptoms: event.symptoms)
                                .font(.subheadline)
                        }
                        if showsDiarrheaCount && event.symptoms.contains(.diarrhea) {
                            Text("avoidance.diarrhea \(event.diarrheaCount)")
                                .font(.footnote)
                                .foregroundStyle(DiaryTheme.secondaryText)
                        }
                        Text(event.symptomTime, format: showsDate ? .dateTime.year().month().day().hour().minute() : .dateTime.hour().minute())
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
        .accessibilityIdentifier("symptom.record")
    }
}

struct SymptomDetail: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var showError = false

    let event: SymptomEvent
    var onDelete: (() -> Void)?

    @ViewBuilder
    var body: some View {
        if event.modelContext != nil && !event.isDeleted {
            detail
        }
    }

    private var detail: some View {
        DiaryPage {
            DiaryCard {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("symptom.started") {
                        Text(event.symptomTime, format: .dateTime.year().month().day().hour().minute())
                    }
                    LabeledContent("symptom.recorded") {
                        Text(event.recordedAt, format: .dateTime.year().month().day().hour().minute())
                    }
                    LabeledContent("feeling.title") {
                        Text(event.feeling?.title ?? "feeling.unknown")
                    }
                    if !event.symptoms.isEmpty {
                        LabeledContent("symptom.list") {
                            SymptomNames(symptoms: event.symptoms)
                        }
                    }
                    if event.symptoms.contains(.diarrhea) {
                        LabeledContent("symptom.diarrheaCount") {
                            Text(event.diarrheaCount, format: .number)
                        }
                    }
                    if let severity = event.severity {
                        LabeledContent("symptom.severity") { Text(severity.title) }
                    }
                    if let duration = event.duration {
                        LabeledContent("symptom.duration") { Text(duration.title) }
                    }
                }
            }
            if let meal = event.linkedMeal {
                DiaryCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("symptom.linkedMeal", systemImage: "link").font(.headline)
                        Text(meal.displayName)
                        Text(meal.eventTime, format: .dateTime.year().month().day().hour().minute())
                            .font(.footnote)
                            .foregroundStyle(DiaryTheme.secondaryText)
                    }
                }
            }
            if let note = event.note {
                DiaryCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("intake.note").font(.headline)
                        Text(note)
                    }
                }
            }
            Button("symptom.delete", role: .destructive) { confirmDelete = true }
                .frame(maxWidth: .infinity, minHeight: 44)
            ExposureCandidates(symptom: event)
                .id(event.symptomTime)
        }
        .navigationTitle("symptom.detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("common.edit") { editing = true }
            }
        }
        .sheet(isPresented: $editing) {
            SymptomEditor(event: event)
        }
        .confirmationDialog("symptom.confirmDelete", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("common.delete", role: .destructive, action: delete)
            Button("common.cancel", role: .cancel) {}
        }
        .alert("common.deleteError", isPresented: $showError) {
            Button("common.done", role: .cancel) {}
        }
    }

    private func delete() {
        do {
            try DiaryStore(context: context).deleteSymptom(event)
            if let onDelete {
                onDelete()
            } else {
                dismiss()
            }
        } catch {
            showError = true
        }
    }
}

struct SymptomNames: View {
    let symptoms: [Symptom]

    var body: some View {
        Text(symptoms.map { String(localized: $0.title) }.joined(separator: "、"))
    }
}
