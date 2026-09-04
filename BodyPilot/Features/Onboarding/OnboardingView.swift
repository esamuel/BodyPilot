import SwiftUI
import SwiftData
import StoreKit
import UIKit

/// Premium, state-driven onboarding that persists into the existing profile model.
struct OnboardingView: View {
    private enum Step: Int, CaseIterable {
        case intro
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

    @State private var step: Step = .intro
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
            if step == .intro {
                IntroOnboardingScreen(onStart: advance)
                    .transition(pageTransition)
            } else if step == .welcome {
                fullBleedWelcomeScreen
                    .transition(pageTransition)
            } else if step == .name {
                fullBleedNameScreen
                    .transition(pageTransition)
            } else if step == .meetBodyPilot {
                MeetBodyPilotScreen(
                    onBack: goBack,
                    onNext: advance
                )
                .transition(pageTransition)
            } else if step == .goals {
                GoalsOnboardingScreen(
                    selectedGoals: selectedGoals,
                    onToggle: toggleGoal,
                    onBack: goBack
                ) {
                    saveDraft()
                    advance()
                }
                .transition(pageTransition)
            } else if step == .healthAccess {
                HealthAccessOnboardingScreen(
                    connectionState: healthAccess.state,
                    isWorking: isWorking,
                    onBack: goBack,
                    onWhyWeAsk: { legalDocument = .health },
                    onContinue: connectHealthAndContinue
                )
                .transition(pageTransition)
            } else if step == .appleWatch {
                AppleWatchOnboardingScreen(
                    onBack: goBack,
                    onContinue: advance
                )
                .transition(pageTransition)
            } else if step == .notifications {
                RemindersOnboardingScreen(
                    isWorking: isWorking,
                    onBack: goBack,
                    onSkip: advance,
                    onEnable: enableNotificationsAndContinue
                )
                .transition(pageTransition)
            } else if step == .coach {
                CoachOnboardingScreen(
                    onBack: goBack,
                    onContinue: advance
                )
                .transition(pageTransition)
            } else if step == .ready {
                ReadyOnboardingScreen(
                    name: trimmedName,
                    onBack: goBack,
                    onContinue: advance
                )
                .transition(pageTransition)
            } else if step == .premium {
                PremiumOnboardingScreen(
                    name: trimmedName,
                    priceText: featuredProduct?.displayPrice,
                    savingsPercentage: annualSavingsPercentage,
                    hasMultiplePlans: store.products.count > 1,
                    isLoading: store.isLoading || isWorking,
                    onClose: finish,
                    onPrimaryAction: premiumPrimaryAction,
                    onMoreOptions: { showsMorePlans = true },
                    onRestore: restorePurchases
                )
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
        .sheet(isPresented: $showsMorePlans) {
            PremiumPlanOptionsView(
                products: store.products,
                isWorking: isWorking,
                onSelect: purchase,
                onRestore: restorePurchases
            )
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
                            TextField("Enter your name", text: $name)
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
                                .accessibilityLabel("Your name")
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
        case .intro, .name, .welcome, .meetBodyPilot, .goals, .healthAccess, .appleWatch, .notifications, .coach, .ready, .premium:
            EmptyView()
        }
    }

    private var annualSavingsPercentage: Int? {
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
        return savings
    }

