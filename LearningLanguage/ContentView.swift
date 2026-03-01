import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @State private var showOnboardingGuide = false

    var body: some View {
        HomeView(viewModel: viewModel)
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
