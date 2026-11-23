import SwiftData
import SwiftUI

struct HistoryView: View {
    private struct DayGroup: Identifiable {
        let date: Date
        let events: [IntakeEvent]
        var id: Date { date }
    }

    let onRecordAdded: () -> Void
    @Query(sort: \IntakeEvent.eventTime, order: .reverse) private var events: [IntakeEvent]
    @State private var creating: IntakeType?

    private var days: [DayGroup] {
        let calendar = Calendar.autoupdatingCurrent
        return Dictionary(grouping: events) { calendar.startOfDay(for: $0.eventTime) }
            .sorted { $0.key > $1.key }
            .map { DayGroup(date: $0.key, events: $0.value) }
    }

    var body: some View {
        DiaryPage {
            DiaryPageTitle(title: "tabs.history")
            ViewThatFits {
                HStack(spacing: 10) { addButtons }
                VStack(spacing: 10) { addButtons }
            }
            if events.isEmpty {
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
                            ForEach(day.events) { event in
                                IntakeRow(event: event, onRecordAdded: onRecordAdded)
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $creating) { type in
            IntakeEditor(type: type, onSave: onRecordAdded)
        }
    }

    private var addButtons: some View {
        ForEach([IntakeType.meal, .snack]) { type in
            Button {
                creating = type
            } label: {
                Label(type.addTitle, systemImage: type.symbol)
            }
            .buttonStyle(DiaryButtonStyle(kind: .secondary))
        }
    }
}