    @ViewBuilder
    private var controls: some View {
        switch step {
        case .intro:
            OnboardingPrimaryButton(title: "Tap to Start", action: advance)
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

    private func premiumPrimaryAction() {
        guard let featuredProduct else {
            finish()
            return
        }
        purchase(featuredProduct)
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
        // Never downgrade a completed profile: replaying onboarding from Me would
        // otherwise flip MainTabView.needsOnboarding and stack a second flow.
        profile.hasCompletedOnboarding = profile.hasCompletedOnboarding || completed
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

private struct ReadyOnboardingScreen: View {
    let name: String
    let onBack: () -> Void
    let onContinue: () -> Void

    private var title: String {
        name.isEmpty ? "Your BodyPilot is ready." : "Your BodyPilot is ready, \(name)."
    }

    var body: some View {
        ZStack {
            FullBleedOnboardingArtwork(
                assetName: BodyPilotAsset.onboardingReady,
                fallbackSystemImage: "checkmark.seal.fill"
            )

            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: BPSpacing.small) {
                    VStack(alignment: .leading, spacing: BPSpacing.small) {
                        Text(title)
                            .font(.largeTitle.bold())
                            .foregroundStyle(BodyPilotColors.primaryText)
                            .accessibilityAddTraits(.isHeader)

                        Text("I’ve prepared your daily guidance and I’m ready to help you move, recover and feel better.")
                            .font(.title3)
                            .foregroundStyle(BodyPilotColors.secondaryText)
                            .lineSpacing(3)
                    }

                    VStack(spacing: BPSpacing.xSmall) {
                        ReadyChecklistRow(title: "Understanding your activity patterns")
                        ReadyChecklistRow(title: "Reviewing sleep and recovery")
                        ReadyChecklistRow(title: "Preparing today’s recommendations")
                    }

                    Spacer(minLength: BPSpacing.small)

                    Button(action: onContinue) {
                        Text("Take Me In")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(.black, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, BPSpacing.xLarge)
                .padding(.top, 60)
                .padding(.bottom, BPSpacing.medium)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .overlay(alignment: .topLeading) {
                    OnboardingBackControl(action: onBack)
                        .padding(.leading, BPSpacing.xLarge)
                        .padding(.top, BPSpacing.small)
                }
            }
        }
    }
}

private struct PremiumOnboardingScreen: View {
    let name: String
    let priceText: String?
    let savingsPercentage: Int?
    let hasMultiplePlans: Bool
    let isLoading: Bool
    let onClose: () -> Void
    let onPrimaryAction: () -> Void
    let onMoreOptions: () -> Void
    let onRestore: () -> Void

    private var offerTitle: String {
        if let savingsPercentage {
            return "\(savingsPercentage)% OFF"
        }
        return priceText == nil ? "Premium preview" : "BodyPilot Premium"
    }

    private var primaryButtonTitle: String {
        if priceText == nil {
            return "Continue into BodyPilot"
        }
        if let savingsPercentage {
            return "Save \(savingsPercentage)% and Start Today"
        }
        return "Start Today"
    }

    var body: some View {
        ZStack {
            FullBleedOnboardingArtwork(
                assetName: BodyPilotAsset.onboardingPremium,
                fallbackSystemImage: "crown.fill"
            )

            GeometryReader { proxy in
                VStack(spacing: BPSpacing.xSmall) {
                    ZStack {
                        Label("BodyPilot Premium", systemImage: "heart.fill")
                            .font(.headline)
                            .foregroundStyle(BodyPilotColors.primaryText)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(BodyPilotColors.accentOrange, BodyPilotColors.primaryText)
                            .padding(.horizontal, BPSpacing.medium)
                            .frame(minHeight: 44)
                            .background(.regularMaterial, in: .capsule)

                        HStack {
                            Spacer()
                            Button(action: onClose) {
                                Image(systemName: "xmark")
                                    .font(.title2.weight(.medium))
                                    .foregroundStyle(BodyPilotColors.primaryText)
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Continue without Premium")
                        }
                    }

                    Spacer(minLength: max(proxy.size.height * 0.34, 245))

                    VStack(spacing: 2) {
                        Text(name.isEmpty ? "Just for you" : "Just for you, \(name)")
                            .font(.subheadline)
                            .foregroundStyle(BodyPilotColors.secondaryText)
                        Text(offerTitle)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(BodyPilotColors.primaryText)
                            .minimumScaleFactor(0.8)
                        Text("Unlock the full power of BodyPilot guidance.")
                            .font(.footnote)
                            .foregroundStyle(BodyPilotColors.secondaryText)
                    }

                    VStack(spacing: BPSpacing.xSmall) {
                        PremiumOfferBenefit(title: "Move consistently, not constantly", systemImage: "figure.run", tint: .green)
                        PremiumOfferBenefit(title: "Track sleep, health & activity in one place", systemImage: "heart.fill", tint: .pink)
                        PremiumOfferBenefit(title: "Personalized recovery and readiness insights", systemImage: "moon.stars.fill", tint: .indigo)
                    }

                    VStack(spacing: BPSpacing.xSmall) {
                        if let priceText {
                            Text(priceText)
                                .font(.title2.bold())
                            Text("Annual plan")
                                .font(.caption)
                                .foregroundStyle(BodyPilotColors.secondaryText)
                        } else {
                            Text("Purchases coming soon")
                                .font(.headline)
                            Text("Continue using the full app while Premium is completed.")
                                .font(.caption)
                                .foregroundStyle(BodyPilotColors.secondaryText)
                        }

                        Button(action: onPrimaryAction) {
                            ZStack {
                                Text(primaryButtonTitle)
                                    .font(.headline)
                                    .opacity(isLoading ? 0 : 1)
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(BodyPilotColors.accentOrange, in: .rect(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)

                        HStack {
                            Button("Restore purchases", action: onRestore)
                            Spacer()
                            if hasMultiplePlans {
                                Button("More options", action: onMoreOptions)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(BodyPilotColors.secondaryText)
                    }
                    .padding(BPSpacing.small)
                    .background(.regularMaterial, in: .rect(cornerRadius: 24))
                }
                .padding(.horizontal, BPSpacing.large)
                .padding(.vertical, BPSpacing.small)
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}

private struct PremiumOfferBenefit: View {
    let title: LocalizedStringResource
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: BPSpacing.small) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: .rect(cornerRadius: 10))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BodyPilotColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PremiumPlanOptionsView: View {
    @Environment(\.dismiss) private var dismiss

    let products: [Product]
    let isWorking: Bool
    let onSelect: (Product) -> Void
    let onRestore: () -> Void

    var body: some View {
        NavigationStack {
            List(products, id: \.id) { product in
                Button {
                    onSelect(product)
                } label: {
                    HStack {
                        Text(product.displayName)
                        Spacer()
                        Text(product.displayPrice)
                            .foregroundStyle(BodyPilotColors.secondaryText)
                    }
                }
                .disabled(isWorking)
            }
            .navigationTitle("Premium options")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Restore", action: onRestore)
                        .disabled(isWorking)
                }
            }
        }
    }
}

private struct RemindersOnboardingScreen: View {
    let isWorking: Bool
    let onBack: () -> Void
    let onSkip: () -> Void
    let onEnable: () -> Void

    var body: some View {
        ZStack {
            FullBleedOnboardingArtwork(
                assetName: BodyPilotAsset.onboardingReminders,
                fallbackSystemImage: "bell.badge.fill"
            )

            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: BPSpacing.small) {
                        VStack(alignment: .leading, spacing: BPSpacing.small) {
                            Text("Keep your momentum.")
                                .font(.largeTitle.bold())
                                .foregroundStyle(BodyPilotColors.primaryText)
                                .accessibilityAddTraits(.isHeader)

                            Text("Helpful reminders keep your routine alive — and nudge you when your body is ready.")
                                .font(.title3)
                                .foregroundStyle(BodyPilotColors.secondaryText)
                                .lineSpacing(3)
                        }

                        Spacer(minLength: max(proxy.size.height * 0.58, 420))

                        HStack(spacing: BPSpacing.small) {
                            Button("Not now", action: onSkip)
                                .font(.headline)
                                .foregroundStyle(BodyPilotColors.primaryText)
                                .frame(maxWidth: .infinity, minHeight: 58)
                                .background(.regularMaterial, in: .capsule)
                                .overlay {
                                    Capsule()
                                        .stroke(.black.opacity(0.12), lineWidth: 1)
                                }
                                .buttonStyle(.plain)

                            Button(action: onEnable) {
                                ZStack {
                                    Text("Turn on reminders")
                                        .font(.headline)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.78)
                                        .opacity(isWorking ? 0 : 1)

                                    if isWorking {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 58)
                                .background(.black, in: .capsule)
                            }
                            .buttonStyle(.plain)
                            .disabled(isWorking)
                        }
                    }
                    .frame(minHeight: max(proxy.size.height - 76, 0), alignment: .top)
                    .padding(.horizontal, BPSpacing.xLarge)
                    .padding(.top, 60)
                    .padding(.bottom, BPSpacing.medium)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .overlay(alignment: .topLeading) {
                    OnboardingBackControl(action: onBack)
                        .padding(.leading, BPSpacing.xLarge)
                        .padding(.top, BPSpacing.small)
                }
            }
        }
    }
}

private struct CoachOnboardingScreen: View {
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            FullBleedOnboardingArtwork(
                assetName: BodyPilotAsset.onboardingCoach,
                fallbackSystemImage: "bubble.left.and.text.bubble.right.fill"
            )

            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: BPSpacing.small) {
                        VStack(alignment: .leading, spacing: BPSpacing.small) {
                            Text("Ask BodyPilot anything.")
                                .font(.largeTitle.bold())
                                .foregroundStyle(BodyPilotColors.primaryText)
                                .accessibilityAddTraits(.isHeader)

                            Text("Get simple coaching based on how you feel, your activity and your recovery.")
                                .font(.title3)
                                .foregroundStyle(BodyPilotColors.secondaryText)
                                .lineSpacing(3)
                        }

                        Spacer(minLength: max(proxy.size.height * 0.58, 420))

                        Button(action: onContinue) {
                            Text("Try Coach")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 58)
                                .background(.black, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(minHeight: max(proxy.size.height - 76, 0), alignment: .top)
                    .padding(.horizontal, BPSpacing.xLarge)
                    .padding(.top, 60)
                    .padding(.bottom, BPSpacing.medium)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .overlay(alignment: .topLeading) {
                    OnboardingBackControl(action: onBack)
                        .padding(.leading, BPSpacing.xLarge)
                        .padding(.top, BPSpacing.small)
                }
            }
        }
    }
}

private struct OnboardingBackControl: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward")
                .font(.headline)
                .foregroundStyle(BodyPilotColors.primaryText)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: .circle)
        }
        .accessibilityLabel("Back")
    }
}

private struct AppleWatchOnboardingScreen: View {
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            FullBleedOnboardingArtwork(
                assetName: BodyPilotAsset.onboardingWatch,
                fallbackSystemImage: "applewatch"
            )

            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: BPSpacing.small) {
                        VStack(alignment: .leading, spacing: BPSpacing.small) {
                            Text("Works beautifully with Apple Watch.")
                                .font(.largeTitle.bold())
                                .foregroundStyle(BodyPilotColors.primaryText)
                                .accessibilityAddTraits(.isHeader)

                            Text("BodyPilot uses your watch activity, heart and workout signals to understand your day.")
                                .font(.title3)
                                .foregroundStyle(BodyPilotColors.secondaryText)
                                .lineSpacing(3)
                        }

                        Spacer(minLength: max(proxy.size.height * 0.55, 400))

                        Button(action: onContinue) {
                            Text("Great")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 58)
                                .background(.black, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(minHeight: max(proxy.size.height - 76, 0), alignment: .top)
                    .padding(.horizontal, BPSpacing.xLarge)
                    .padding(.top, 60)
                    .padding(.bottom, BPSpacing.medium)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .overlay(alignment: .topLeading) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.backward")
                            .font(.headline)
                            .foregroundStyle(BodyPilotColors.primaryText)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: .circle)
                    }
                    .accessibilityLabel("Back")
                    .padding(.leading, BPSpacing.xLarge)
                    .padding(.top, BPSpacing.small)
                }
            }
        }
    }
}

