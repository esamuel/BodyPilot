import AppIntents

/// AppEnum conformance for the check-in feeling. Raw values are the persisted
/// contract for saved shortcuts — never rename them, only append new cases,
/// and always add the display entry in the same edit.
extension FeelingLevel: AppEnum {
    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Feeling")
    }

    nonisolated static var caseDisplayRepresentations: [FeelingLevel: DisplayRepresentation] {
        [
            .veryTired: "Very tired",
            .tired: "Tired",
            .normal: "Normal",
            .good: "Good",
            .excellent: "Excellent",
        ]
    }
}
