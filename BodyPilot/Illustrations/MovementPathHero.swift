import SwiftUI

/// Hero for the Steps & Movement insight: an original BodyPilot landscape —
/// soft hills and a winding path marked with step dots — with the day's step
/// count and status. Built from gradients and shapes only; fully static.
struct MovementPathHero: View {
    let statusLabel: String
    let primaryValueText: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MovementHillScene()

            VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
                Text(statusLabel)
                    .font(.headline)
                Text(primaryValueText)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .foregroundStyle(BodyPilotColors.primaryText)
            .shadow(color: .white.opacity(0.7), radius: 4)
            .padding(BPSpacing.medium)
        }
        .frame(height: 220)
        .clipShape(.rect(cornerRadius: BPCornerRadius.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Steps: \(primaryValueText), \(statusLabel)"))
    }
}

/// Layered hills with a winding trail and footstep dots along it.
private struct MovementHillScene: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BodyPilotColors.warmGlow, Color.white],
                startPoint: .top,
                endPoint: .bottom
            )

            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height

                // Small morning sun, upper right
                Circle()
                    .fill(Color(red: 1.0, green: 0.87, blue: 0.65))
                    .frame(width: width * 0.20)
                    .blur(radius: 3)
                    .position(x: width * 0.82, y: height * 0.20)

                // Distant hill
                Ellipse()
                    .fill(BodyPilotColors.landscapeBlue.opacity(0.7))
                    .frame(width: width * 1.5, height: height * 0.6)
                    .position(x: width * 0.18, y: height * 0.78)

                // Near hill
                Ellipse()
                    .fill(Color(red: 0.66, green: 0.80, blue: 0.72).opacity(0.75))
                    .frame(width: width * 1.7, height: height * 0.62)
                    .position(x: width * 0.92, y: height * 0.92)

                // Winding trail
                TrailShape()
                    .stroke(.white.opacity(0.95), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(width: width, height: height)

                // Footstep dots along the trail
                TrailShape()
                    .stroke(
                        BodyPilotColors.accentOrange.opacity(0.85),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [1, 14])
                    )
                    .frame(width: width, height: height)
            }
        }
        .accessibilityHidden(true)
    }

    /// A trail sweeping from the near foreground up over the hills.
    private nonisolated struct TrailShape: Shape {
        nonisolated func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.width * 0.10, y: rect.height * 1.02))
            path.addCurve(
                to: CGPoint(x: rect.width * 0.58, y: rect.height * 0.66),
                control1: CGPoint(x: rect.width * 0.30, y: rect.height * 0.96),
                control2: CGPoint(x: rect.width * 0.34, y: rect.height * 0.70)
            )
            path.addCurve(
                to: CGPoint(x: rect.width * 1.02, y: rect.height * 0.52),
                control1: CGPoint(x: rect.width * 0.80, y: rect.height * 0.62),
                control2: CGPoint(x: rect.width * 0.88, y: rect.height * 0.50)
            )
            return path
        }
    }
}

#Preview {
    MovementPathHero(
        statusLabel: "On track for today",
        primaryValueText: "6,240 steps"
    )
    .padding()
}