private struct HealthAccessOnboardingScreen: View {
    let connectionState: HealthAccessModel.ConnectionState
    let isWorking: Bool
    let onBack: () -> Void
    let onWhyWeAsk: () -> Void
    let onContinue: () -> Void

    private var primaryButtonTitle: LocalizedStringKey {
        connectionState == .needsRequest ? "Connect Apple Health" : "Continue"
    }

    var body: some View {
        ZStack {
            FullBleedOnboardingArtwork(
                assetName: BodyPilotAsset.onboardingHealth,
                fallbackSystemImage: "heart.text.square.fill"
            )

            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: BPSpacing.small) {
                        HealthAccessOnboardingHeader()

                        Spacer(minLength: max(proxy.size.height * 0.03, BPSpacing.large))

                        HealthAccessCategoryPanel()

                        Spacer(minLength: BPSpacing.medium)

                        Button("Why we ask", action: onWhyWeAsk)
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 44)

                        if connectionState == .connected {
                            Label("Apple Health is connected", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.green)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, BPSpacing.xSmall)
                        }

                        Button(action: onContinue) {
                            ZStack {
                                Text(primaryButtonTitle)
                                    .font(.headline)
                                    .opacity(isWorking ? 0 : 1)

                                if isWorking {
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(.black, in: .capsule)
                        }
                        .buttonStyle(.plain)
                        .disabled(isWorking)
                    }
                    .frame(minHeight: max(proxy.size.height - 76, 0), alignment: .top)
                    .padding(.horizontal, BPSpacing.xLarge)
                    .padding(.top, 60)
                    .padding(.bottom, BPSpacing.medium)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .overlay(alignment: .topLeading) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.backward")
                            .font(.headline)
                            .foregroundStyle(BodyPilotColors.primaryText)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: .circle)
                    }
                    .accessibilityLabel("Back")
                    .padding(.leading, BPSpacing.xLarge)
                    .padding(.top, BPSpacing.small)
                }
            }
        }
    }
}

