import SwiftUI
import StoreKit

/// BodyPilot Pro subscription screen (skeleton per PRD 14).
struct PaywallView: View {
    @State private var store = SubscriptionService()

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    Image("BodyPilotLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 56)
                        .accessibilityHidden(true)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            Section("BodyPilot Pro") {
                Label("AI Coach conversations", systemImage: "bubble.left.and.text.bubble.right")
                Label("Personalized workout generation", systemImage: "figure.run")
                Label("Live Watch coaching", systemImage: "applewatch")
                Label("Personal programs", systemImage: "calendar")
                Label("Advanced progress analysis", systemImage: "chart.line.uptrend.xyaxis")
            }
            Section {
                if store.hasPro {
                    Label("You have BodyPilot Pro", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if store.products.isEmpty {
                    Text("Subscriptions aren't available yet. Everything you see today stays free while BodyPilot is in development.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.products, id: \.id) { product in
                        Button {
                            Task {
                                await store.purchase(product)
                            }
                        } label: {
                            HStack {
                                Text(product.displayName)
                                Spacer()
                                Text(product.displayPrice)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("BodyPilot Pro")
        .task {
            await store.load()
        }
    }
}

#Preview {
    NavigationStack {
        PaywallView()
    }
}
