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
            #if os(iOS)
            .fullScreenCover(isPresented: $showOnboardingGuide) {
                OnboardingGuideView {
                    viewModel.markOnboardingGuideSeen()
                    showOnboardingGuide = false
                }
            }
            #elseif os(macOS)
            .sheet(isPresented: $showOnboardingGuide) {
                OnboardingGuideView {
                    viewModel.markOnboardingGuideSeen()
                    showOnboardingGuide = false
                }
            }
            #endif
    }
}