private struct HealthAccessOnboardingHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.small) {
            Text("Connect Apple Health")
                .font(.largeTitle.bold())
                .foregroundStyle(BodyPilotColors.primaryText)
                .accessibilityAddTraits(.isHeader)

            Text("With your permission, BodyPilot can read the signals it needs to build more accurate guidance.")
                .font(.title3)
                .foregroundStyle(BodyPilotColors.secondaryText)
                .lineSpacing(3)
        }
    }
}

private struct HealthAccessCategoryPanel: View {
    var body: some View {
        VStack(spacing: BPSpacing.xSmall) {
            HealthAccessCategoryRow(title: "Sleep", systemImage: "moon.zzz.fill", tint: .indigo)
            HealthAccessCategoryRow(title: "Steps", systemImage: "shoeprints.fill", tint: .orange)
            HealthAccessCategoryRow(title: "Heart Rate", systemImage: "heart.fill", tint: .pink)
            HealthAccessCategoryRow(title: "Workouts", systemImage: "figure.run", tint: .green)
        }
        .padding(BPSpacing.small)
        .padding(.top, 28)
        .frame(maxWidth: 224)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 28))
        .overlay(alignment: .top) {
            Image(systemName: "heart.fill")
                .font(.title.weight(.semibold))
                .foregroundStyle(.pink)
                .frame(width: 68, height: 68)
                .background(.regularMaterial, in: .rect(cornerRadius: 20))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                .offset(y: -38)
                .accessibilityHidden(true)
        }
        .padding(.top, 38)
    }
}

