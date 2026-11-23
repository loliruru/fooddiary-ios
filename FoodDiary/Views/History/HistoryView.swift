import SwiftData
import SwiftUI

struct HistoryView: View {
    private struct DayGroup: Identifiable {
        let date: Date
        let entries: [TimelineEntry]
        var id: Date { date }
    }

    let onRecordAdded: () -> Void
    @Query private var events: [IntakeEvent]
    @Query private var symptoms: [SymptomEvent]
    @State private var creating: RecordAction?

    private var days: [DayGroup] {
        let calendar = Calendar.autoupdatingCurrent
        let entries = TimelineEntry.ordered(intakes: events, symptoms: symptoms)
        return Dictionary(grouping: entries) { calendar.startOfDay(for: $0.time) }
            .sorted { $0.key > $1.key }
            .map { DayGroup(date: $0.key, entries: $0.value) }
    }

    var body: some View {
        DiaryPage {
            DiaryPageTitle(title: "tabs.history")
            ViewThatFits {
                HStack(spacing: 10) { addButtons }
                VStack(spacing: 10) { addButtons }
            }
            if events.isEmpty && symptoms.isEmpty {
                DiaryCard {
                    DiaryEmptyState(
                        title: "history.empty.title",
                        message: "history.empty.message",
                        symbol: "calendar"
                    )
                }
            } else {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(days) { day in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(day.date, format: .dateTime.year().month().day().weekday(.abbreviated))
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(day.entries) { entry in
                                entry.row(onRecordAdded: onRecordAdded)
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $creating) { action in
            action.editor(onSave: onRecordAdded)
        }
    }

    private var addButtons: some View {
        ForEach(RecordAction.allCases) { action in
            Button {
                creating = action
            } label: {
                Label(action.title, systemImage: action.symbol)
            }
            .buttonStyle(DiaryButtonStyle(kind: .secondary))
        }
    }
}
