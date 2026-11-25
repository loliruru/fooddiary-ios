import SwiftData
import SwiftUI

struct HistoryView: View {
    private struct DayGroup: Identifiable {
        let date: Date
        let entries: [TimelineEntry]
        var id: Date { date }
    }

    let onRecordAdded: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query private var events: [IntakeEvent]
    @Query private var symptoms: [SymptomEvent]
    @State private var creating: RecordAction?
    @State private var search = ""
    @State private var filter = TimelineFilter()
    @State private var showingFilters = false
    @FocusState private var searchFocused: Bool

    private var days: [DayGroup] {
        let calendar = Calendar.autoupdatingCurrent
        let entries = TimelineEntry.ordered(intakes: events, symptoms: symptoms)
        let matching = filter.apply(to: entries, searching: search, calendar: calendar)
        return Dictionary(grouping: matching) { calendar.startOfDay(for: $0.time) }
            .sorted { $0.key > $1.key }
            .map { DayGroup(date: $0.key, entries: $0.value) }
    }

    var body: some View {
        DiaryPage {
            DiaryPageTitle(title: "tabs.history")
            let layout = typeSize >= .xxxLarge
                ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
            layout { addButtons }
            if events.isEmpty && symptoms.isEmpty {
                DiaryCard {
                    DiaryEmptyState(
                        title: "history.empty.title",
                        message: "history.empty.message",
                        symbol: "calendar"
                    )
                }
            } else {
                searchControls
                let matchingDays = days
                if matchingDays.isEmpty {
                    DiaryCard {
                        DiaryEmptyState(
                            title: "history.noMatches",
                            message: "history.noMatches.message",
                            symbol: "magnifyingglass"
                        )
                    }
                } else {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        ForEach(matchingDays) { day in
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
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showingFilters) {
            HistoryFilters(applied: $filter)
        }
        .sheet(item: $creating) { action in
            if action == .symptom {
                SymptomEditor()
            } else {
                action.editor(onSave: onRecordAdded)
            }
        }
    }

    private var searchControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").accessibilityHidden(true)
                TextField("history.search", text: $search)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .onSubmit { searchFocused = false }
                    .accessibilityIdentifier("history.search")
                if !search.isEmpty {
                    Button {
                        search = ""
                    } label: {
                        Label("history.clearSearch", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("history.clearSearch")
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(DiaryTheme.surface, in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).strokeBorder(DiaryTheme.border).allowsHitTesting(false)
            }
            Button {
                searchFocused = false
                showingFilters = true
            } label: {
                Label(
                    filter == TimelineFilter() ? "history.filters" : "history.filters.active",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
                .frame(minHeight: 44)
            }
            .accessibilityIdentifier("history.filters")
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
