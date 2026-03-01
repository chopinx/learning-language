import SwiftUI

struct OnboardingGuideView: View {
    private struct GuidePage: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let systemImage: String
    }

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
        )
    ]

    var body: some View {
        TabView(selection: $selectedPage) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                guidePage(for: page)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .accessibilityIdentifier("onboardingPager")
        .background {
            AppTheme.screenBackground.ignoresSafeArea()
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Spacer()
                Button("Skip") {
                    onFinish()
                }
                .font(.body.weight(.semibold))
                .accessibilityIdentifier("onboardingSkipButton")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.clear)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                if selectedPage < pages.count - 1 {
                    selectedPage += 1
                } else {
                    onFinish()
                }
            } label: {
                Text(selectedPage == pages.count - 1 ? "Get Started" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .accessibilityIdentifier("onboardingContinueButton")
        }
    }

    private func guidePage(for page: GuidePage) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 30)

            Image(systemName: page.systemImage)
                .font(.system(size: 78))
                .foregroundStyle(.blue)
                .symbolEffect(.bounce, value: selectedPage)

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(page.message)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
        )
    }
}
