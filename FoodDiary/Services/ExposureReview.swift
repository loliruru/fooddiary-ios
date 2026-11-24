import Foundation

enum ExposureReview {
    static let windowHours = 48
    private static let secondsPerHour: TimeInterval = 3_600

    static func windowStart(for symptomTime: Date) -> Date {
        symptomTime.addingTimeInterval(-TimeInterval(windowHours) * secondsPerHour)
    }

    static func contains(_ intakeTime: Date, before symptomTime: Date) -> Bool {
        intakeTime >= windowStart(for: symptomTime) && intakeTime < symptomTime
    }

    static func predicate(before symptomTime: Date) -> Predicate<IntakeEvent> {
        let start = windowStart(for: symptomTime)
        return #Predicate { $0.eventTime >= start && $0.eventTime < symptomTime }
    }

    static func hoursBefore(_ symptomTime: Date, intakeTime: Date) -> Double {
        symptomTime.timeIntervalSince(intakeTime) / secondsPerHour
    }
}
