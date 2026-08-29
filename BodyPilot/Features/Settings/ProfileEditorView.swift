import SwiftUI
import SwiftData

/// Edits the stored profile and coaching preferences from the Me tab.
/// Changes apply to the next readiness refresh and workout generation.
struct ProfileEditorView: View {
    @Query private var profiles: [UserProfile]
    @Query private var coachPreferences: [CoachPreference]

    var body: some View {
        if let profile = profiles.first {
            ProfileEditorForm(profile: profile, coachPreference: coachPreferences.first)
        } else {
            ContentUnavailableView(
                "No Profile Yet",
                systemImage: "person.crop.circle.badge.questionmark",
                description: Text("Complete onboarding first — it creates your profile.")
            )
        }
    }
}

private struct ProfileEditorForm: View {
    @Bindable var profile: UserProfile
    let coachPreference: CoachPreference?

    private static let durationOptions = [15, 20, 30, 45, 60]

    private var durationOptions: [Int] {
        Self.durationOptions.contains(profile.preferredWorkoutMinutes)
            ? Self.durationOptions
            : (Self.durationOptions + [profile.preferredWorkoutMinutes]).sorted()
    }

    var body: some View {
        Form {
            Section("Goal") {
                Picker("Goal", selection: $profile.goal) {
                    ForEach(FitnessGoal.allCases, id: \.self) { goal in
                        Text(goal.displayName).tag(goal)
                    }
                }
            }
            Section("Activity level") {
                Picker("Activity level", selection: $profile.activityFrequency) {
                    ForEach(ActivityFrequency.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
            }
            Section("Activities you enjoy") {
                ForEach(ActivityType.allCases, id: \.self) { activity in
                    toggleRow(
                        title: activity.displayName,
                        isSelected: profile.preferredActivities.contains(activity)
                    ) {
                        toggleActivity(activity)
                    }
                }
            }
            Section("Equipment") {
                ForEach(EquipmentType.allCases, id: \.self) { equipment in
                    toggleRow(
                        title: equipment.displayName,
                        isSelected: profile.equipment.contains(equipment)
                    ) {
                        toggleEquipment(equipment)
                    }
                }
            }
            Section("Preferred workout length") {
                Picker("Minutes", selection: $profile.preferredWorkoutMinutes) {
                    ForEach(durationOptions, id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(minutes)
                    }
                }
            }
            if let coachPreference {
                CoachToneSection(coachPreference: coachPreference)
            }
        }
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggleRow(
        title: LocalizedStringResource,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func toggleActivity(_ activity: ActivityType) {
        if profile.preferredActivities.contains(activity) {
            // Keep at least one activity so recommendations stay meaningful.
            if profile.preferredActivities.count > 1 {
                profile.preferredActivities.removeAll { $0 == activity }
            }
        } else {
            profile.preferredActivities = ActivityType.allCases.filter {
                profile.preferredActivities.contains($0) || $0 == activity
            }
        }
    }

    /// "No equipment" is exclusive: choosing it clears the rest and vice versa.
    private func toggleEquipment(_ equipment: EquipmentType) {
        if equipment == .none {
            profile.equipment = [.none]
            return
        }
        var selection = Set(profile.equipment)
        selection.remove(.none)
        if selection.contains(equipment) {
            selection.remove(equipment)
        } else {
            selection.insert(equipment)
        }
        if selection.isEmpty {
            selection = [.none]
        }
        profile.equipment = EquipmentType.allCases.filter(selection.contains)
    }
}

private struct CoachToneSection: View {
    @Bindable var coachPreference: CoachPreference

    var body: some View {
        Section("Coaching tone") {
            Picker("Tone", selection: $coachPreference.tone) {
                ForEach(CoachTone.allCases, id: \.self) { tone in
                    Text(tone.displayName).tag(tone)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

#Preview {
    NavigationStack {
        ProfileEditorView()
    }
    .modelContainer(for: UserProfile.self, inMemory: true)
}
