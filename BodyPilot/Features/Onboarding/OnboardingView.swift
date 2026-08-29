import SwiftUI
import SwiftData
import StoreKit
import UIKit

/// Premium, state-driven onboarding that persists into the existing profile model.
struct OnboardingView: View {
    private enum Step: Int, CaseIterable {
        case name
        case welcome
        case meetBodyPilot
        case goals
        case healthAccess
        case appleWatch
        case notifications
        case coach
        case ready
        case premium
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var step: Step = .name
    @State private var name = ""
    @State private var selectedGoals: Set<OnboardingGoal> = []
    @State private var healthAccess = HealthAccessModel()
    @State private var notifications = NotificationService()
    @State private var store = SubscriptionService()
    @State private var isWorking = false
    @State private var showsMorePlans = false
    @State private var legalDocument: LegalDocument?
    @State private var didLoadProfile = false
    @FocusState private var isNameFocused: Bool

    private let onComplete: () -> Void

    init(onComplete: @escaping () -> Void = {}) {
        self.onComplete = onComplete
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var featuredProduct: Product? {
        store.products.first { $0.id.localizedCaseInsensitiveContains("year") }
            ?? store.products.first
    }

    var body: some View {
        ZStack {
            if step == .welcome {
                fullBleedWelcomeScreen
                    .transition(pageTransition)
            } else if step == .name {
                fullBleedNameScreen
                    .transition(pageTransition)
            } else {
                standardOnboardingFlow
                    .transition(pageTransition)
            }
        }
        .tint(BodyPilotColors.accentOrange)
        .interactiveDismissDisabled()
        .task(id: step) {
            loadExistingProfileOnce()
            if step == .healthAccess {
                await healthAccess.refresh()
            } else if step == .premium && store.products.isEmpty {
                await store.load()
            }
        }
        .sheet(item: $legalDocument) { document in
            OnboardingLegalView(document: document)
        }
    }

    private var standardOnboardingFlow: some View {
        ZStack {
            BodyPilotColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                OnboardingProgressView(
                    value: Double(step.rawValue + 1),
                    total: Double(Step.allCases.count),
                    showsBackButton: true,
                    backAction: goBack
                )

                ScrollView {
                    stepContent
                        .id(step)
                        .transition(pageTransition)
                        .padding(.horizontal, BPSpacing.large)
                        .padding(.vertical, BPSpacing.medium)
                }
                .scrollDismissesKeyboard(.interactively)

                controls
                    .padding(.horizontal, BPSpacing.large)
                    .padding(.top, BPSpacing.small)
                    .padding(.bottom, BPSpacing.medium)
                    .background(.ultraThinMaterial)
            }
        }
    }

    private var fullBleedWelcomeScreen: some View {
        ZStack {
            FullBleedOnboardingArtwork(
                assetName: BodyPilotAsset.onboardingWelcome,
                fallbackSystemImage: "figure.walk.motion"
            )

            VStack(alignment: .leading, spacing: BPSpacing.medium) {
                Button(action: goBack) {
                    Image(systemName: "chevron.backward")
                        .font(.headline)
                        .foregroundStyle(BodyPilotColors.primaryText)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: .circle)
                }
                .accessibilityLabel("Back to edit name")

                Text(welcomeTitle)
                    .font(.largeTitle.bold())
                    .foregroundStyle(BodyPilotColors.primaryText)
                    .multilineTextAlignment(.leading)
                    .accessibilityAddTraits(.isHeader)

                Text("I’m BodyPilot — your daily guide to movement, recovery and wellbeing.")
                    .font(.title3)
                    .foregroundStyle(BodyPilotColors.secondaryText)
                    .lineSpacing(3)

                Spacer(minLength: BPSpacing.large)

                Button(action: advance) {
                    Text("Go for it")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(.black, in: .capsule)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, BPSpacing.xLarge)
            .padding(.top, 54)
            .padding(.bottom, BPSpacing.large)
        }
        .ignoresSafeArea(edges: .top)
    }

    private var welcomeTitle: String {
        if trimmedName.isEmpty {
            return "Let’s get to know each other!"
        }
        return "Let’s get to know each other, \(trimmedName)!"
    }

