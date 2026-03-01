import SwiftUI

struct OnboardingGuideView: View {
    let onFinish: () -> Void

    @State private var selectedPage = 0

    private let pages: [GuidePage] = [
        GuidePage(
            title: "Welcome to LearningLanguage",
            message: "Import audio or generate practice audio from text to start a learning session.",
            systemImage: "waveform.badge.plus"
        ),
        GuidePage(
            title: "Practice Sentence by Sentence",
            message: "Play each sentence, repeat it with your voice, and generate your own transcript.",
            systemImage: "mic.circle.fill"
        ),
        GuidePage(
            title: "Compare and Track Progress",
            message: "Compare your transcript with the original, highlight mistakes, and resume later anytime.",
            systemImage: "checkmark.seal.fill"
        ),
    ]

    var body: some View {
        TabView(selection: $selectedPage) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                pageView(for: page).tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .accessibilityIdentifier("onboardingPager")
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .top) {
            HStack {
                Spacer()
                Button("Skip") { onFinish() }
                    .font(.subheadline)
                    .foregroundStyle(Color.themeTextTertiary)
                    .accessibilityIdentifier("onboardingSkipButton")
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                if selectedPage < pages.count - 1 {
                    withAnimation { selectedPage += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(selectedPage == pages.count - 1 ? "Get Started" : "Continue")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.themePrimaryGradient, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .accessibilityIdentifier("onboardingContinueButton")
        }
    }

    private func pageView(for page: GuidePage) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 30)

            Image(systemName: page.systemImage)
                .font(.largeTitle)
                .fontWeight(.light)
                .imageScale(.large)
                .scaleEffect(2.0)
                .foregroundStyle(Color.themePrimary)
                .symbolEffect(.bounce, value: selectedPage)

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.themeTextPrimary)
                    .minimumScaleFactor(0.8)

                Text(page.message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.themeTextSecondary)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
        )
    }
}

// MARK: - Guide Page Model

private struct GuidePage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let systemImage: String
}
