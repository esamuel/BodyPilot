import SwiftUI
import Charts

/// Shared Body Insight page template per BODY_INSIGHTS_EXPERIENCE.md:
/// hero → what it means → key numbers → your normal → pattern → coach → action.
/// Everything shown comes from the deterministic InsightSnapshot; the coach
/// section only rephrases those facts and disappears when AI is unavailable.
struct InsightDetailView: View {
    let snapshot: InsightSnapshot
    /// Runs the page CTA. The owner generates a validated workout from the action.
    let onAction: (SuggestedAction) -> Void

    @State private var coach: InsightCoachModel

    init(
        snapshot: InsightSnapshot,
        coach: InsightCoachModel = InsightCoachModel(),
        onAction: @escaping (SuggestedAction) -> Void
    ) {
        self.snapshot = snapshot
        self.onAction = onAction
        _coach = State(initialValue: coach)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: BPSpacing.large) {
                hero
                if !snapshot.metrics.isEmpty {
                    metricsGrid
                }
                if !snapshot.bodyMetrics.isEmpty {
                    BodyMetricsSection(metrics: snapshot.bodyMetrics)
                }
                if snapshot.kind != .recovery {
                    summaryCard
                }
                if !snapshot.facts.isEmpty {
                    keyNumbersCard
                }
                if !snapshot.comparisons.isEmpty {
                    yourNormalCard
                }
                if snapshot.pattern.count >= 2 {
                    patternCard
                }
                coachCard
                if let action = snapshot.action {
                    actionButton(action)
                }
            }
            .padding(BPSpacing.medium)
        }
        .navigationTitle(Text(snapshot.kind.displayName))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await coach.load(for: snapshot)
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var hero: some View {
        switch snapshot.kind {
        case .movement:
            MovementPathHero(
                statusLabel: snapshot.statusLabel,
                primaryValueText: snapshot.primaryValueText
            )
        case .recovery:
            // The verdict hero already contains the summary, so the separate
            // "What it means" card is skipped for recovery.
            RecoveryVerdictHero(
                statusLabel: snapshot.statusLabel,
                summary: snapshot.summary,
                score: snapshot.scoreValue,
                status: snapshot.status
            )
        default:
            artworkHero
        }
    }

    private var artworkHero: some View {
        ZStack(alignment: .bottomLeading) {
            heroScene
                .frame(height: 200)
                .clipShape(.rect(cornerRadius: BPCornerRadius.card))

            VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
                Text(snapshot.statusLabel)
                    .font(.headline)
                Text(snapshot.primaryValueText)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(heroTextColor)
            .shadow(color: heroTextShadow, radius: 4)
            .padding(BPSpacing.medium)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(Text(snapshot.kind.displayName)): \(snapshot.statusLabel), \(snapshot.primaryValueText)"))
    }

    /// Dark text over the light movement/recovery/load artwork (per the
    /// approved mocks); white with a dark shadow over the darker scenes.
    private var heroTextColor: Color {
        switch snapshot.kind {
        case .movement, .recovery, .trainingLoad: .graphite
        default: .white
        }
    }

    private var heroTextShadow: Color {
        switch snapshot.kind {
        case .movement, .recovery, .trainingLoad: .white.opacity(0.6)
        default: .black.opacity(0.35)
        }
    }

    @ViewBuilder
    private var heroScene: some View {
        if let art = snapshot.kind.heroArt {
            InsightHeroArt(resource: art)
        } else {
            // V1.1 worlds without commissioned artwork yet.
            LinearGradient(
                colors: [snapshot.kind.accent.opacity(0.55), .skyMist],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Stat tiles

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BPSpacing.small) {
            ForEach(snapshot.metrics, id: \.self) { metric in
                VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
                    Label {
                        Text(metric.label)
                            .font(.footnote.weight(.medium))
                    } icon: {
                        Image(systemName: metric.systemImage)
                            .font(.footnote)
                    }
                    .foregroundStyle(.secondary)
                    Text(metric.valueText)
                        .font(.title2.bold())
                        .foregroundStyle(BodyPilotColors.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BPSpacing.medium)
                .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
            }
        }
    }

    // MARK: - What it means

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: BPSpacing.small) {
            Text("What it means")
                .font(.headline)
            Text(snapshot.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if snapshot.confidence < 0.5 {
                Label("Limited data so far — this gets more accurate as history builds.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
    }

    // MARK: - Key numbers

    private var keyNumbersCard: some View {
        VStack(alignment: .leading, spacing: BPSpacing.small) {
            Text("Key numbers")
                .font(.headline)
            ForEach(snapshot.facts, id: \.self) { fact in
                VStack(alignment: .leading, spacing: 2) {
                    Text(fact.title)
                        .font(.subheadline.weight(.medium))
                    Text(fact.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
    }

    // MARK: - Your normal

    private var yourNormalCard: some View {
        VStack(alignment: .leading, spacing: BPSpacing.small) {
            Text("Your normal")
                .font(.headline)
            ForEach(snapshot.comparisons, id: \.self) { comparison in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(comparison.label)
                            .font(.subheadline.weight(.medium))
                        Text(comparison.typicalText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(comparison.todayText)
                        .font(.subheadline)
                    Image(systemName: comparison.sevenDayTrend.systemImage)
                        .font(.footnote)
                        .foregroundStyle(snapshot.kind.accent)
                        .accessibilityLabel(Text(comparison.sevenDayTrend.accessibilityDescription))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
    }

    // MARK: - Pattern

    private var patternCard: some View {
        VStack(alignment: .leading, spacing: BPSpacing.small) {
            Text("Last 7 days")
                .font(.headline)
            Chart(snapshot.pattern, id: \.date) { value in
                BarMark(
                    x: .value("Day", value.date, unit: .day),
                    y: .value("Value", value.value)
                )
                .foregroundStyle(snapshot.kind.accent.gradient)
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 140)
            .accessibilityLabel("Seven day pattern chart")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
    }

    // MARK: - Coach insight

    @ViewBuilder
    private var coachCard: some View {
        switch coach.state {
        case .ready(let text):
            VStack(alignment: .leading, spacing: BPSpacing.small) {
                Label("Coach insight", systemImage: "sparkles")
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BPSpacing.large)
            .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
        case .idle, .loading, .unavailable:
            // The page is complete without AI wording — no placeholder needed.
            EmptyView()
        }
    }

    // MARK: - Action

    private func actionButton(_ action: SuggestedAction) -> some View {
        Button {
            onAction(action)
        } label: {
            Text(action.title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(snapshot.kind.accent)
    }
}

#Preview("Sleep") {
    NavigationStack {
        InsightDetailView(
            snapshot: .previewSleep,
            coach: InsightCoachModel(explainer: PreviewInsightExplainer())
        ) { _ in }
    }
}

#Preview("Movement") {
    NavigationStack {
        InsightDetailView(snapshot: .previewMovement) { _ in }
    }
}

#Preview("Recovery") {
    NavigationStack {
        InsightDetailView(snapshot: .previewRecovery) { _ in }
    }
}
