import PhotosUI
import SwiftData
import SwiftUI

/// Shows one generated workout: why it fits today, its steps, and completion.
struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var workout: GeneratedWorkout
    @State private var selectedPhotos: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(workout.explanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section("Step-by-step guide") {
                    ForEach(workout.steps, id: \.self) { step in
                        WorkoutStepRow(step: step)
                    }
                }
                Section {
                    LabeledContent("Total") {
                        Text("\(workout.durationMinutes) minutes")
                    }
                    LabeledContent("Intensity") {
                        Text(workout.intensity.displayName)
                    }
                    if let completedAt = workout.completedAt {
                        LabeledContent("Completed") {
                            Text(completedAt.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                }
                WorkoutJournalSection(
                    workout: workout,
                    selectedPhotos: $selectedPhotos
                )
                if workout.completedAt == nil {
                    Section("Live tracking") {
                        Label(
                            "For live heart rate and step guidance, start from BodyPilot on Apple Watch.",
                            systemImage: "applewatch"
                        )
                        .font(.subheadline)
                    }
                    Section {
                        Button {
                            workout.completedAt = .now
                            dismiss()
                        } label: {
                            Label("Mark Completed Manually", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                    } header: {
                        Text("Manual completion")
                    }
                }
            }
            .navigationTitle(workout.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct WorkoutJournalSection: View {
    @Bindable var workout: GeneratedWorkout
    @Binding var selectedPhotos: [PhotosPickerItem]

    var body: some View {
        let photoCount = workout.photoIdentifiers.count
        Section("Workout Journal") {
            TextField("Workout name", text: $workout.title)

            VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
                Text("Notes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $workout.journalNote)
                    .frame(minHeight: 90)
                    .accessibilityLabel("Workout notes")
            }

            Picker("Effort (RPE)", selection: $workout.perceivedExertion) {
                Text("Not set").tag(nil as Int?)
                ForEach(1...10, id: \.self) { value in
                    Text("\(value)").tag(Optional(value))
                }
            }

            Toggle("Favorite", isOn: $workout.isFavorite)

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
                workout.photoIdentifiers = items.compactMap(\.itemIdentifier)
            }
        }
    }
}

private struct WorkoutStepRow: View {
    let step: WorkoutStep

    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
            HStack(alignment: .firstTextBaseline) {
                Text(step.name)
                    .font(.body.weight(.medium))
                Spacer()
                Text("\(step.durationMinutes) min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(step.durationMinutes) minutes")
            }
            Text(step.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let coachingCue = step.coachingCue {
                Label(coachingCue, systemImage: "checkmark.seal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, BPSpacing.xSmall)
    }
}

#Preview {
    WorkoutDetailView(
        workout: GeneratedWorkout(
            title: "Walking · 30 min",
            activity: .walking,
            durationMinutes: 30,
            intensity: .moderate,
            explanation: "Built for today's readiness: moderate intensity, within your 30-minute window.",
            steps: [
                WorkoutStep(phase: .warmup, name: "Warm-up", detail: "Easy walking to start.", durationMinutes: 5, intensity: .light),
                WorkoutStep(phase: .main, name: "Brisk pace", detail: "Push to a pace where talking takes a little effort.", durationMinutes: 20, intensity: .moderate),
                WorkoutStep(phase: .cooldown, name: "Cool-down", detail: "Slow down gradually.", durationMinutes: 5, intensity: .light),
            ]
        )
    )
    .modelContainer(for: GeneratedWorkout.self, inMemory: true)
}
