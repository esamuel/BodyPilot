import SwiftUI

struct LifeStatusSheet: View {
    let activeStatus: LifeStatus?
    let onSave: (LifeStatusKind, Date, Date?) -> Void
    let onEnd: (LifeStatus) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedKind: LifeStatusKind = .onBreak
    @State private var startDate = Date.now
    @State private var hasEndDate = false
    @State private var endDate = Date.now

    var body: some View {
        NavigationStack {
            Form {
                if let activeStatus {
                    ActiveLifeStatusSection(
                        kind: activeStatus.kind,
                        startDate: activeStatus.startDate,
                        onEnd: {
                            onEnd(activeStatus)
                            dismiss()
                        }
                    )
                }

                Section("New Life Status") {
                    Picker("Status", selection: $selectedKind) {
                        ForEach(LifeStatusKind.allCases, id: \.self) { kind in
                            Label {
                                Text(kind.displayName)
                            } icon: {
                                Image(systemName: kind.systemImage)
                            }
                            .tag(kind)
                        }
                    }
                    DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                    Toggle("Set an end date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker(
                            "Ends",
                            selection: $endDate,
                            in: startDate...,
                            displayedComponents: .date
                        )
                    }
                }
            }
            .navigationTitle("Life Status")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selectedKind, startDate, hasEndDate ? endDate : nil)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ActiveLifeStatusSection: View {
    let kind: LifeStatusKind
    let startDate: Date
    let onEnd: () -> Void

    var body: some View {
        Section("Active") {
            Label {
                VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
                    Text(kind.displayName)
                    Text(startDate, format: .dateTime.day().month().year())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: kind.systemImage)
            }
            Button("End Life Status", role: .destructive, action: onEnd)
        }
    }
}
