import Foundation

struct DiaryExportFile: Sendable {
    enum Format: String, Sendable {
        case csv, json
    }

    private static let root = URL.temporaryDirectory.appending(path: "FoodDiaryExports", directoryHint: .isDirectory)
    private let directory: URL
    let url: URL

    init(backup: DiaryBackup, format: Format, timeZone: TimeZone) throws {
        let data = switch format {
        case .csv: try backup.csv(in: timeZone)
        case .json: try backup.json()
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let stamp = formatter.string(from: backup.exportedAt)
        directory = Self.root.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        url = directory.appending(path: "FoodDiary-\(stamp).\(format.rawValue)")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            remove()
            throw error
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }

    static func removePreviousExports() {
        try? FileManager.default.removeItem(at: root)
    }
}
