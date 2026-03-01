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
                ZStack {
                    AppTheme.screenBackground
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            headerSection(session: session)
                            sentenceNavigationSection(session: session)
                            originalTranscriptCard
                            recordingCard
                            if let result = compareResult {
                                comparisonCard(result: result)
                            }
                            if let errorMessage = actionErrorMessage ?? audioController.errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .padding(.bottom, compareResult == nil ? 16 : 70)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if compareResult != nil {
                        doneAndNextBar
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

    // MARK: - Header

    private func headerSection(session: LearningSession) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Practice")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Workspace: \(workspaceName(for: session))")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            if let ws = workspace {
                Text(ws.shortCode)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.chipInactiveText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(AppColors.chipInactiveBg, in: Capsule())
            }
        }
    }

    // MARK: - Sentence Navigation

    private func sentenceNavigationSection(session: LearningSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sentence \(sentenceIndex + 1) of \(session.sentences.count)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.textHeading)
                    .accessibilityIdentifier("sentenceHeader")
                Text("Drag the handle to jump")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            customSlider(session: session)

            HStack {
                PillButton("Prev", style: .secondary) {
                    jumpToSentence(max(0, sentenceIndex - 1))
                }
                .accessibilityIdentifier("prevSentenceButton")

                Spacer()

                PillButton("Next", style: .primary) {
                    jumpToSentence(min(session.sentences.count - 1, sentenceIndex + 1))
                }
                .accessibilityIdentifier("nextSentenceButton")
            }
        }
    }

    private func customSlider(session: LearningSession) -> some View {
        HStack(spacing: 8) {
            Text("1")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppColors.chipInactiveText)

            GeometryReader { geo in
                let totalWidth = geo.size.width
                let maxIndex = max(Double(session.sentences.count - 1), 1)
                let fraction = sliderValue / maxIndex
                let thumbX = totalWidth * CGFloat(fraction)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.progressTrack)
                        .frame(height: 10)

                    Capsule()
                        .fill(AppColors.tealAccent)
                        .frame(width: max(0, thumbX), height: 10)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle()
                                .stroke(AppColors.tealAccent, lineWidth: 3)
                        )
                        .offset(x: thumbX - 13)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let newFraction = max(0, min(1, value.location.x / totalWidth))
                                    let newIndex = Double(Int((newFraction * maxIndex).rounded()))
                                    sliderValue = newIndex
                                }
                                .onEnded { _ in
                                    jumpToSentence(Int(sliderValue))
                                }
                        )
                }
                .frame(height: 26)
            }
            .frame(height: 26)
            .accessibilityIdentifier("sentenceSlider")

            Text("\(session.sentences.count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppColors.chipInactiveText)
        }
    }

    // MARK: - Original Transcript Card

    private var originalTranscriptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Original transcript")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.textHeading)

                Spacer()

                showTogglePill
            }

            if showOriginal {
                Text(currentSentence?.text ?? "")
                    .font(.body)
                    .foregroundStyle(AppColors.textHeading)
                    .accessibilityIdentifier("originalSentenceText")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppColors.inputBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppColors.inputBorder, lineWidth: 1)
                            )
                    )
            } else {
                Text("Original hidden")
                    .font(.body)
                    .foregroundStyle(AppColors.textSecondary)
                    .accessibilityIdentifier("originalHiddenLabel")
            }

            playSentenceButton
        }
        .appCard()
    }

    private var showTogglePill: some View {
        Button {
            showOriginal.toggle()
            viewModel.setShowOriginalByDefault(showOriginal)
        } label: {
            HStack(spacing: 6) {
                Text(showOriginal ? "Show" : "Hide")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.chipGreenText)

                Circle()
                    .fill(AppColors.validSuccessIcon)
                    .frame(width: 20, height: 20)
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .padding(.vertical, 4)
            .background(AppColors.chipGreenBg, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("showOriginalToggle")
    }

    private var playSentenceButton: some View {
        Button {
            togglePlayback()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: audioController.isPlaying ? "stop.fill" : "play.fill")
                    .font(.caption2)
                    .foregroundStyle(AppColors.tealAccent)
                Text(audioController.isPlaying ? "Stop playback" : "Play sentence")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.chipInactiveText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppColors.chipInactiveBg, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recording Card

    private var recordingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your recording")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.textHeading)

            HStack(alignment: .center, spacing: 16) {
                micButton

                VStack(alignment: .leading, spacing: 6) {
                    Text(audioController.isRecording ? "Recording..." : "Tap to record")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.textHeading)

                    Text("Clip length: \(formattedDuration)")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)

                    if audioController.isRecording || !audioController.audioLevels.isEmpty {
                        waveformView
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if audioController.latestRecordingURL != nil && !audioController.isRecording {
                HStack {
                    Spacer()
                    PillButton("Transcribe", icon: "waveform", style: .secondary) {
                        transcribeLatestRecording()
                    }
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

    private var micButton: some View {
        Button {
            toggleRecording()
        } label: {
            ZStack {
                Circle()
                    .fill(AppTheme.recordButton)

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
            .frame(width: 80, height: 80)
        }
        .buttonStyle(.plain)
    }

    private var waveformView: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(audioController.audioLevels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 1)
                    .fill(AppColors.tealAccent)
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
                .foregroundStyle(AppColors.textHeading)

            DiffSummaryChips(result: result)

            Text("You said")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            tokenFlowLayout(tokens: result.tokens)
        }
        .appCard()
    }

    private func tokenFlowLayout(tokens: [DiffToken]) -> some View {
        FlowLayout(spacing: 4) {
            ForEach(tokens) { token in
                DiffTokenChip(text: displayText(for: token), kind: token.kind)
            }
        }
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
            PillButton("Done and Next", style: .primary) {
                markDoneAndNext()
            }
            .accessibilityIdentifier("doneAndNextButton")
        }
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

    // MARK: - Bindings & Helpers

    private var sliderRange: ClosedRange<Double> {
        guard let session, !session.sentences.isEmpty else {
            return 0 ... 0
        }

        return 0 ... Double(session.sentences.count - 1)
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
