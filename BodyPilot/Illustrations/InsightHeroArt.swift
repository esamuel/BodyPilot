import SwiftUI

/// Hero artwork for insight pages: commissioned BodyPilot scenes cropped to
/// their text-free art regions. Static by nature, so no Reduce Motion variant
/// is needed. Decorative only — live values are overlaid by the insight page.
struct InsightHeroArt: View {
    let resource: ImageResource

    var body: some View {
        GeometryReader { proxy in
            Image(resource)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

/// Maps each world to its artwork. V1.1 worlds get art when they ship.
extension InsightKind {
    var heroArt: ImageResource? {
        switch self {
        case .sleep: .sleepHeroArt
        case .movement: .movementHeroArt
        case .recovery: .recoveryHeroArt
        case .trainingLoad: .trainingLoadHeroArt
        case .workoutHistory: .journeyHeroArt
        case .heart, .strength, .mobilityBalance: nil
        }
    }
}

#Preview("Sleep") {
    InsightHeroArt(resource: .sleepHeroArt)
        .frame(height: 200)
}

#Preview("Movement") {
    InsightHeroArt(resource: .movementHeroArt)
        .frame(height: 200)
}

#Preview("Recovery") {
    InsightHeroArt(resource: .recoveryHeroArt)
        .frame(height: 200)
}

#Preview("Training Load") {
    InsightHeroArt(resource: .trainingLoadHeroArt)
        .frame(height: 200)
}

#Preview("Journey") {
    InsightHeroArt(resource: .journeyHeroArt)
        .frame(height: 200)
}
