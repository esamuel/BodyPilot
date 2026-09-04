import PhotosUI
import SwiftData
import SwiftUI

struct HealthWorkoutJournalView: View {
    let summary: WorkoutSummary
    let existingEntry: WorkoutJournalEntry?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var customName: String
    @State private var note: String
    @State private var perceivedExertion: Int?
    @State private var isFavorite: Bool
    @State private var photoIdentifiers: [String]
    @State private var selectedPhotos: [PhotosPickerItem] = []

    init(summary: WorkoutSummary, existingEntry: WorkoutJournalEntry?) {
        self.summary = summary
        self.existingEntry = existingEntry
        _customName = State(initialValue: existingEntry?.customName ?? "")
        _note = State(initialValue: existingEntry?.note ?? "")
        _perceivedExertion = State(initialValue: existingEntry?.perceivedExertion)
        _isFavorite = State(initialValue: existingEntry?.isFavorite ?? false)
        _photoIdentifiers = State(initialValue: existingEntry?.photoIdentifiers ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    LabeledContent("Activity") {
                        Text(summary.activity?.displayName ?? "Workout")
                    }
                    LabeledContent("Date") {
                        Text(summary.start, format: .dateTime.day().month().year().hour().minute())
                    }
                    LabeledContent("Duration") {
                        Text("\(Int(summary.durationMinutes.rounded())) minutes")
                    }
                }

                Section("Journal") {
                    TextField("Workout name", text: $customName)
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                        .accessibilityLabel("Workout notes")

                    Picker("Effort (RPE)", selection: $perceivedExertion) {
                        Text("Not set").tag(nil as Int?)
                        ForEach(1...10, id: \.self) { value in
                            Text("\(value)").tag(Optional(value))
                        }
                    }

                    Toggle("Favorite", isOn: $isFavorite)

                    let photoCount = photoIdentifiers.count
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 5,
                        matching: .images
                    ) {
                        Label {
                            if photoCount == 0 {
                                Text("Add Photos")
                            } else {
                                Text("\(photoCount) photos selected")
                            }
                        } icon: {
                            Image(systemName: "photo.on.rectangle.angled")
                        }
                    }
                    .onChange(of: selectedPhotos) { _, items in
                        photoIdentifiers = items.compactMap(\.itemIdentifier)
                    }
                }

                if perceivedExertion != nil {
                    Section {
                        Label(
                            "Your effort rating will replace heart-rate load for this workout.",
                            systemImage: "gauge.with.needle"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Workout Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() {
        let trimmedName = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = existingEntry ?? WorkoutJournalEntry(workoutID: summary.id)
        entry.customName = trimmedName.isEmpty ? nil : trimmedName
        entry.note = note
        entry.perceivedExertion = perceivedExertion
        entry.isFavorite = isFavorite
        entry.photoIdentifiers = photoIdentifiers
        entry.updatedAt = .now
        if existingEntry == nil {
            modelContext.insert(entry)
        }
    }
}
