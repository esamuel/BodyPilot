import Foundation
import SwiftData

enum LifeStatusKind: String, Codable, CaseIterable, Sendable {
    case sick
    case injured
    case onBreak
    case vacation
}

/// A user-owned period that pauses training pressure without erasing progress.
@Model
final class LifeStatus {
    @Attribute(.unique) var id: UUID
    var kind: LifeStatusKind
    var startDate: Date
    var endDate: Date?

    init(
        id: UUID = UUID(),
        kind: LifeStatusKind,
        startDate: Date = .now,
        endDate: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.startDate = startDate
        self.endDate = endDate
    }

    func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        let start = calendar.startOfDay(for: startDate)
        let end = endDate.map { calendar.startOfDay(for: $0) }
        return start <= day && end.map { day <= $0 } != false
    }
}

enum LifeStatusResolver {
    static func activeStatus(
        in statuses: [LifeStatus],
        at date: Date,
        calendar: Calendar = .current
    ) -> LifeStatus? {
        statuses
            .filter { $0.isActive(at: date, calendar: calendar) }
            .max { $0.startDate < $1.startDate }
    }
}
