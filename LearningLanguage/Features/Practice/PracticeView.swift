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

    private var workspace: WorkspaceLanguage? {
        guard let session else { return nil }
        return WorkspaceLanguage(rawValue: session.languageCode)
    }

    var body: some View {
        Group {
            if let session {
                practiceContent(session: session)
                    .onAppear {
                        sentenceIndex = session.currentSentenceIndex
                        sliderValue = Double(sentenceIndex)
                        showOriginal = viewModel.workspaceState.showOriginalByDefault
                        viewModel.setLastOpenedSession(sessionID)
                    }
            } else {
                ContentUnavailableView("Session not found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let ws = workspace {
                    ChipView(
                        text: ws.shortCode,
                        foregroundColor: .themePrimary,
                        backgroundColor: .themePrimary.opacity(0.12)
                    )
                }
            }
        }
    }

    // MARK: - Main Content

    private func practiceContent(session: LearningSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sentenceHeaderSection(session: session)
                sentenceNavigationButtons(session: session)
                originalTranscriptCard
                recordingCard
                if let result = compareResult {
                    comparisonCard(result: result)
                }
                errorMessageView
            }
            .padding()
            .padding(.bottom, compareResult == nil ? 0 : 60)
        }
        .safeAreaInset(edge: .bottom) {
            if compareResult != nil {
                doneAndNextBar
            }
        }
    }

    // MARK: - Sentence Header + Slider

    private func sentenceHeaderSection(session: LearningSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sentence \(sentenceIndex + 1) of \(session.sentences.count)")
                .font(.headline)
                .foregroundStyle(Color.themeTextPrimary)
                .accessibilityIdentifier("sentenceHeader")

            if session.sentences.count > 1 {
                Slider(
                    value: $sliderValue,
                    in: 0...Double(session.sentences.count - 1),
                    step: 1
                ) {
                    Text("Sentence")
                } minimumValueLabel: {
                    Text("1").font(.caption2.weight(.semibold)).foregroundStyle(Color.themeTextSecondary)
                } maximumValueLabel: {
                    Text("\(session.sentences.count)").font(.caption2.weight(.semibold)).foregroundStyle(Color.themeTextSecondary)
                } onEditingChanged: { editing in
                    if !editing {
                        jumpToSentence(Int(sliderValue))
                    }
                }
                .tint(Color.themePrimary)
                .accessibilityIdentifier("sentenceSlider")
            }
        }
    }

    // MARK: - Prev / Next Buttons

    private func sentenceNavigationButtons(session: LearningSession) -> some View {
        HStack {
            Button("Prev") {
                jumpToSentence(max(0, sentenceIndex - 1))
            }
            .buttonStyle(.bordered)
            .disabled(sentenceIndex <= 0)
            .accessibilityIdentifier("prevSentenceButton")

            Spacer()

            Button("Next") {
                jumpToSentence(min(session.sentences.count - 1, sentenceIndex + 1))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.themePrimary)
            .disabled(sentenceIndex >= session.sentences.count - 1)
            .accessibilityIdentifier("nextSentenceButton")
        }
    }

    // MARK: - Original Transcript Card

    private var originalTranscriptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Original transcript")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.themeTextPrimary)

                Spacer()

                Toggle(isOn: $showOriginal) {
                    Text(showOriginal ? "Show" : "Hidden")
                        .font(.caption.weight(.semibold))
                }
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Color.themePrimary)
                .accessibilityIdentifier("showOriginalToggle")

                Text(showOriginal ? "Show" : "Hidden")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.themeTextSecondary)
            }

            if showOriginal {
                Text(currentSentence?.text ?? "")
                    .font(.body)
                    .foregroundStyle(Color.themeTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("originalSentenceText")
            } else {
                Text("Original hidden")
                    .font(.body)
                    .foregroundStyle(Color.themeTextTertiary)
                    .accessibilityIdentifier("originalHiddenLabel")
            }

            playSentenceButton
        }
        .appCard()
    }

    private var playSentenceButton: some View {
        Button {
            togglePlayback()
        } label: {
            Label(
                audioController.isPlaying ? "Stop playback" : "Play sentence",
                systemImage: audioController.isPlaying ? "stop.fill" : "play.fill"
            )
            .font(.caption.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .tint(Color.themePrimary)
    }

    // MARK: - Recording Card

    private var recordingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your recording")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.themeTextPrimary)

            HStack(alignment: .center, spacing: 16) {
                recordButton

                VStack(alignment: .leading, spacing: 6) {
                    Text(audioController.isRecording ? "Recording..." : "Tap to record")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.themeTextPrimary)

                    Text("Clip length: \(formattedDuration)")
                        .font(.caption)
                        .foregroundStyle(Color.themeTextSecondary)

                    if audioController.isRecording || !audioController.audioLevels.isEmpty {
                        waveformView
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if audioController.latestRecordingURL != nil && !audioController.isRecording {
                HStack {
                    Spacer()
                    Button {
                        transcribeLatestRecording()
                    } label: {
                        Label("Transcribe", systemImage: "waveform")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.themePrimary)
                    .disabled(isTranscribingRecording)
                }
            }

            if isTranscribingRecording {
                ProgressView("Transcribing recording...")
                    .font(.caption)
            }
        }
        .appCard()
    }

    private var recordButton: some View {
        Button {
            toggleRecording()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.themePrimaryGradient)

                if audioController.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 72, height: 72)
        }
        .buttonStyle(.plain)
    }

    private var waveformView: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(audioController.audioLevels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.themePrimary)
                    .frame(width: 3, height: max(4, level * 24))
            }
        }
        .frame(height: 28, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formattedDuration: String {
        let total = Int(audioController.recordingDuration)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Comparison Card

    private func comparisonCard(result: DiffResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Comparison")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.themeTextPrimary)

            DiffSummaryChips(result: result)

            Text("You said")
                .font(.caption)
                .foregroundStyle(Color.themeTextSecondary)

            FlowLayout(spacing: 4) {
                ForEach(result.tokens) { token in
                    DiffTokenChip(text: displayText(for: token), kind: token.kind)
                }
            }
        }
        .appCard()
    }

    private func displayText(for token: DiffToken) -> String {
        switch token.kind {
        case .correct:
            return token.userWord ?? token.sourceWord ?? ""
        case .missing:
            return token.sourceWord ?? ""
        case .wrong:
            return token.userWord ?? ""
        case .extra:
            return token.userWord ?? ""
        }
    }

    // MARK: - Done and Next

    private var doneAndNextBar: some View {
        HStack {
            Spacer()
            Button {
                markDoneAndNext()
            } label: {
                Text("Done and Next")
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.themePrimary)
            .accessibilityIdentifier("doneAndNextButton")
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Error Message

    @ViewBuilder
    private var errorMessageView: some View {
        if let msg = actionErrorMessage ?? audioController.errorMessage {
            Text(msg)
                .font(.footnote)
                .foregroundStyle(Color.themeError)
        }
    }

    // MARK: - Helpers

    private var sliderRange: ClosedRange<Double> {
        guard let session, !session.sentences.isEmpty else {
            return 0...0
        }
        return 0...Double(session.sentences.count - 1)
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
                runComparison()
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
        guard let session else { return }

        viewModel.markSentenceDoneAndAdvance(sessionID: sessionID, sentenceIndex: sentenceIndex)

        let nextIndex = min(sentenceIndex + 1, session.sentences.count - 1)
        sentenceIndex = nextIndex
        sliderValue = Double(nextIndex)
        compareResult = nil
        userTranscript = ""
        actionErrorMessage = nil
    }
}

// MARK: - Flow Layout for Token Chips

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
