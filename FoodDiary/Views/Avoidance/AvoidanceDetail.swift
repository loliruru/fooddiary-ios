import SwiftData
import SwiftUI

struct AvoidanceDetail: View {
    @Environment(\.modelContext) private var context
    @Query private var intakes: [IntakeEvent]
    @Query private var symptoms: [SymptomEvent]
    @Query private var links: [SymptomExposureLink]
    @Query private var statuses: [AvoidanceStatus]
    @State private var showError = false

    let target: AvoidanceTarget

    var body: some View {
        let summary = AvoidanceStatistics.summarize(
            intakes: intakes, symptoms: symptoms, links: links, statuses: statuses
        ).first { $0.id == target.id } ?? AvoidanceSummary(target: target)
        DiaryPage {
            DiaryCard {
                VStack(alignment: .leading, spacing: 10) {
                    AvoidanceSummaryText(summary: summary)
                    if !summary.symptoms.isEmpty {
                        SymptomNames(symptoms: summary.symptoms)
                            .font(.subheadline)
                    }
                    Text("avoidance.explanation")
                        .font(.footnote)
                        .foregroundStyle(DiaryTheme.secondaryText)
                }
            }
            DiaryCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("avoidance.manual").font(.headline).accessibilityAddTraits(.isHeader)
                    statusMenu(for: summary)
                }
            }
            LazyVStack(alignment: .leading, spacing: 14) {
                Text("avoidance.originals")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                if summary.intakes.isEmpty {
                    Text("avoidance.noOriginals")
                        .font(.subheadline)
                        .foregroundStyle(DiaryTheme.secondaryText)
                }
                ForEach(summary.intakes) { record in
                    VStack(alignment: .leading, spacing: 6) {
                        IntakeRow(event: record.event, showsDate: true, onRecordAdded: {})
                        ForEach(record.relevantSymptoms) { symptom in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.suspectedBy.contains { $0.id == symptom.id }
                                     ? "exposure.suspected" : "symptom.linkedMeal")
                                    .font(.footnote)
                                    .foregroundStyle(DiaryTheme.secondaryText)
                                SymptomRow(event: symptom, showsDate: true, showsDiarrheaCount: true)
                            }
                            .padding(.leading, 12)
                        }
                    }
                }
            }
        }
        .navigationTitle("avoidance.detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .alert("common.saveError", isPresented: $showError) {
            Button("common.done", role: .cancel) {}
        }
    }

    private func statusMenu(for summary: AvoidanceSummary) -> some View {
        Picker("avoidance.manual", selection: Binding {
            summary.choice
        } set: { choice in
            do {
                try DiaryStore(context: context).saveAvoidanceChoice(choice, for: summary.target)
            } catch {
                showError = true
            }
        }) {
            Text("avoidance.status.none").tag(Optional<AvoidanceChoice>.none)
            ForEach(AvoidanceChoice.allCases) { choice in
                Text(choice.title).tag(Optional(choice))
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(minHeight: 44)
        .accessibilityIdentifier("avoidance.status")
    }
}

struct AvoidanceSummaryText: View {
    @Environment(\.locale) private var locale
    let summary: AvoidanceSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(summary.target.name).font(.headline)
            Text(summary.target.kind.title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(DiaryTheme.accent)
            Text("avoidance.counts \(summary.evidenceCount) \(summary.intakes.count)")
            Text("avoidance.suspicions \(summary.suspectedCount)")
            if let latest = summary.latestEvidence {
                let date = latest.formatted(.dateTime.year().month().day().hour().minute().locale(locale))
                Text("avoidance.latest \(date)")
            }
            if summary.intakes.count < AvoidanceSummary.smallSampleLimit {
                Text("avoidance.smallSample").font(.footnote)
            }
            if let choice = summary.choice {
                Label(choice.title, systemImage: "bookmark").font(.footnote.weight(.medium))
            }
        }
        .font(.subheadline)
    }
}

private extension AvoidanceKind {
    var title: LocalizedStringKey {
        switch self {
        case .food: "avoidance.food"
        case .ingredient: "avoidance.ingredient"
        case .place: "avoidance.place"
        case .brand: "intake.brand"
        }
    }
}

private extension AvoidanceChoice {
    var title: LocalizedStringKey {
        switch self {
        case .watch: "avoidance.status.watch"
        case .avoid: "avoidance.status.avoid"
        case .retried: "avoidance.status.retried"
        case .dismissed: "avoidance.status.dismissed"
        }
    }
}
