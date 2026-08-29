import Foundation
import SwiftData

/// The user's enrollment in a multi-week personal program (e.g. "Get Active Again").
@Model
final class ProgramEnrollment {
    var programName: String
    var startDate: Date
    var weekCount: Int
    var isActive: Bool

    init(
        programName: String,
        startDate: Date = .now,
        weekCount: Int,
        isActive: Bool = true
    ) {
        self.programName = programName
        self.startDate = startDate
        self.weekCount = weekCount
        self.isActive = isActive
    }
}