    private var fullBleedNameScreen: some View {
        ZStack {
            FullBleedOnboardingArtwork(
                assetName: BodyPilotAsset.onboardingName,
                fallbackSystemImage: "person.crop.circle.fill"
            )

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: BPSpacing.medium) {
                        Text("First, let’s make this personal.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BodyPilotColors.secondaryText)

                        Text("What should I call you?")
                            .font(.largeTitle.bold())
                            .foregroundStyle(BodyPilotColors.primaryText)
                            .accessibilityAddTraits(.isHeader)

                        Text("I’ll use your name to personalize your daily guidance and encouragement.")
                            .font(.title3)
                            .foregroundStyle(BodyPilotColors.secondaryText)
                            .lineSpacing(3)

                        VStack(alignment: .leading, spacing: BPSpacing.small) {
                            Text("Your name")
                                .font(.headline)
                            TextField("Your name", text: $name)
                                .textContentType(.name)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .submitLabel(.continue)
                                .focused($isNameFocused)
                                .onSubmit(continueFromName)
                                .font(.title3)
                                .padding(BPSpacing.medium)
                                .background(.white.opacity(0.16), in: .rect(cornerRadius: BPCornerRadius.control))
                                .overlay {
                                    RoundedRectangle(cornerRadius: BPCornerRadius.control)
                                        .stroke(.black.opacity(0.2), lineWidth: 1)
                                }
                            Text("You can change this later.")
                                .font(.footnote)
                                .foregroundStyle(BodyPilotColors.secondaryText)
                        }
                        .padding(.vertical, BPSpacing.small)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, BPSpacing.large)
                    .padding(.top, 76)
                }
                .scrollDismissesKeyboard(.interactively)

                Button(action: continueFromName) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(.black, in: .capsule)
                }
                .buttonStyle(.plain)
                .disabled(trimmedName.isEmpty)
                .opacity(trimmedName.isEmpty ? 0.5 : 1)
                .padding(.horizontal, BPSpacing.xLarge)
                .padding(.top, BPSpacing.small)
                .padding(.bottom, BPSpacing.medium)
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            isNameFocused = name.isEmpty
        }
    }

    private var pageTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            welcomeScreen
        case .meetBodyPilot:
            meetScreen
        case .name:
            nameScreen
        case .goals:
            goalsScreen
        case .healthAccess:
            healthScreen
        case .appleWatch:
            watchScreen
        case .notifications:
            notificationsScreen
        case .coach:
            coachScreen
        case .ready:
            readyScreen
        case .premium:
            premiumScreen
        }
    }

    private var welcomeScreen: some View {
        OnboardingPage(
            artwork: BodyPilotAsset.onboardingWelcome,
            fallbackSystemImage: "figure.walk.motion",
            title: "Let’s get to know each other!",
            message: "I’m BodyPilot — your daily guide to movement, recovery and wellbeing."
        )
    }

    private var meetScreen: some View {
        VStack(spacing: BPSpacing.large) {
            OnboardingPage(
                artwork: BodyPilotAsset.onboardingMeet,
                fallbackSystemImage: "heart.text.square.fill",
                title: "Meet BodyPilot.",
                message: "Your personal guide for movement, recovery and everyday wellbeing."
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92))], spacing: BPSpacing.small) {
                FeaturePill(title: "Sleep", systemImage: "moon.zzz.fill")
                FeaturePill(title: "Steps", systemImage: "figure.walk")
                FeaturePill(title: "Heart", systemImage: "heart.fill")
                FeaturePill(title: "Workouts", systemImage: "figure.run")
                FeaturePill(title: "Recovery", systemImage: "waveform.path.ecg")
            }
        }
    }

    private var nameScreen: some View {
        VStack(alignment: .leading, spacing: BPSpacing.large) {
            OnboardingPage(
                artwork: BodyPilotAsset.onboardingName,
                fallbackSystemImage: "person.crop.circle.fill",
                kicker: "First, let’s make this personal.",
                title: "What should I call you?",
                message: "I’ll use your name to personalize your daily guidance and encouragement.",
                alignment: .leading
            )

            VStack(alignment: .leading, spacing: BPSpacing.small) {
                Text("Your name")
                    .font(.headline)
                TextField("Your name", text: $name)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.continue)
                    .focused($isNameFocused)
                    .onSubmit(continueFromName)
                    .font(.title3)
                    .padding(BPSpacing.medium)
                    .background(BodyPilotColors.card, in: .rect(cornerRadius: BPCornerRadius.control))
                    .overlay {
                        RoundedRectangle(cornerRadius: BPCornerRadius.control)
                            .stroke(BodyPilotColors.sleepLavender, lineWidth: 1)
                    }
                Text("You can change this later.")
                    .font(.footnote)
                    .foregroundStyle(BodyPilotColors.secondaryText)
            }
        }
        .onAppear {
            isNameFocused = name.isEmpty
        }
    }

    private var goalsScreen: some View {
        VStack(alignment: .leading, spacing: BPSpacing.large) {
            OnboardingPage(
                artwork: BodyPilotAsset.onboardingLearn,
                fallbackSystemImage: "sparkles",
                kicker: "Now for the important part.",
                title: "Let’s learn about you.",
                message: "Tell me your goals, routine and pace so I can guide you better.",
                alignment: .leading
            )

            VStack(spacing: BPSpacing.small) {
                ForEach(OnboardingGoal.allCases, id: \.self) { goal in
                    GoalSelectionCard(
                        goal: goal,
                        isSelected: selectedGoals.contains(goal)
                    ) {
                        toggleGoal(goal)
                    }
                }
            }
        }
    }

    private var healthScreen: some View {
        VStack(alignment: .leading, spacing: BPSpacing.large) {
            OnboardingPage(
                artwork: BodyPilotAsset.onboardingHealth,
                fallbackSystemImage: "heart.text.square.fill",
                title: "Connect Apple Health",
                message: "With your permission, BodyPilot can read the signals it needs to build more accurate guidance.",
                alignment: .leading
            )

            VStack(spacing: BPSpacing.small) {
                HealthCategoryRow(title: "Sleep", systemImage: "moon.zzz.fill")
                HealthCategoryRow(title: "Steps", systemImage: "figure.walk")
                HealthCategoryRow(title: "Heart Rate", systemImage: "heart.fill")
                HealthCategoryRow(title: "Workouts", systemImage: "figure.run")
            }

            healthStatus

            Button("Why we ask", systemImage: "info.circle") {
                legalDocument = .health
            }
            .frame(minHeight: 44)
        }
    }

    @ViewBuilder
    private var healthStatus: some View {
        switch healthAccess.state {
        case .checking:
            Label("Checking Apple Health…", systemImage: "ellipsis.circle")
                .foregroundStyle(BodyPilotColors.secondaryText)
        case .connected:
            Label("Apple Health is connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(BodyPilotColors.successGreen)
        case .needsRequest:
            Label("You’ll choose what BodyPilot can read on the next screen.", systemImage: "hand.raised.fill")
                .foregroundStyle(BodyPilotColors.secondaryText)
        case .unavailable:
            Label("Apple Health isn’t available on this device. You can still continue.", systemImage: "exclamationmark.circle")
                .foregroundStyle(BodyPilotColors.secondaryText)
        case .failed:
            Label("Apple Health couldn’t be connected. You can try again later.", systemImage: "exclamationmark.circle")
                .foregroundStyle(BodyPilotColors.secondaryText)
        }
    }

    private var watchScreen: some View {
        OnboardingPage(
            artwork: BodyPilotAsset.onboardingWatch,
            fallbackSystemImage: "applewatch",
            title: "Works beautifully with Apple Watch.",
            message: "BodyPilot uses your watch activity, heart and workout signals to understand your day."
        )
    }

    private var notificationsScreen: some View {
        OnboardingPage(
            artwork: BodyPilotAsset.onboardingReminders,
            fallbackSystemImage: "bell.badge.fill",
            title: "Keep your momentum.",
            message: "Helpful reminders keep your routine alive — and nudge you when your body is ready."
        )
    }

    private var coachScreen: some View {
        VStack(spacing: BPSpacing.large) {
            OnboardingPage(
                artwork: BodyPilotAsset.onboardingCoach,
                fallbackSystemImage: "bubble.left.and.text.bubble.right.fill",
                title: "Ask BodyPilot anything.",
                message: "Get simple coaching based on how you feel, your activity and your recovery."
            )

            VStack(spacing: BPSpacing.small) {
                ConversationBubble(
                    text: "Create me a 10-minute workout.",
                    isUser: true
                )
                ConversationBubble(
                    text: "You’re good for a short walk or gentle mobility session today.",
                    isUser: false
                )
            }
        }
    }

    private var readyScreen: some View {
        VStack(alignment: .leading, spacing: BPSpacing.large) {
            OnboardingPage(
                artwork: BodyPilotAsset.onboardingReady,
                fallbackSystemImage: "checkmark.seal.fill",
                title: "Your BodyPilot is ready, \(trimmedName).",
                message: "I’ve prepared your daily guidance and I’m ready to help you move, recover and feel better.",
                alignment: .leading
            )

            VStack(spacing: BPSpacing.small) {
                ReadyChecklistRow(title: "Understanding your activity patterns")
                ReadyChecklistRow(title: "Reviewing sleep and recovery")
                ReadyChecklistRow(title: "Preparing today’s recommendations")
            }
        }
    }

    private var premiumScreen: some View {
        VStack(alignment: .leading, spacing: BPSpacing.large) {
            OnboardingArtwork(
                assetName: BodyPilotAsset.onboardingPremium,
                fallbackSystemImage: "crown.fill"
            )

            VStack(alignment: .leading, spacing: BPSpacing.small) {
                Text("BodyPilot Premium")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BodyPilotColors.accentOrange)
                Text("Just for you, \(trimmedName)")
                    .font(.largeTitle.bold())
                    .foregroundStyle(BodyPilotColors.primaryText)
                if let savings = annualSavingsText {
                    Text(savings)
                        .font(.headline)
                        .foregroundStyle(BodyPilotColors.accentOrange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(BodyPilotColors.warmGlow, in: .capsule)
                }
                Text("Unlock the full power of BodyPilot guidance.")
                    .font(.title3)
                    .foregroundStyle(BodyPilotColors.secondaryText)
            }

            VStack(spacing: BPSpacing.medium) {
                PremiumBenefit(
                    title: "Move consistently, not constantly",
                    message: "Smart, adaptive recommendations that adjust to your energy, schedule, and goals.",
                    systemImage: "figure.walk.motion"
                )
                PremiumBenefit(
                    title: "Track sleep, health & activity in one place",
                    message: "Heart rate, steps, sleep, workouts and more — all synced and simple to understand.",
                    systemImage: "heart.text.square.fill"
                )
                PremiumBenefit(
                    title: "Personalized recovery and readiness insights",
                    message: "Know when to push, when to rest, and how to build long-term strength and balance.",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
            }

            if showsMorePlans {
                VStack(spacing: BPSpacing.small) {
                    ForEach(store.products, id: \.id) { product in
                        Button {
                            purchase(product)
                        } label: {
                            HStack {
                                Text(product.displayName)
                                Spacer()
                                Text(product.displayPrice)
                                    .foregroundStyle(BodyPilotColors.secondaryText)
                            }
                            .padding(BPSpacing.medium)
                            .background(BodyPilotColors.card, in: .rect(cornerRadius: BPCornerRadius.control))
                        }
                        .buttonStyle(.plain)
                        .disabled(isWorking)
                    }
                }
            }

            HStack {
                Button("Restore Purchases") {
                    restorePurchases()
                }
                Spacer()
                Button("Terms") {
                    legalDocument = .terms
                }
                Button("Privacy") {
                    legalDocument = .privacy
                }
            }
            .font(.footnote)
            .buttonStyle(.plain)
            .foregroundStyle(BodyPilotColors.secondaryText)
        }
    }

    private var annualSavingsText: String? {
        guard
            let yearly = store.products.first(where: { $0.id.localizedCaseInsensitiveContains("year") }),
            let monthly = store.products.first(where: { $0.id.localizedCaseInsensitiveContains("month") })
        else {
            return nil
        }
        let annualMonthlyPrice = monthly.price * Decimal(12)
        guard annualMonthlyPrice > 0, yearly.price < annualMonthlyPrice else {
            return nil
        }
        let yearlyValue = NSDecimalNumber(decimal: yearly.price).doubleValue
        let monthlyValue = NSDecimalNumber(decimal: annualMonthlyPrice).doubleValue
        let savings = Int(((1 - yearlyValue / monthlyValue) * 100).rounded())
        return "Save \(savings)% with the yearly plan"
    }

    @ViewBuilder
    private var controls: some View {
        switch step {
        case .welcome:
            OnboardingPrimaryButton(title: "Go for it", action: advance)
        case .meetBodyPilot:
            OnboardingPrimaryButton(title: "Next", action: advance)
        case .name:
            OnboardingPrimaryButton(
                title: "Continue",
                isDisabled: trimmedName.isEmpty,
                action: continueFromName
            )
        case .goals:
            OnboardingPrimaryButton(
                title: "This is me",
                isDisabled: selectedGoals.isEmpty
            ) {
                saveDraft()
                advance()
            }
        case .healthAccess:
            OnboardingPrimaryButton(title: "Continue", isLoading: isWorking) {
                connectHealthAndContinue()
            }
        case .appleWatch:
            OnboardingPrimaryButton(title: "Great", action: advance)
        case .notifications:
            VStack(spacing: BPSpacing.small) {
                OnboardingPrimaryButton(title: "Turn on reminders", isLoading: isWorking) {
                    enableNotificationsAndContinue()
                }
                Button("Not now", action: advance)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        case .coach:
            OnboardingPrimaryButton(title: "Try Coach", action: advance)
        case .ready:
            OnboardingPrimaryButton(title: "Take Me In", action: advance)
        case .premium:
            VStack(spacing: BPSpacing.small) {
                if store.isLoading {
                    OnboardingPrimaryButton(title: "Loading plans…", isLoading: true, action: {})
                } else if let product = featuredProduct {
                    OnboardingPrimaryButton(
                        title: "Start Today — \(product.displayPrice)",
                        isLoading: isWorking
                    ) {
                        purchase(product)
                    }
                    Button("More options") {
                        withAnimation(reduceMotion ? nil : .smooth) {
                            showsMorePlans.toggle()
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    Button("Continue without Premium", action: finish)
                        .font(.footnote)
                        .foregroundStyle(BodyPilotColors.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    OnboardingPrimaryButton(title: "Continue with BodyPilot", action: finish)
                    Text("Subscriptions aren’t available yet. You can continue using BodyPilot.")
                        .font(.caption)
                        .foregroundStyle(BodyPilotColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func continueFromName() {
        guard !trimmedName.isEmpty else { return }
        name = trimmedName
        isNameFocused = false
        saveDraft()
        advance()
    }

    private func toggleGoal(_ goal: OnboardingGoal) {
        if selectedGoals.contains(goal) {
            selectedGoals.remove(goal)
        } else {
            selectedGoals.insert(goal)
        }
    }

    private func connectHealthAndContinue() {
        guard !isWorking else { return }
        isWorking = true
        Task {
            if healthAccess.state == .needsRequest {
                await healthAccess.connect()
            }
            isWorking = false
            advance()
        }
    }

    private func enableNotificationsAndContinue() {
        guard !isWorking else { return }
        isWorking = true
        Task {
            await notifications.setMorningReminder(enabled: true)
            isWorking = false
            advance()
        }
    }

    private func purchase(_ product: Product) {
        guard !isWorking else { return }
        isWorking = true
        Task {
            await store.purchase(product)
            isWorking = false
            if store.hasPro {
                finish()
            }
        }
    }

    private func restorePurchases() {
        guard !isWorking else { return }
        isWorking = true
        Task {
            try? await AppStore.sync()
            await store.refreshEntitlement()
            isWorking = false
            if store.hasPro {
                finish()
            }
        }
    }

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.32)) {
            step = next
        }
    }

    private func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
            step = previous
        }
    }

    private func loadExistingProfileOnce() {
        guard !didLoadProfile else { return }
        didLoadProfile = true
        guard let profile = profiles.first else { return }
        selectedGoals = Set(profile.onboardingGoals ?? [])
    }

    private func saveDraft(completed: Bool = false) {
        let orderedGoals = OnboardingGoal.allCases.filter(selectedGoals.contains)
        let profile: UserProfile
        if let existingProfile = profiles.first {
            profile = existingProfile
        } else {
            profile = UserProfile()
            modelContext.insert(profile)
        }

        profile.displayName = trimmedName.isEmpty ? nil : trimmedName
        profile.onboardingGoals = orderedGoals
        profile.goal = mappedFitnessGoal(from: orderedGoals)
        profile.preferredActivities = mappedActivities(from: orderedGoals)
        profile.hasCompletedOnboarding = completed
        try? modelContext.save()
    }

    private func finish() {
        saveDraft(completed: true)
        hasCompletedOnboarding = true
        onComplete()
    }

    private func mappedFitnessGoal(from goals: [OnboardingGoal]) -> FitnessGoal {
        if goals.contains(.walkMore) { return .walkingEndurance }
        if goals.contains(.buildConsistency) { return .getActiveAgain }
        if goals.contains(.recoverSmarter) { return .improveMobility }
        return .generalFitness
    }

    private func mappedActivities(from goals: [OnboardingGoal]) -> [ActivityType] {
        var activities: [ActivityType] = []
        if goals.contains(.walkMore) || goals.contains(.buildConsistency) {
            activities.append(.walking)
        }
        if goals.contains(.recoverSmarter) || goals.contains(.sleepBetter) {
            activities.append(.recovery)
        }
        return activities.isEmpty ? [.walking] : activities
    }
}

private struct OnboardingProgressView: View {
    let value: Double
    let total: Double
    let showsBackButton: Bool
    let backAction: () -> Void

    var body: some View {
        HStack(spacing: BPSpacing.medium) {
            if showsBackButton {
                Button(action: backAction) {
                    Image(systemName: "chevron.backward")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Back")
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }

            ProgressView(value: value, total: total)
                .tint(BodyPilotColors.accentOrange)
                .accessibilityLabel("Onboarding progress")
                .accessibilityValue("Step \(Int(value)) of \(Int(total))")

            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, BPSpacing.medium)
        .padding(.top, BPSpacing.small)
    }
}

private struct OnboardingPrimaryButton: View {
    let title: String
    var isDisabled = false
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.headline)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: BPCornerRadius.control))
        .disabled(isDisabled || isLoading)
    }
}

private struct OnboardingPage: View {
    let artwork: String
    let fallbackSystemImage: String
    var kicker: LocalizedStringResource?
    let title: String
    let message: LocalizedStringResource
    var alignment: HorizontalAlignment = .center

    var body: some View {
        VStack(alignment: alignment, spacing: BPSpacing.medium) {
            OnboardingArtwork(assetName: artwork, fallbackSystemImage: fallbackSystemImage)
            if let kicker {
                Text(kicker)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BodyPilotColors.accentOrange)
            }
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(BodyPilotColors.primaryText)
                .multilineTextAlignment(alignment == .center ? .center : .leading)
            Text(message)
                .font(.title3)
                .foregroundStyle(BodyPilotColors.secondaryText)
                .multilineTextAlignment(alignment == .center ? .center : .leading)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }
}

private struct FullBleedOnboardingArtwork: View {
    let assetName: String
    let fallbackSystemImage: String

    var body: some View {
        GeometryReader { proxy in
            Group {
                if UIImage(named: assetName) != nil {
                    Image(assetName)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [BodyPilotColors.background, BodyPilotColors.warmGlow],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        Image(systemName: fallbackSystemImage)
                            .font(.system(size: 96, weight: .medium))
                            .foregroundStyle(BodyPilotColors.sleepIndigo)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .accessibilityHidden(true)
        }
        .ignoresSafeArea()
    }
}

private struct OnboardingArtwork: View {
    let assetName: String
    let fallbackSystemImage: String

    var body: some View {
        Group {
            if UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .accessibilityHidden(true)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [BodyPilotColors.sleepLavender, BodyPilotColors.warmGlow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: fallbackSystemImage)
                        .font(.system(size: 72, weight: .medium))
                        .foregroundStyle(BodyPilotColors.sleepIndigo)
                }
                .clipShape(.rect(cornerRadius: 28))
                .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 210)
    }
}

private struct FeaturePill: View {
    let title: LocalizedStringResource
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(BodyPilotColors.sleepIndigo)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(BodyPilotColors.sleepLavender, in: .capsule)
    }
}

private struct GoalSelectionCard: View {
    let goal: OnboardingGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: BPSpacing.medium) {
                Image(systemName: goal.systemImage)
                    .font(.title2)
                    .foregroundStyle(goal.tint)
                    .frame(width: 44, height: 44)
                    .background(goal.tint.opacity(0.12), in: .circle)
                Text(goal.displayName)
                    .font(.headline)
                    .foregroundStyle(BodyPilotColors.primaryText)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? BodyPilotColors.accentOrange : BodyPilotColors.secondaryText)
            }
            .padding(BPSpacing.medium)
            .background(BodyPilotColors.card, in: .rect(cornerRadius: BPCornerRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: BPCornerRadius.card)
                    .stroke(isSelected ? BodyPilotColors.accentOrange : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct HealthCategoryRow: View {
    let title: LocalizedStringResource
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(BodyPilotColors.primaryText)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, BPSpacing.medium)
            .background(BodyPilotColors.card, in: .rect(cornerRadius: BPCornerRadius.control))
    }
}

private struct ConversationBubble: View {
    let text: LocalizedStringResource
    let isUser: Bool

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: BPSpacing.xLarge) }
            Text(text)
                .padding(BPSpacing.medium)
                .foregroundStyle(isUser ? .white : BodyPilotColors.primaryText)
                .background(
                    isUser ? AnyShapeStyle(BodyPilotColors.sleepIndigo) : AnyShapeStyle(BodyPilotColors.card),
                    in: .rect(cornerRadius: BPCornerRadius.card)
                )
            if !isUser { Spacer(minLength: BPSpacing.xLarge) }
        }
    }
}

