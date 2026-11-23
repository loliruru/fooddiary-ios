import SwiftData
import SwiftUI

struct HomeView: View {
    let showSaved: Bool
    let onRecordAdded: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(sort: \IntakeEvent.eventTime, order: .reverse) private var events: [IntakeEvent]
    @Query private var symptoms: [SymptomEvent]
    @State private var selectedAction: RecordAction?
    @State private var today = Date.now

    private var todayEvents: [IntakeEvent] {
        let calendar = Calendar.autoupdatingCurrent
        return events.filter { calendar.isDate($0.eventTime, inSameDayAs: today) }
    }

    private var todayEntries: [TimelineEntry] {
        let calendar = Calendar.autoupdatingCurrent
        return TimelineEntry.ordered(
            intakes: todayEvents,
            symptoms: symptoms.filter { calendar.isDate($0.symptomTime, inSameDayAs: today) }
        )
    }

    var body: some View {
        DiaryPage {
            VStack(alignment: .leading, spacing: 7) {
                Label("app.title", systemImage: "leaf.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DiaryTheme.accent)

                DiaryPageTitle(title: "home.greeting")

                Text(today, format: .dateTime.month().day().weekday(.wide))
                    .font(.subheadline)
                    .foregroundStyle(DiaryTheme.secondaryText)
            }

            todayCard

            if showSaved {
                Label("home.saved", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DiaryTheme.accent)
            }

            VStack(spacing: 10) {
                actionButton(for: .meal, kind: .primary)

                let secondaryLayout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 10))
                    : AnyLayout(HStackLayout(spacing: 10))
                secondaryLayout {
                    actionButton(for: .snack, kind: .secondary)
                    actionButton(for: .symptom, kind: .secondary)
                }
            }
            if !todayEntries.isEmpty {
                LazyVStack(spacing: 10) {
                    ForEach(todayEntries) { entry in
                        entry.row(onRecordAdded: onRecordAdded, showFeelingPrompt: true)
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { today = .now }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            today = .now
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            today = .now
        }
        .sheet(item: $selectedAction) { action in
            action.editor(onSave: onRecordAdded)
        }
    }

    private var todayCard: some View {
        DiaryCard(fill: DiaryTheme.accentSurface) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("home.today")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(todayEvents.count, format: .number)
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                        Text("home.intake.unit")
                            .font(.subheadline)
                    }
                    .foregroundStyle(DiaryTheme.accent)
                    .accessibilityElement(children: .combine)

                    if todayEvents.isEmpty {
                        Text("home.empty.title")
                            .font(.subheadline)
                            .foregroundStyle(DiaryTheme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !typeSize.isAccessibilitySize {
                    ZStack {
                        Circle().fill(DiaryTheme.canvas)
                        Circle().strokeBorder(DiaryTheme.accent.opacity(0.24)).padding(7)
                        Image(systemName: "fork.knife")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(DiaryTheme.accent)
                    }
                    .frame(width: 84, height: 84)
                    .accessibilityHidden(true)
                }
            }
        }
    }

    private func actionButton(for action: RecordAction, kind: DiaryButtonStyle.Kind) -> some View {
        Button {
            selectedAction = action
        } label: {
            Label(action.title, systemImage: action.symbol)
        }
        .buttonStyle(DiaryButtonStyle(kind: kind))
    }
}
