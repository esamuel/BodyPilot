import SwiftUI

/// First onboarding screen: the BodyPilot coach walks down the hill to the
/// front of the scene and greets the user. The landscape is an original
/// SwiftUI illustration; only the mascot cutout is a rendered image.
struct IntroOnboardingScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onStart: () -> Void

    /// 0 = on the hill crest (small, far away), 1 = front and center.
    @State private var walkProgress: CGFloat = 0
    @State private var showsGreeting = false
    @State private var showsStartButton = false

    var body: some View {
        ZStack {
            IntroHillScene()

            VStack(spacing: 0) {
                Spacer()

                ZStack(alignment: .top) {
                    Image(BodyPilotAsset.coachMascot)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 340)
                        .modifier(WalkDownModifier(progress: walkProgress))
                        .accessibilityHidden(true)

                    if showsGreeting {
                        SpeechBubble(text: "Hi! I'm BodyPilot — your coach.")
                            .offset(y: -46)
                            .transition(.scale(scale: 0.4, anchor: .bottom).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity)

                Button(action: onStart) {
                    Text("Tap to Start")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(.black, in: .capsule)
                }
                .buttonStyle(.plain)
                .opacity(showsStartButton ? 1 : 0)
                .disabled(!showsStartButton)
                .padding(.horizontal, BPSpacing.xLarge)
                .padding(.top, BPSpacing.large)
                .padding(.bottom, BPSpacing.large)
            }
        }
        .ignoresSafeArea(edges: .top)
        .task {
            await runEntrance()
        }
    }

    private func runEntrance() async {
        if reduceMotion {
            walkProgress = 1
            showsGreeting = true
            showsStartButton = true
            return
        }
        // Let the scene settle for a beat before the coach sets off.
        try? await Task.sleep(for: .milliseconds(350))
        withAnimation(.easeInOut(duration: 2.3)) {
            walkProgress = 1
        }
        try? await Task.sleep(for: .milliseconds(2_450))
        withAnimation(.spring(duration: 0.45, bounce: 0.35)) {
            showsGreeting = true
        }
        try? await Task.sleep(for: .milliseconds(400))
        withAnimation(.easeIn(duration: 0.4)) {
            showsStartButton = true
        }
    }
}

/// Moves the mascot from the hill crest (small, upper right) to the front,
/// with a gentle walking bob that fades out on arrival. Animatable so the
/// bob is computed continuously from the interpolated progress.
private struct WalkDownModifier: ViewModifier, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let remaining = 1 - progress
        let bob = sin(progress * .pi * 7)
        return content
            .scaleEffect(0.30 + 0.70 * progress, anchor: .bottom)
            .rotationEffect(.degrees(bob * 2.5 * remaining), anchor: .bottom)
            .offset(
                x: 92 * remaining,
                y: -216 * remaining + bob * 5 * remaining
            )
    }
}

/// Rounded greeting bubble with a small tail pointing at the coach.
private struct SpeechBubble: View {
    let text: LocalizedStringKey

    var body: some View {
        VStack(spacing: -1) {
            Text(text)
                .font(.title3.weight(.semibold))
                .foregroundStyle(BodyPilotColors.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BPSpacing.medium)
                .padding(.vertical, BPSpacing.small + 2)
                .background(.white, in: .rect(cornerRadius: 20))
                .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
            Triangle()
                .fill(.white)
                .frame(width: 18, height: 10)
        }
        .padding(.horizontal, BPSpacing.xLarge)
    }

    private nonisolated struct Triangle: Shape {
        nonisolated func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}

/// Original static landscape: warm sky, sun, layered hills, and a path
/// winding down from the crest where the coach starts.
private struct IntroHillScene: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BodyPilotColors.warmGlow, Color(hex: 0xFDF6EC), BodyPilotColors.landscapeBlue.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )

            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height

                // Sun
                Circle()
                    .fill(Color(hex: 0xFFE7B8))
                    .frame(width: width * 0.42)
                    .blur(radius: 6)
                    .position(x: width * 0.22, y: height * 0.20)

                // Far hill on the left
                Ellipse()
                    .fill(BodyPilotColors.landscapeBlue.opacity(0.8))
                    .frame(width: width * 1.3, height: height * 0.42)
                    .position(x: width * 0.15, y: height * 0.62)

                // Near hill on the right — the one the coach walks down
                Ellipse()
                    .fill(Color(hex: 0xB9D3EC))
                    .frame(width: width * 1.6, height: height * 0.55)
                    .position(x: width * 0.88, y: height * 0.68)

                // Path from the crest toward the front
                PathShape()
                    .fill(Color.white.opacity(0.75))
                    .frame(width: width, height: height * 0.5)
                    .position(x: width * 0.5, y: height * 0.72)

                // Foreground ground
                Ellipse()
                    .fill(Color(hex: 0xF3E9D8))
                    .frame(width: width * 2.2, height: height * 0.38)
                    .position(x: width * 0.5, y: height * 1.02)
            }
        }
        .accessibilityHidden(true)
    }

    /// A path that widens as it comes toward the viewer.
    private nonisolated struct PathShape: Shape {
        nonisolated func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.width * 0.72, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.width * 0.28, y: rect.maxY),
                control: CGPoint(x: rect.width * 0.30, y: rect.height * 0.45)
            )
            path.addLine(to: CGPoint(x: rect.width * 0.78, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.width * 0.78, y: rect.minY),
                control: CGPoint(x: rect.width * 0.52, y: rect.height * 0.40)
            )
            path.closeSubpath()
            return path
        }
    }
}

// DesignSystem's hex initializer is file-private; the scene needs a local copy
// for its three landscape-only tones.
private extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

#Preview("Intro") {
    IntroOnboardingScreen(onStart: {})
}
