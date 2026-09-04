import SwiftData
import SwiftUI

/// Editable personal details: name, sex, and birth date.
/// Values persist to the on-device profile and never leave the device.
struct PersonalDetailsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    var body: some View {
        List {
            Section {
                LabeledContent("Name") {
                    TextField("Name", text: nameBinding, prompt: Text("Your name"))
                        .multilineTextAlignment(.trailing)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Your name")
                }
                Picker("Sex", selection: sexBinding) {
                    ForEach(BiologicalSexOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                DatePicker(
                    "Birth Date",
                    selection: birthDateBinding,
                    in: earliestBirthDate...latestBirthDate,
                    displayedComponents: .date
                )
                if let age = profiles.first?.age {
                    LabeledContent("Age") {
                        Text("\(age) years")
                    }
                }
            } footer: {
                Text("Your data never leaves your device. BodyPilot stores these details locally and uses them only to personalize guidance, like estimating your heart rate zones. Deleting the app deletes them.")
            }
        }
        .navigationTitle("Personal Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Bindings

    private var nameBinding: Binding<String> {
        Binding {
            profiles.first?.displayName ?? ""
        } set: { newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            update { $0.displayName = trimmed.isEmpty ? nil : newValue }
        }
    }

    private var sexBinding: Binding<BiologicalSexOption> {
        Binding {
            profiles.first?.biologicalSex ?? .notSpecified
        } set: { newValue in
            update { $0.biologicalSex = newValue }
        }
    }

    private var birthDateBinding: Binding<Date> {
        Binding {
            profiles.first?.birthDate ?? defaultBirthDate
        } set: { newValue in
            update { $0.birthDate = newValue }
        }
    }

    private func update(_ change: (UserProfile) -> Void) {
        let profile: UserProfile
        if let existingProfile = profiles.first {
            profile = existingProfile
        } else {
            profile = UserProfile()
            modelContext.insert(profile)
        }
        change(profile)
        try? modelContext.save()
    }

    // MARK: - Date limits

    private var defaultBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -HeartRateZoneEngine.fallbackAge, to: .now) ?? .now
    }

    private var earliestBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -110, to: .now) ?? .distantPast
    }

    private var latestBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -10, to: .now) ?? .now
    }
}

extension BiologicalSexOption {
    var displayName: LocalizedStringResource {
        switch self {
        case .female: "Female"
        case .male: "Male"
        case .notSpecified: "Prefer not to say"
        }
    }
}

#Preview {
    NavigationStack {
        PersonalDetailsView()
    }
    .modelContainer(for: [UserProfile.self], inMemory: true)
}
