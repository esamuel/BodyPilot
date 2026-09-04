import Charts
import SwiftData
import SwiftUI

struct SleepView: View {
    @Query private var profiles: [UserProfile]
    @State private var model: SleepModel
    @State private var presentedInfo: SleepInfoKind?
    @State private var isGoalPresented = false
    @State private var isOverviewExpanded = false

    init(model: SleepModel = SleepModel()) {
        _model = State(initialValue: model)
    }

    private var sleepGoal: Double { profiles.first?.sleepGoalHours ?? 8 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                dateNavigator

                if model.isLoading {
                    ProgressView("Loading sleep from Apple Health…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                } else if let errorMessage = model.errorMessage {
                    ContentUnavailableView(
                        "Sleep data unavailable",
                        systemImage: "moon.zzz",
                        description: Text(errorMessage)
                    )
                } else if let night = model.selectedNight {
                    qualitySection(night)
                    metricsSection(night)
                    SleepStagesSection(
                        night: night,
                        goalHours: sleepGoal,
                        onInfo: { presentedInfo = .stages }
                    )
                    shortTermSection
                    NavigationLink {
                        AboutSleepView()
                    } label: {
                        SleepNavigationRow(title: "About Sleep")
                    }
                    .buttonStyle(.plain)
                } else {
                    ContentUnavailableView(
                        "No sleep recorded",
                        systemImage: "moon.zzz",
                        description: Text("Wear Apple Watch to bed or add sleep in Apple Health, then check again.")
                    )
                    .frame(minHeight: 420)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(BodyPilotColors.background)
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isGoalPresented = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Edit sleep goal")
            }
        }
        .task { await model.refresh() }
        .refreshable { await model.refresh() }
        .sheet(item: $presentedInfo) { kind in
            SleepInfoSheet(kind: kind, model: model, goalHours: sleepGoal)
        }
        .sheet(isPresented: $isGoalPresented) {
            SleepGoalSheet(initialGoal: sleepGoal) { goal in
                profiles.first?.sleepGoalHours = goal
            }
        }
    }