private struct HealthAccessCategoryRow: View {
    let title: LocalizedStringResource
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: BPSpacing.small) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.1), in: .circle)

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(BodyPilotColors.primaryText)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, BPSpacing.small)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(.thinMaterial, in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

private struct GoalsOnboardingScreen: View {
    let selectedGoals: Set<OnboardingGoal>
    let onToggle: (OnboardingGoal) -> Void
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            FullBleedOnboardingArtwork(
                assetName: BodyPilotAsset.onboardingLearn,
                fallbackSystemImage: "sparkles",
                verticalOffset: 44
            )

            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: BPSpacing.small) {
                        GoalsOnboardingHeader()
                        GoalsSelectionGrid(
                            selectedGoals: selectedGoals,
                            onToggle: onToggle
                        )

                        Spacer(minLength: max(proxy.size.height * 0.2, 160))

                        Button(action: onContinue) {
                            Text("This is me")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 58)
                                .background(.black, in: .capsule)
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedGoals.isEmpty)
                        .opacity(selectedGoals.isEmpty ? 0.5 : 1)
                    }
                    .frame(minHeight: max(proxy.size.height - 24, 0), alignment: .top)
                    .padding(.horizontal, BPSpacing.xLarge)
                    .padding(.top, BPSpacing.small)
                    .padding(.bottom, BPSpacing.medium)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .overlay(alignment: .topTrailing) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.backward")
                            .font(.headline)
                            .foregroundStyle(BodyPilotColors.primaryText)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: .circle)
                    }
                    .accessibilityLabel("Back")
                    .padding(.top, BPSpacing.small)
                    .padding(.trailing, BPSpacing.xLarge)
                }
            }
        }
    }
}

private struct GoalsOnboardingHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.small) {
            Text("Now for the important part.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BodyPilotColors.secondaryText)

            Text("Let’s learn about you.")
                .font(.largeTitle.bold())
                .foregroundStyle(BodyPilotColors.primaryText)
                .accessibilityAddTraits(.isHeader)

            Text("Tell me your goals, routine and pace so I can guide you better.")
                .font(.title3)
                .foregroundStyle(BodyPilotColors.secondaryText)
                .lineSpacing(3)
        }
    }
}

private struct GoalsSelectionGrid: View {
    private let columns = [
        GridItem(.flexible(), spacing: BPSpacing.small),
        GridItem(.flexible(), spacing: BPSpacing.small)
    ]

    let selectedGoals: Set<OnboardingGoal>
    let onToggle: (OnboardingGoal) -> Void

    var body: some View {
        LazyVGrid(columns: columns, spacing: BPSpacing.xSmall) {
            ForEach(OnboardingGoal.allCases, id: \.self) { goal in
                GoalsOnboardingCard(
                    goal: goal,
                    isSelected: selectedGoals.contains(goal)
                ) {
                    onToggle(goal)
                }
            }
        }
    }
}

