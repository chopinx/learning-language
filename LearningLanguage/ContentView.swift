import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @State private var showOnboardingGuide = false

    var body: some View {
        TabView {
            HomeView(viewModel: viewModel)
                .tabItem { Label("Home", systemImage: "house.fill") }

            SettingsView(viewModel: viewModel, apiKeyManager: viewModel.apiKeyManager)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .onAppear {
            if viewModel.shouldShowOnboardingGuide {
                showOnboardingGuide = true
            }
        }
        .fullScreenCover(isPresented: $showOnboardingGuide) {
            OnboardingGuideView {
                viewModel.markOnboardingGuideSeen()
                showOnboardingGuide = false
            }
        }
    }
}