    private var dateNavigator: some View {
        HStack {
            Button { model.moveSelection(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .disabled(!model.canMove(by: -1))

            Spacer()
            Text(model.selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()

            Button { model.moveSelection(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .disabled(!model.canMove(by: 1))
        }
        .font(.title3.weight(.regular))
    }

    private func qualitySection(_ night: SleepNight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep Quality")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(model.quality(goalHours: sleepGoal).rawValue)
                .font(.system(.largeTitle, design: .rounded, weight: .medium))
            Text(model.narrative(goalHours: sleepGoal))
                .font(.title3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func metricsSection(_ night: SleepNight) -> some View {
        let durationRange = model.optimalDurationRange(goalHours: sleepGoal)
        let restorativeRange = model.optimalRestorativeRange(goalHours: sleepGoal)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 22) {
            SleepMetric(
                title: "Sleep Duration",
                value: durationString(night.totalSleep),
                status: model.status(for: night.totalSleep, range: durationRange),
                onInfo: { presentedInfo = .duration }
            )
            SleepMetric(
                title: "Restorative Sleep",
                value: durationString(night.restorativeSleep),
                status: model.status(for: night.restorativeSleep, range: restorativeRange),
                onInfo: { presentedInfo = .restorative }
            )
            SleepMetric(
                title: "Fell Asleep At",
                value: timeString(night.fellAsleepAt),
                status: ("Recorded", .positive),
                onInfo: nil
            )
            SleepMetric(
                title: "Woke Up At",
                value: timeString(night.wokeUpAt),
                status: ("Recorded", .positive),
                onInfo: nil
            )
        }
    }

    private var shortTermSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy) { isOverviewExpanded.toggle() }
            } label: {
                SleepNavigationRow(
                    title: "Short-term Overview",
                    isExpanded: isOverviewExpanded
                )
            }
            .buttonStyle(.plain)

            if isOverviewExpanded {
                ShortTermSleepOverview(model: model, goalHours: sleepGoal)
                    .padding(.top, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

private struct SleepMetric: View {
    let title: LocalizedStringResource
    let value: String
    let status: (String, SleepStatusTone)
    let onInfo: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let onInfo {
                    Button(action: onInfo) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("More information")
                }
            }
            Text(value)
                .font(.system(.title, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Label(status.0, systemImage: statusIcon)
                .font(.subheadline)
                .foregroundStyle(statusColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var statusColor: Color {
        switch status.1 {
        case .positive: BodyPilotColors.successGreen
        case .warning: BodyPilotColors.warningOrange
        case .critical: .red
        }
    }

    private var statusIcon: String {
        switch status.1 {
        case .positive: "checkmark.circle.fill"
        case .warning: "arrow.up.circle.fill"
        case .critical: "chevron.down.circle.fill"
        }
    }
}

private struct SleepStagesSection: View {
    let night: SleepNight
    let goalHours: Double
    let onInfo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Text("Sleep Stages")
                    .font(.title3.weight(.medium))
                Button(action: onInfo) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("More information about sleep stages")
            }

            SleepStageTimeline(night: night)

            VStack(spacing: 14) {
                StageOverviewRow(stage: .awake, night: night, goalHours: goalHours)
                StageOverviewRow(stage: .rem, night: night, goalHours: goalHours)
                StageOverviewRow(stage: .core, night: night, goalHours: goalHours)
                StageOverviewRow(stage: .deep, night: night, goalHours: goalHours)
            }
        }
        .padding(.top, 8)
    }
}

private struct SleepStageTimeline: View {
    let night: SleepNight

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let start = night.segments.map(\.start).min() ?? night.date
                let end = night.segments.map(\.end).max() ?? night.date.addingTimeInterval(1)
                let total = max(end.timeIntervalSince(start), 1)
                ZStack(alignment: .topLeading) {
                    ForEach(0..<5, id: \.self) { index in
                        Rectangle()
                            .fill(Color.secondary.opacity(0.16))
                            .frame(width: 1)
                            .offset(x: geometry.size.width * CGFloat(index) / 4)
                    }
                    ForEach(night.segments) { segment in
                        let x = geometry.size.width * segment.start.timeIntervalSince(start) / total
                        let width = max(3, geometry.size.width * segment.duration / total)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(segment.stage.color)
                            .frame(width: width, height: 34)
                            .offset(x: x, y: segment.stage.timelineY)
                    }
                }
            }
            .frame(height: 150)

            HStack {
                Text(timeString(night.segments.map(\.start).min()))
                Spacer()
                Text(timeString(night.segments.map(\.end).max()))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sleep stage timeline from \(timeString(night.fellAsleepAt)) to \(timeString(night.wokeUpAt))")
    }
}

private struct StageOverviewRow: View {
    let stage: SleepStage
    let night: SleepNight
    let goalHours: Double

    var body: some View {
        let value = night.duration(for: stage)
        let denominator = stage == .awake ? max(value + night.totalSleep, 1) : max(night.totalSleep, 1)
        let fraction = min(max(value / denominator, 0), 1)
        HStack(spacing: 12) {
            Text(stage.title)
                .frame(width: 58, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.1))
                    Capsule()
                        .fill(stage.color)
                        .frame(width: max(4, geometry.size.width * fraction))
                }
            }
            .frame(height: 28)
            Text(fraction, format: .percent.precision(.fractionLength(0)))
                .font(.body.weight(.medium).monospacedDigit())
                .frame(width: 48, alignment: .trailing)
            Text(durationString(value))
                .font(.body.weight(.medium).monospacedDigit())
                .frame(width: 72, alignment: .trailing)
        }
    }
}

private struct ShortTermSleepOverview: View {
    enum Metric: String, CaseIterable, Identifiable {
        case duration = "Duration"
        case consistency = "Consistency"
        case stages = "Stages"
        var id: Self { self }
    }

    let model: SleepModel
    let goalHours: Double
    @State private var metric: Metric = .duration

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Picker("Sleep metric", selection: $metric) {
                ForEach(Metric.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            switch metric {
            case .duration: durationView
            case .consistency: consistencyView
            case .stages: stagesView
            }
        }
        .padding(18)
        .background(BodyPilotColors.sleepLavender.opacity(0.38), in: .rect(cornerRadius: 20))
    }

    private var durationView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                overviewValue("Avg. Sleep Duration", model.averageSleep, model.status(for: model.averageSleep, range: model.optimalDurationRange(goalHours: goalHours)))
                Spacer()
                overviewValue("Duration Variability", model.durationVariability, variabilityStatus)
            }
            Chart(model.recentNights) { night in
                RectangleMark(
                    x: .value("Day", night.date, unit: .day),
                    yStart: .value("Lower", goalHours * 0.9),
                    yEnd: .value("Upper", goalHours * 1.1)
                )
                .foregroundStyle(BodyPilotColors.sleepLavender.opacity(0.7))
                BarMark(
                    x: .value("Day", night.date, unit: .day),
                    y: .value("Hours", night.totalSleep / 3600)
                )
                .foregroundStyle(BodyPilotColors.coreBlue.gradient)
                .cornerRadius(5)
                RuleMark(y: .value("Average", model.averageSleep / 3600))
                    .foregroundStyle(.secondary)
            }
            .chartYScale(domain: 0...max(10, goalHours * 1.25))
            .chartXAxis { AxisMarks(values: .stride(by: .day, count: 2)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
            .frame(height: 240)
        }
    }

    private var consistencyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Consistency")
                .font(.title3.weight(.medium))
            Text("Your duration variability over the last 30 recorded nights is \(durationString(model.durationVariability)). Lower variability generally means a steadier sleep routine.")
                .foregroundStyle(.secondary)
            ProgressView(value: max(0, 1 - model.durationVariability / (2 * 3600)))
                .tint(BodyPilotColors.sleepIndigo)
        }
    }

    private var stagesView: some View {
        VStack(spacing: 16) {
            averageStageRow(.rem)
            averageStageRow(.core)
            averageStageRow(.deep)
        }
    }

    private var variabilityStatus: (String, SleepStatusTone) {
        if model.durationVariability <= 30 * 60 { return (String(localized: "Steady"), .positive) }
        if model.durationVariability <= 60 * 60 { return (String(localized: "Moderate"), .warning) }
        return (String(localized: "High"), .critical)
    }

    private func overviewValue(_ title: LocalizedStringResource, _ value: TimeInterval, _ status: (String, SleepStatusTone)) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(durationString(value)).font(.title2.weight(.semibold)).monospacedDigit()
            Text(status.0).font(.subheadline).foregroundStyle(status.1.color)
        }
    }

    private func averageStageRow(_ stage: SleepStage) -> some View {
        let value = model.averageDuration(for: stage)
        let range = model.optimalStageRange(stage, goalHours: goalHours)
        return HStack {
            Circle().fill(stage.color).frame(width: 12, height: 12)
            Text(stage.title).font(.body.weight(.medium))
            Spacer()
            Text(durationString(value)).font(.body.weight(.medium).monospacedDigit())
            Text(model.status(for: value, range: range).0).foregroundStyle(.secondary)
        }
    }
}

