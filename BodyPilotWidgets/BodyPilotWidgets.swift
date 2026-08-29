import WidgetKit
import SwiftUI

/// Reads the derived snapshot the app publishes to the shared App Group.
/// Key names must stay in sync with the writer in
/// `BodyPilot/Widgets/WidgetSnapshotStore.swift`.
struct WidgetData {
    static let suiteName = "group.com.samueleskenasy.BodyPilot"

    let bodyScore: Int?
    let readinessRaw: String?
    let readinessLabel: String?
    let recommendationText: String?
    let movementValue: String?
    let movementStatus: String?

    static func load() -> WidgetData {
        let defaults = UserDefaults(suiteName: suiteName)
        return WidgetData(
            bodyScore: defaults?.object(forKey: "widget.bodyScore") as? Int,
            readinessRaw: defaults?.string(forKey: "widget.readinessRaw"),
            readinessLabel: defaults?.string(forKey: "widget.readinessLabel"),
            recommendationText: defaults?.string(forKey: "widget.recommendationText"),
            movementValue: defaults?.string(forKey: "widget.movementValue"),
            movementStatus: defaults?.string(forKey: "widget.movementStatus")
        )
    }

    /// Calm readiness tint matching the app: recovery days are indigo, never red.
    var readinessTint: Color {
        switch readinessRaw {
        case "strong": .green
        case "ready": .teal
        case "easy": .orange
        case "recover": .indigo
        default: .secondary
        }
    }
}

struct BodyPilotEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct BodyPilotProvider: TimelineProvider {
    func placeholder(in context: Context) -> BodyPilotEntry {
        BodyPilotEntry(date: .now, data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (BodyPilotEntry) -> Void) {
        completion(BodyPilotEntry(date: .now, data: context.isPreview ? .placeholder : .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BodyPilotEntry>) -> Void) {
        let entry = BodyPilotEntry(date: .now, data: .load())
        // The app refreshes the shared snapshot and reloads timelines itself;
        // this interval is only a fallback so stale data eventually re-renders.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

extension WidgetData {
    static let placeholder = WidgetData(
        bodyScore: 72,
        readinessRaw: "ready",
        readinessLabel: "Ready",
        recommendationText: "25–35 min · Moderate",
        movementValue: "6,240 steps",
        movementStatus: "On track for today"
    )
}

// MARK: - Body Score widget

struct BodyScoreWidgetView: View {
    let entry: BodyPilotEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Body Score")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let score = entry.data.bodyScore {
                Text("\(score)")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(entry.data.readinessTint)
                if let label = entry.data.readinessLabel {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(entry.data.readinessTint)
                }
                if let recommendation = entry.data.recommendationText {
                    Text(recommendation)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(verbatim: "—")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("Open BodyPilot to calculate today's score.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct BodyScoreWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BodyScoreWidget", provider: BodyPilotProvider()) { entry in
            BodyScoreWidgetView(entry: entry)
        }
        .configurationDisplayName("Body Score")
        .description("Today's readiness and recommended session at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Steps widget

struct StepsWidgetView: View {
    let entry: BodyPilotEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Movement", systemImage: "figure.walk")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let value = entry.data.movementValue {
                Text(value)
                    .font(.title2.weight(.semibold))
                    .minimumScaleFactor(0.7)
                if let status = entry.data.movementStatus {
                    Text(status)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Open BodyPilot to see your movement vs your usual day.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct StepsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StepsWidget", provider: BodyPilotProvider()) { entry in
            StepsWidgetView(entry: entry)
        }
        .configurationDisplayName("Steps vs Your Usual")
        .description("How today's movement compares with your own pattern.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview("Body Score", as: .systemSmall) {
    BodyScoreWidget()
} timeline: {
    BodyPilotEntry(date: .now, data: .placeholder)
}

#Preview("Steps", as: .systemSmall) {
    StepsWidget()
} timeline: {
    BodyPilotEntry(date: .now, data: .placeholder)
}
