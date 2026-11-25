import Foundation

extension DiaryBackup {
    func csv(in timeZone: TimeZone = .current) throws -> Data {
        let columns = [
            "recordType", "id", "intakeID", "symptomID", "comboID", "linkedMealID", "position",
            "name", "intakeType", "mealType", "merchantName", "brandName", "purchasePlaceName", "amountText",
            "category", "note", "tags", "symptoms", "diarrheaCount", "feeling", "severity", "duration",
            "judgment", "targetKind", "manualChoice", "eventTime", "symptomTime", "recordedAt",
            "createdAt", "updatedAt", "lastUsedAt"
        ]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = timeZone
        let encoder = JSONEncoder()
        var output = "\u{FEFF}" + columns.joined(separator: ",") + "\r\n"

        func date(_ value: Date?) -> String? { value.map(formatter.string(from:)) }

        func list(_ values: [String]) throws -> String {
            String(decoding: try encoder.encode(values), as: UTF8.self)
        }

        func append(_ type: String, id: UUID? = nil, _ fields: [String: String?]) {
            let values = [type, id?.uuidString ?? ""] + columns.dropFirst(2).map { fields[$0].flatMap { $0 } ?? "" }
            output += values.map(Self.csvField).joined(separator: ",") + "\r\n"
        }

        for item in intakes {
            append("intake", id: item.id, [
                "name": item.displayName, "intakeType": item.intakeType, "mealType": item.mealType,
                "merchantName": item.merchantName, "brandName": item.brandName, "amountText": item.amountText,
                "note": item.note, "tags": try list(item.tags), "eventTime": date(item.eventTime),
                "createdAt": date(item.createdAt), "updatedAt": date(item.updatedAt)
            ])
            for (position, row) in item.ingredients.enumerated() {
                append("ingredient", id: row.id, [
                    "intakeID": item.id.uuidString, "position": String(position), "name": row.name,
                    "purchasePlaceName": row.purchasePlaceName, "amountText": row.amountText, "note": row.note
                ])
            }
        }
        for item in symptoms {
            append("symptom", id: item.id, [
                "linkedMealID": item.linkedMealID?.uuidString, "symptoms": try list(item.symptoms),
                "diarrheaCount": String(item.diarrheaCount), "feeling": item.feeling, "severity": item.severity,
                "duration": item.duration, "note": item.note, "symptomTime": date(item.symptomTime),
                "recordedAt": date(item.recordedAt)
            ])
        }
        for item in exposureLinks {
            append("exposure", id: item.id, [
                "intakeID": item.intakeID.uuidString, "symptomID": item.symptomID.uuidString,
                "judgment": item.judgment, "note": item.note, "updatedAt": date(item.updatedAt)
            ])
        }
        for item in savedPlaces {
            append("savedPlace", id: item.id, [
                "name": item.name, "category": item.category, "note": item.note,
                "createdAt": date(item.createdAt), "lastUsedAt": date(item.lastUsedAt)
            ])
        }
        for item in savedFoods {
            append("savedFood", id: item.id, [
                "name": item.name, "category": item.category,
                "createdAt": date(item.createdAt), "lastUsedAt": date(item.lastUsedAt)
            ])
        }
        for item in mealCombos {
            append("mealCombo", id: item.id, [
                "name": item.name, "createdAt": date(item.createdAt), "updatedAt": date(item.updatedAt)
            ])
            for (position, row) in item.ingredients.enumerated() {
                append("comboIngredient", [
                    "comboID": item.id.uuidString, "position": String(position), "name": row.name,
                    "purchasePlaceName": row.purchasePlaceName, "amountText": row.amountText, "note": row.note
                ])
            }
        }
        for item in avoidanceStatuses {
            append("avoidanceStatus", id: item.id, [
                "name": item.displayName, "targetKind": item.kind, "manualChoice": item.choice,
                "updatedAt": date(item.updatedAt)
            ])
        }
        return Data(output.utf8)
    }

    static func csvField(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
