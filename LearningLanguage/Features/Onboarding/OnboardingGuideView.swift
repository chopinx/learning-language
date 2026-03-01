import SwiftUI

struct OnboardingGuideView: View {
    let onFinish: () -> Void
    var body: some View {
        VStack { Text("Welcome").font(.largeTitle); Button("Get Started") { onFinish() } }
    }
}