private struct SleepNavigationRow: View {
    let title: LocalizedStringResource
    var isExpanded: Bool? = nil

    var body: some View {
        HStack {
            Text(title).font(.title3.weight(.medium))
            Spacer()
            Image(systemName: isExpanded == true ? "chevron.down" : "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 18)
        .contentShape(.rect)
        .overlay(alignment: .bottom) { Divider() }
    }
}

enum SleepInfoKind: String, Identifiable {
    case duration
    case restorative
    case stages
    var id: Self { self }
}

private struct SleepInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let kind: SleepInfoKind
    let model: SleepModel
    let goalHours: Double

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch kind {
                    case .duration: durationContent
                    case .restorative: restorativeContent
                    case .stages: stagesContent
                    }
                }
                .padding(20)
            }
            .background(BodyPilotColors.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var durationContent: some View {
        let range = model.optimalDurationRange(goalHours: goalHours)
        return VStack(alignment: .leading, spacing: 24) {
            RangeInformationCard(
                title: "Your Sleep Duration",
                typical: model.averageSleep,
                range: range,
                color: BodyPilotColors.successGreen,
                explanation: "Your typical value is the average of up to 30 recorded nights. The target zone is 90–110% of your personal sleep goal."
            )
            education(
                title: "About Sleep Duration",
                paragraphs: [
                    "Getting enough sleep supports physical recovery, attention, mood, and overall health. Your personal result is compared with the goal you set in BodyPilot.",
                    "One short night is not a diagnosis. Look at the pattern over time and speak with a clinician if sleep problems are persistent or concerning."
                ]
            )
        }
    }

    private var restorativeContent: some View {
        let range = model.optimalRestorativeRange(goalHours: goalHours)
        return VStack(alignment: .leading, spacing: 24) {
            RangeInformationCard(
                title: "Your Restorative Sleep Values",
                typical: model.averageRestorative,
                range: range,
                color: BodyPilotColors.successGreen,
                explanation: "BodyPilot combines REM and deep sleep recorded by Apple Health. The reference zone is 25–45% of your personal sleep goal."
            )
            education(
                title: "About Restorative Sleep",
                paragraphs: [
                    "REM and deep sleep support different parts of mental and physical recovery. BodyPilot groups them to make the nightly pattern easier to understand.",
                    "Consumer sleep stages are estimates. Use trends as guidance, not as a medical measurement or diagnosis."
                ]
            )
        }
    }

    private var stagesContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your Sleep Stages").font(.title2.weight(.medium))
            ForEach([SleepStage.rem, .core, .deep], id: \.self) { stage in
                let range = model.optimalStageRange(stage, goalHours: goalHours)
                RangeInformationCard(
                    title: "\(stage.title) Stage",
                    typical: model.averageDuration(for: stage),
                    range: range,
                    color: stage.color,
                    explanation: stage.explanation
                )
            }
        }
    }

    private func education(title: LocalizedStringResource, paragraphs: [LocalizedStringResource]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title2.weight(.medium))
            ForEach(paragraphs.indices, id: \.self) { index in
                Text(paragraphs[index]).font(.title3)
            }
        }
    }
}

