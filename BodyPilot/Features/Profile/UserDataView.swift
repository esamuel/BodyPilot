import PhotosUI
import SwiftData
import SwiftUI

/// Profile sheet opened from the person icon on Path.
/// Shows who the user is, their life status, and entry points
/// to personal details, heart rate zones, and settings.
struct UserDataView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \LifeStatus.startDate, order: .reverse) private var lifeStatuses: [LifeStatus]

    @State private var subscription = SubscriptionService()
    @State private var isLifeStatusPresented = false
    @State private var selectedPhoto: PhotosPickerItem?

    let onSaveLifeStatus: (LifeStatusKind, Date, Date?) -> Void
    let onEndLifeStatus: (LifeStatus) -> Void

    private var profile: UserProfile? {
        profiles.first
    }

    private var activeLifeStatus: LifeStatus? {
        LifeStatusResolver.activeStatus(in: lifeStatuses, at: .now)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: BPSpacing.small) {
                        ProfileHeader(
                            name: profile?.displayName,
                            avatarData: profile?.avatarImageData,
                            hasPro: subscription.hasPro
                        )
                        photoControls
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    Button {
                        isLifeStatusPresented = true
                    } label: {
                        lifeStatusRow
                    }
                }

                Section {
                    NavigationLink {
                        PersonalDetailsView()
                    } label: {
                        Label("Personal Details", systemImage: "person.text.rectangle")
                    }
                    NavigationLink {
                        HeartRateZonesView()
                    } label: {
                        Label("Heart Rate Zones", systemImage: "heart.fill")
                    }
                } header: {
                    Text("Personalize")
                } footer: {
                    Text("Your details stay on this device and are used only to personalize your guidance.")
                }

                Section {
                    NavigationLink {
                        SettingsListView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isLifeStatusPresented) {
                LifeStatusSheet(
                    activeStatus: activeLifeStatus,
                    onSave: onSaveLifeStatus,
                    onEnd: onEndLifeStatus
                )
            }
            .task {
                await subscription.refreshEntitlement()
            }
            .onChange(of: selectedPhoto) { _, newItem in
                guard let newItem else { return }
                Task {
                    await saveAvatar(from: newItem)
                }
            }
        }
    }

    private var photoControls: some View {
        HStack(spacing: BPSpacing.medium) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Text(profile?.avatarImageData == nil ? "Add Photo" : "Edit Photo")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BodyPilotColors.accentOrange)
            }
            if profile?.avatarImageData != nil {
                Button("Remove Photo", role: .destructive) {
                    updateProfile { $0.avatarImageData = nil }
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .buttonStyle(.borderless)
    }

    private var lifeStatusRow: some View {
        HStack(spacing: BPSpacing.small) {
            Label {
                Text("Life Status")
                    .foregroundStyle(BodyPilotColors.primaryText)
            } icon: {
                Image(systemName: activeLifeStatus?.kind.systemImage ?? "figure.walk")
                    .foregroundStyle(BodyPilotColors.accentOrange)
            }
            Spacer()
            Circle()
                .fill(activeLifeStatus == nil ? BodyPilotColors.successGreen : BodyPilotColors.warningOrange)
                .frame(width: 9, height: 9)
                .accessibilityHidden(true)
            if let kind = activeLifeStatus?.kind {
                Text(kind.displayName)
                    .fontWeight(.semibold)
                    .foregroundStyle(BodyPilotColors.primaryText)
            } else {
                Text("Active")
                    .fontWeight(.semibold)
                    .foregroundStyle(BodyPilotColors.primaryText)
            }
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Avatar persistence

    private func saveAvatar(from item: PhotosPickerItem) async {
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let processed = Self.processedAvatarData(from: data)
        else {
            selectedPhoto = nil
            return
        }
        updateProfile { $0.avatarImageData = processed }
        selectedPhoto = nil
    }

    private func updateProfile(_ change: (UserProfile) -> Void) {
        let target: UserProfile
        if let profile {
            target = profile
        } else {
            target = UserProfile()
            modelContext.insert(target)
        }
        change(target)
        try? modelContext.save()
    }

    /// Downscales the picked image to at most 512pt per side and re-encodes as
    /// JPEG so the profile store never holds a full-resolution photo.
    private static func processedAvatarData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxSide: CGFloat = 512
        let scale = min(maxSide / image.size.width, maxSide / image.size.height, 1)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }
}

/// Large centered avatar, name, and membership badge.
private struct ProfileHeader: View {
    let name: String?
    let avatarData: Data?
    let hasPro: Bool

    var body: some View {
        VStack(spacing: BPSpacing.small) {
            avatar
                .frame(width: 104, height: 104)
                .accessibilityHidden(true)

            Text(name?.isEmpty == false ? name ?? "" : String(localized: "Your Profile"))
                .font(.title.bold())
                .foregroundStyle(BodyPilotColors.primaryText)

            Text(hasPro ? "Premium Member" : "Free Plan")
                .font(.footnote.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(hasPro ? BodyPilotColors.accentOrange : BodyPilotColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, BPSpacing.medium)
    }

    @ViewBuilder
    private var avatar: some View {
        if let avatarData, let image = UIImage(data: avatarData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 104, height: 104)
                .clipShape(.circle)
        } else {
            ZStack {
                Circle()
                    .fill(BodyPilotColors.accentOrange.opacity(0.14))
                if let initial = name?.trimmingCharacters(in: .whitespaces).first {
                    Text(String(initial))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(BodyPilotColors.accentOrange)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(BodyPilotColors.accentOrange)
                }
            }
        }
    }
}

#Preview {
    UserDataView(
        onSaveLifeStatus: { _, _, _ in },
        onEndLifeStatus: { _ in }
    )
    .modelContainer(
        for: [UserProfile.self, LifeStatus.self],
        inMemory: true
    )
}
