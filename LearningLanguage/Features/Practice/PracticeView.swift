import SwiftUI

struct PracticeView: View {
    @ObservedObject var viewModel: AppViewModel
    let sessionID: UUID

    @StateObject private var audioController = PracticeAudioController()

    @State private var sentenceIndex: Int = 0
    @State private var sliderValue: Double = 0
    @State private var showOriginal: Bool = true
    @State private var userTranscript: String = ""
    @State private var compareResult: DiffResult?
    @State private var isTranscribingRecording = false
    @State private var actionErrorMessage: String?

    private var session: LearningSession? {
        viewModel.session(for: sessionID)
    }

    private var currentSentence: SentenceItem? {
        guard let session, session.sentences.indices.contains(sentenceIndex) else {
            return nil
        }

        return session.sentences[sentenceIndex]
    }

    var body: some View {
        Group {
            if let session {
                ZStack {
                    AppTheme.screenBackground
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Practice")
                                    .font(.largeTitle.weight(.bold))
                                Text("Workspace: \(workspaceName(for: session))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Sentence \(sentenceIndex + 1) of \(session.sentences.count)")
                                    .font(.headline)
                                    .accessibilityIdentifier("sentenceHeader")

                                HStack {
                                    Text("1")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    Slider(value: sliderBinding, in: sliderRange, step: 1)
                                        .accessibilityIdentifier("sentenceSlider")

                                    Text("\(session.sentences.count)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }

                                HStack {
                                    Button("Prev") {
                                        jumpToSentence(max(0, sentenceIndex - 1))
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("prevSentenceButton")

                                    Spacer()

                                    Button("Next") {
                                        jumpToSentence(min(session.sentences.count - 1, sentenceIndex + 1))
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .accessibilityIdentifier("nextSentenceButton")
                                }
                            }
                            .appCard()

                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Original Transcript")
                                        .font(.headline)

                                    Spacer()

                                    Toggle(showOriginal ? "Show" : "Hide", isOn: showOriginalBinding)
                                        .tint(Color(red: 0.08, green: 0.41, blue: 0.46))
                                        .accessibilityIdentifier("showOriginalToggle")
                                }

                                if showOriginal {
                                    Text(currentSentence?.text ?? "")
                                        .font(.body)
                                        .accessibilityIdentifier("originalSentenceText")
                                } else {
                                    Text("Original hidden")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .accessibilityIdentifier("originalHiddenLabel")
                                }
                            }
                            .appCard()

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Practice Audio")
                                    .font(.headline)

                                HStack(spacing: 10) {
                                    Button(audioController.isPlaying ? "Stop Playback" : "Play Sentence") {
                                        togglePlayback()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.large)

                                    if audioController.isRecording {
                                        Button("Stop Recording") {
                                            toggleRecording()
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.large)
                                    } else {
                                        Button("Record") {
                                            toggleRecording()
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.large)
                                    }

                                    Button("Transcribe Recording") {
                                        transcribeLatestRecording()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.large)
                                    .disabled(audioController.latestRecordingURL == nil || isTranscribingRecording)
                                }

                                if isTranscribingRecording {
                                    ProgressView("Transcribing recording...")
                                }
                            }
                            .appCard()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your Transcript")
                                    .font(.headline)

                                TextField("Transcribed user speech", text: $userTranscript, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3 ... 6)
                                    .accessibilityIdentifier("userTranscriptField")

                                Button("Compare With Original") {
                                    runComparison()
                                }
                                .buttonStyle(.bordered)
                                .disabled(userTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .accessibilityIdentifier("compareButton")
                            }
                            .appCard()

                            if let errorMessage = actionErrorMessage ?? audioController.errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }

                            if let result = compareResult {
                                ComparisonResultView(result: result)
                            }
                        }
                        .padding()
                        .padding(.bottom, compareResult == nil ? 24 : 94)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if compareResult != nil {
                        Button("Done and Next") {
                            markDoneAndNext()
                        }
                        .buttonStyle(.plain)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(AppTheme.primaryButton)
                        )
                        .accessibilityIdentifier("doneAndNextButton")
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.clear, Color.white.opacity(0.75)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
                .navigationTitle(session.title)
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    sentenceIndex = session.currentSentenceIndex
                    sliderValue = Double(sentenceIndex)
                    showOriginal = viewModel.workspaceState.showOriginalByDefault
                }
            } else {
                ContentUnavailableView("Session not found", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private var sliderRange: ClosedRange<Double> {
        guard let session, !session.sentences.isEmpty else {
            return 0 ... 0
        }

        return 0 ... Double(session.sentences.count - 1)
    }

    private var sliderBinding: Binding<Double> {
        Binding {
            sliderValue
        } set: { newValue in
            sliderValue = newValue
            jumpToSentence(Int(newValue.rounded()))
        }
    }

    private var showOriginalBinding: Binding<Bool> {
        Binding {
            showOriginal
        } set: { newValue in
            showOriginal = newValue
            viewModel.setShowOriginalByDefault(newValue)
        }
    }

    private func jumpToSentence(_ newIndex: Int) {
        sentenceIndex = newIndex
        sliderValue = Double(newIndex)
        compareResult = nil
        userTranscript = ""
        actionErrorMessage = nil
        audioController.stopPlayback()
        viewModel.updateSessionIndex(sessionID: sessionID, newIndex: newIndex)
    }

    private func togglePlayback() {
        guard let session,
              let sourceURL = viewModel.sourceAudioURL(for: session),
              let sentence = currentSentence
        else {
            actionErrorMessage = "Source audio is not available"
            return
        }

        actionErrorMessage = nil

        if audioController.isPlaying {
            audioController.stopPlayback()
        } else {
            audioController.play(
                sourceURL: sourceURL,
                startSec: sentence.startSec,
                endSec: sentence.endSec
            )
        }
    }

    private func toggleRecording() {
        actionErrorMessage = nil

        if audioController.isRecording {
            audioController.stopRecording()
            return
        }

        Task { @MainActor in
            await audioController.startRecording()
        }
    }

    private func transcribeLatestRecording() {
        guard let recordingURL = audioController.latestRecordingURL else {
            actionErrorMessage = "Record audio first"
            return
        }

        actionErrorMessage = nil
        isTranscribingRecording = true

        Task { @MainActor in
            do {
                let transcript = try await viewModel.transcribeUserRecording(
                    fileURL: recordingURL,
                    sessionLanguageCode: session?.languageCode
                )
                userTranscript = transcript
                isTranscribingRecording = false
            } catch {
                actionErrorMessage = error.localizedDescription
                isTranscribingRecording = false
            }
        }
    }

    private func runComparison() {
        guard let sourceSentence = currentSentence?.text else {
            return
        }

        let result = TranscriptDiffer.compare(source: sourceSentence, user: userTranscript)
        compareResult = result
        viewModel.recordAttempt(
            sessionID: sessionID,
            sentenceIndex: sentenceIndex,
            userTranscript: userTranscript,
            diffResult: result
        )
    }

    private func markDoneAndNext() {
        guard let session else {
            return
        }

        viewModel.markSentenceDoneAndAdvance(sessionID: sessionID, sentenceIndex: sentenceIndex)

        let nextIndex = min(sentenceIndex + 1, session.sentences.count - 1)
        sentenceIndex = nextIndex
        sliderValue = Double(nextIndex)
        compareResult = nil
        userTranscript = ""
        actionErrorMessage = nil
    }

    private func workspaceName(for session: LearningSession) -> String {
        WorkspaceLanguage(rawValue: session.languageCode)?.displayName ?? session.languageCode
    }
}

private struct ComparisonResultView: View {
    let result: DiffResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Comparison")
                .font(.headline)

            HStack(spacing: 10) {
                Label("missing \(result.summary.missingCount)", systemImage: "minus.circle")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.12), in: Capsule())

                Label("wrong \(result.summary.wrongCount)", systemImage: "xmark.circle")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12), in: Capsule())

                Label("extra \(result.summary.extraCount)", systemImage: "plus.circle")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.indigo.opacity(0.12), in: Capsule())
            }

            FlexibleWordWrap(tokens: result.tokens)
        }
        .appCard()
    }
}

private struct FlexibleWordWrap: View {
    let tokens: [DiffToken]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(tokens) { token in
                Text(displayText(for: token))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(color(for: token.kind), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func displayText(for token: DiffToken) -> String {
        switch token.kind {
        case .correct:
            return token.userWord ?? token.sourceWord ?? ""
        case .missing:
            return "[missing: \(token.sourceWord ?? "") ]"
        case .wrong:
            return "[wrong: \(token.sourceWord ?? "") -> \(token.userWord ?? "") ]"
        case .extra:
            return "[extra: \(token.userWord ?? "") ]"
        }
    }

    private func color(for kind: DiffToken.Kind) -> Color {
        switch kind {
        case .correct:
            return .green.opacity(0.14)
        case .missing:
            return .red.opacity(0.14)
        case .wrong:
            return .orange.opacity(0.14)
        case .extra:
            return .indigo.opacity(0.14)
        }
    }
}