private struct RangeInformationCard: View {
    let title: String
    let typical: TimeInterval
    let range: SleepRange
    let color: Color
    let explanation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title).font(.title3.weight(.medium))
            VStack(alignment: .leading, spacing: 4) {
                Text("TYPICAL VALUE").font(.subheadline).foregroundStyle(color)
                Text(durationString(typical)).font(.largeTitle.weight(.semibold)).foregroundStyle(color)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15)).frame(height: 14)
                    Capsule().fill(color).frame(width: geometry.size.width * 0.55, height: 14).offset(x: geometry.size.width * 0.25)
                    Circle().fill(color).stroke(.white, lineWidth: 4).frame(width: 26, height: 26).offset(x: geometry.size.width * 0.20)
                }
            }
            .frame(height: 28)
            HStack {
                Text(durationString(range.lower))
                Spacer()
                Text(durationString(range.upper))
            }
            .font(.title3.weight(.medium)).foregroundStyle(color)
            Text("OPTIMAL RANGE").font(.subheadline.weight(.medium)).foregroundStyle(color).frame(maxWidth: .infinity)
            Text(explanation).font(.body).foregroundStyle(.secondary)
        }
        .padding(20)
        .background(Color.secondary.opacity(0.08), in: .rect(cornerRadius: 20))
    }
}