private struct ReadyChecklistRow: View {
    let title: LocalizedStringResource

    var body: some View {
        Label(title, systemImage: "checkmark.circle.fill")
            .font(.headline)
            .foregroundStyle(BodyPilotColors.primaryText)
            .symbolRenderingMode(.palette)
            .foregroundStyle(BodyPilotColors.successGreen, BodyPilotColors.sleepLavender)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}

private struct PremiumBenefit: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: BPSpacing.medium) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(BodyPilotColors.accentOrange)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(BodyPilotColors.primaryText)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(BodyPilotColors.secondaryText)
            }
        }
    }
}

private enum LegalDocument: String, Identifiable {
    case health
    case terms
    case privacy

    var id: String { rawValue }
}

private struct OnboardingLegalView: View {
    @Environment(\.dismiss) private var dismiss
    let document: LegalDocument

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BPSpacing.medium) {
                    Text(title)
                        .font(.largeTitle.bold())
                    Text(message)
                        .font(.body)
                        .foregroundStyle(BodyPilotColors.secondaryText)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BPSpacing.large)
            }
            .background(BodyPilotColors.background)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var title: LocalizedStringResource {
        switch document {
        case .health: "Why we ask"
        case .terms: "Subscription Terms"
        case .privacy: "Privacy"
        }
    }

    private var message: LocalizedStringResource {
        switch document {
        case .health:
            "BodyPilot uses only the Apple Health categories you approve to personalize activity, recovery, and wellbeing guidance. Your health data stays on your device and is never used for advertising. You can change access at any time in Settings."
        case .terms:
            "Payment is charged to your Apple Account after confirmation. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. You can manage or cancel your subscription in your Apple Account settings."
        case .privacy:
            "BodyPilot is designed to process health information privately on your device. Health data is used to provide app features and is not used for advertising. You control access through Apple Health settings."
        }
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [UserProfile.self, CoachPreference.self], inMemory: true)
}