private struct GoalsOnboardingCard: View {
    let goal: OnboardingGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: BPSpacing.xSmall) {
                Image(systemName: goal.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(goal.tint)
                    .frame(width: 40, height: 40)
                    .background(goal.tint.opacity(0.12), in: .circle)

                Text(goal.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BodyPilotColors.primaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, BPSpacing.small)
            .padding(.vertical, BPSpacing.xSmall)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? goal.tint : .white.opacity(0.65),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct MeetBodyPilotScreen: View {
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        ZStack {
            FullBleedOnboardingArtwork(
                assetName: BodyPilotAsset.onboardingMeet,
                fallbackSystemImage: "figure.walk.motion"
            )

            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: BPSpacing.medium) {
                        Button(action: onBack) {
                            Image(systemName: "chevron.backward")
                                .font(.headline)
                                .foregroundStyle(BodyPilotColors.primaryText)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial, in: .circle)
                        }
                        .accessibilityLabel("Back")

                        MeetBodyPilotHeader()
                        MeetBodyPilotFeatureStrip()

                        Spacer(minLength: max(proxy.size.height * 0.36, 260))

                        Button(action: onNext) {
                            Text("Next")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 58)
                                .background(.black, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(minHeight: max(proxy.size.height - 24, 0), alignment: .top)
                    .padding(.horizontal, BPSpacing.xLarge)
                    .padding(.top, BPSpacing.small)
                    .padding(.bottom, BPSpacing.medium)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }
}

private struct MeetBodyPilotHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.small) {
            Text("Meet BodyPilot.")
                .font(.largeTitle.bold())
                .foregroundStyle(BodyPilotColors.primaryText)
                .accessibilityAddTraits(.isHeader)

            Text("Your personal guide for movement, recovery and everyday wellbeing.")
                .font(.title3)
                .foregroundStyle(BodyPilotColors.secondaryText)
                .lineSpacing(3)
        }
    }
}

private struct MeetBodyPilotFeatureStrip: View {
    var body: some View {
        HStack(alignment: .top, spacing: BPSpacing.xSmall) {
            MeetBodyPilotFeature(title: "Sleep", systemImage: "moon.zzz.fill", tint: .indigo)
            MeetBodyPilotFeature(title: "Steps", systemImage: "figure.walk", tint: .mint)
            MeetBodyPilotFeature(title: "Heart", systemImage: "heart.fill", tint: .pink)
            MeetBodyPilotFeature(title: "Workouts", systemImage: "dumbbell.fill", tint: .orange)
            MeetBodyPilotFeature(title: "Recovery", systemImage: "figure.mind.and.body", tint: .teal)
        }
    }
}

private struct MeetBodyPilotFeature: View {
    let title: LocalizedStringResource
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: BPSpacing.xSmall) {
            Image(systemName: systemImage)
                .font(.title2.weight(.medium))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.white.opacity(0.7), lineWidth: 1)
                }

            Text(title)
                .font(.caption)
                .foregroundStyle(BodyPilotColors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
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
    var verticalOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                BodyPilotColors.background

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
                .offset(y: verticalOffset)
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

#Preview("Meet BodyPilot") {
    MeetBodyPilotScreen(onBack: {}, onNext: {})
}

#Preview("Onboarding Goals") {
    GoalsOnboardingScreen(
        selectedGoals: [.walkMore, .sleepBetter],
        onToggle: { _ in },
        onBack: {},
        onContinue: {}
    )
}

#Preview("Apple Health Onboarding") {
    HealthAccessOnboardingScreen(
        connectionState: .needsRequest,
        isWorking: false,
        onBack: {},
        onWhyWeAsk: {},
        onContinue: {}
    )
}

#Preview("Apple Health Onboarding — Connected") {
    HealthAccessOnboardingScreen(
        connectionState: .connected,
        isWorking: false,
        onBack: {},
        onWhyWeAsk: {},
        onContinue: {}
    )
}

#Preview("Apple Watch Onboarding") {
    AppleWatchOnboardingScreen(onBack: {}, onContinue: {})
}

#Preview("Reminders Onboarding") {
    RemindersOnboardingScreen(
        isWorking: false,
        onBack: {},
        onSkip: {},
        onEnable: {}
    )
}

#Preview("Coach Onboarding") {
    CoachOnboardingScreen(onBack: {}, onContinue: {})
}

#Preview("Ready Onboarding") {
    ReadyOnboardingScreen(name: "Samuel", onBack: {}, onContinue: {})
}

#Preview("Premium Onboarding") {
    PremiumOnboardingScreen(
        name: "Samuel",
        priceText: nil,
        savingsPercentage: nil,
        hasMultiplePlans: false,
        isLoading: false,
        onClose: {},
        onPrimaryAction: {},
        onMoreOptions: {},
        onRestore: {}
    )
}
