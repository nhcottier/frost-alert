import Foundation

enum FrostWidgetRiskLevel: String, Codable, CaseIterable {
    case safe = "Safe"
    case watch = "Watch"
    case frostLikely = "Frost likely"
    case severe = "Severe frost risk"
    case unavailable = "Unavailable"

    var sortOrder: Int {
        switch self {
        case .safe: 0
        case .watch: 1
        case .frostLikely: 2
        case .severe: 3
        case .unavailable: -1
        }
    }
}

struct FrostWidgetLocationSnapshot: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var crop: String
    var risk: FrostWidgetRiskLevel
    var expectedLowCelsius: Double?
    var frostPeriod: String
}

struct FrostWidgetSnapshot: Codable, Equatable {
    var generatedAt: Date
    var coverageEnd: Date
    var highestRisk: FrostWidgetRiskLevel
    var locations: [FrostWidgetLocationSnapshot]

    var isStale: Bool {
        isStale(now: Date())
    }

    func isStale(now: Date) -> Bool {
        now.timeIntervalSince(generatedAt) > 24 * 60 * 60
    }

    static let empty = FrostWidgetSnapshot(
        generatedAt: .distantPast,
        coverageEnd: .distantPast,
        highestRisk: .unavailable,
        locations: []
    )
}

enum FrostWidgetStore {
    static let appGroupIdentifier = "group.com.nickcottier.frostalert"
    static let widgetKind = "FrostAlertWidget"

    private static let snapshotKey = "frostWidgetSnapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func loadSnapshot() -> FrostWidgetSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(FrostWidgetSnapshot.self, from: data)
    }

    static func saveSnapshot(_ snapshot: FrostWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func clearSnapshot() {
        defaults.removeObject(forKey: snapshotKey)
    }
}
