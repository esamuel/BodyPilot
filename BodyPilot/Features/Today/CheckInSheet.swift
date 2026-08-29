import SwiftUI

/// One-tap daily readiness check-in per PRD 7.4.
/// Influences recommendations but never overrides safety logic.
struct CheckInSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var feeling: FeelingLevel = .normal
    @State private var soreness: Set<SorenessArea> = []
    @State private var note = ""

    let onSave: (CheckIn) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("How do you feel?") {
                    Picker("Feeling", selection: $feeling) {
                        ForEach(FeelingLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("Any soreness?") {
                    ForEach(SorenessArea.allCases, id: \.self) { area in
                        Button {
                            if soreness.contains(area) {
                                soreness.remove(area)
                            } else {
                                soreness.insert(area)
                            }
                        } label: {
                            HStack {
                                Text(area.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if soreness.contains(area) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityAddTraits(soreness.contains(area) ? .isSelected : [])
                    }
                }
                Section("Note (optional)") {
                    TextField("Anything worth noting?", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("Daily Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            CheckIn(
                                feeling: feeling,
                                soreness: Array(soreness),
                                note: note.isEmpty ? nil : note
                            )
                        )
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CheckInSheet { _ in }
}