private struct SleepGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var goal: Double
    let onSave: (Double) -> Void

    init(initialGoal: Double, onSave: @escaping (Double) -> Void) {
        _goal = State(initialValue: initialGoal)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 70))
                .foregroundStyle(BodyPilotColors.sleepIndigo)
            Text("Sleep Goal").font(.title.weight(.medium))
            Text("Set how many hours of sleep you need per night")
                .font(.title2).multilineTextAlignment(.center)
            Text(durationString(goal * 3600))
                .font(.system(size: 58, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Slider(value: $goal, in: 5...10, step: 0.25)
                .tint(BodyPilotColors.sleepIndigo)
                .accessibilityValue(durationString(goal * 3600))
            Text("Most adults are generally advised to get at least 7 hours of sleep, while individual needs vary. Choose a realistic goal that fits you.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Done") {
                onSave(goal)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(BodyPilotColors.sleepIndigo)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .padding(28)
        .presentationDetents([.large])
    }
}

private struct AboutSleepView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(BodyPilotColors.sleepLavender)
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(BodyPilotColors.sleepIndigo)
                }
                .frame(height: 260)
                Text("Sleep Basics").font(.title.weight(.medium))
                Text("Sleep duration and quality affect energy, physical recovery, attention, and emotional wellbeing.")
                    .font(.title3.weight(.medium))
                Group {
                    Text("Why sleep matters").font(.title3.weight(.medium))
                    Label("Body recovery — sleep supports tissue repair and adaptation after activity.", systemImage: "heart.fill")
                    Label("Learning and mood — sleep supports memory, focus, and emotional regulation.", systemImage: "brain.head.profile")
                    Label("Long-term patterns — consistent sleep can be more useful than judging a single night.", systemImage: "chart.line.uptrend.xyaxis")
                }
                .font(.title3)
                Text("BodyPilot reads sleep duration and stages from Apple Health. These values are estimates and are intended for wellness guidance, not diagnosis.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .background(BodyPilotColors.background)
        .navigationTitle("About Sleep")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension SleepStage {
    var title: String {
        switch self {
        case .awake: "Awake"
        case .rem: "REM"
        case .core: "Core"
        case .deep: "Deep"
        case .asleepUnspecified: "Asleep"
        }
    }

    var color: Color {
        switch self {
        case .awake: BodyPilotColors.warningOrange
        case .rem: BodyPilotColors.remBlue
        case .core, .asleepUnspecified: BodyPilotColors.coreBlue
        case .deep: BodyPilotColors.deepPurple
        }
    }

    var timelineY: CGFloat {
        switch self {
        case .awake: 0
        case .rem: 38
        case .core, .asleepUnspecified: 76
        case .deep: 114
        }
    }

    var explanation: String {
        switch self {
        case .rem: "REM sleep is associated with dreaming, memory processing, and emotional regulation. The reference zone is 15–25% of your goal."
        case .core, .asleepUnspecified: "Core sleep includes light and intermediate sleep and commonly makes up the largest part of a night. The reference zone is 55–75% of your goal."
        case .deep: "Deep sleep is the most physically restorative stage. The reference zone is 10–20% of your goal."
        case .awake: "Brief awakenings can be a normal part of sleep."
        }
    }
}

private extension SleepStatusTone {
    var color: Color {
        switch self {
        case .positive: BodyPilotColors.successGreen
        case .warning: BodyPilotColors.warningOrange
        case .critical: .red
        }
    }
}

private func durationString(_ duration: TimeInterval) -> String {
    guard duration.isFinite, duration > 0 else { return "—" }
    let minutes = Int((duration / 60).rounded())
    return "\(minutes / 60)h \(minutes % 60)m"
}

private func timeString(_ date: Date?) -> String {
    date?.formatted(date: .omitted, time: .shortened) ?? "—"
}

#Preview {
    NavigationStack {
        SleepView(model: SleepModel(provider: MockHealthProvider()))
    }
    .modelContainer(for: UserProfile.self, inMemory: true)
}
