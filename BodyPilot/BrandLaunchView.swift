import SwiftUI

struct BrandLaunchView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image("BodyPilotLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)

            Text(BodyPilotBrand.appName)
                .font(.largeTitle.bold())
                .foregroundStyle(BodyPilotBrand.deepBlue)

            Text(BodyPilotBrand.tagline)
                .font(.headline)
                .foregroundStyle(BodyPilotBrand.coolGray)
        }
        .padding()
        .background(BodyPilotBrand.white)
    }
}

#Preview {
    BrandLaunchView()
}
