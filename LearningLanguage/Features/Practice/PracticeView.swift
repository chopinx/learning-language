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

    /// Tracks which step the user is on in the practice flow.
    private enum PracticeStep: Int, CaseIterable {
        case listen = 0
        case record = 1
        case transcribe = 2
        case compare = 3
    }

    private var currentStep: PracticeStep {
        if compareResult != nil { return .compare }
        if isTranscribingRecording { return .transcribe }
        if audioController.latestRecordingURL != nil && !audioController.isRecording { return .transcribe }
        if audioController.isRecording { return .record }
        return .listen
    }

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
        .navigationBarTitleDisplayMode(.inline)
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
                sessionProgressBar(session: session)
                sentenceHeaderSection(session: session)
                sentenceNavigationButtons(session: session)
                stepIndicator
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

    // MARK: - Session Progress Bar

    private func sessionProgressBar(session: LearningSession) -> some View {
        let completed = session.completedSentenceIDs.count
        let total = session.sentences.count
        let progress = total > 0 ? Double(completed) / Double(total) : 0

        return HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    Capsule()
                        .fill(Color.themePrimary)
                        .frame(width: max(0, geo.size.width * progress), height: 6)
                }
            }
            .frame(height: 6)

            Text("\(completed)/\(total) completed")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.themeTextSecondary)
                .fixedSize()
        }
        .accessibilityIdentifier("sessionProgressBar")
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            stepPill(step: .listen, label: "Listen", icon: "play.fill")
            stepConnector(active: currentStep.rawValue >= PracticeStep.record.rawValue)
            stepPill(step: .record, label: "Record", icon: "mic.fill")
            stepConnector(active: currentStep.rawValue >= PracticeStep.transcribe.rawValue)
            stepPill(step: .transcribe, label: "Check", icon: "waveform")
            stepConnector(active: currentStep.rawValue >= PracticeStep.compare.rawValue)
            stepPill(step: .compare, label: "Compare", icon: "checkmark.circle.fill")
        }
        .accessibilityIdentifier("stepIndicator")
    }

    private func stepPill(step: PracticeStep, label: String, icon: String) -> some View {
        let isActive = currentStep.rawValue >= step.rawValue
        let isCurrent = currentStep == step

        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.themePrimary : Color(.systemGray5))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isActive ? .white : Color.themeTextTertiary)
            }
            Text(label)
                .font(.caption2.weight(isCurrent ? .bold : .regular))
                .foregroundStyle(isActive ? Color.themeTextPrimary : Color.themeTextTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func stepConnector(active: Bool) -> some View {
        Rectangle()
            .fill(active ? Color.themePrimary : Color(.systemGray5))
            .frame(height: 2)
            .frame(maxWidth: 24)
            .padding(.bottom, 16)
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
                    .font(.title3)
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
                audioController.isPlaying ? "Stop" : "Play sentence",
                systemImage: audioController.isPlaying ? "stop.fill" : "play.fill"
            )
            .font(.caption.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .tint(audioController.isPlaying ? Color.themeError : Color.themePrimary)
        .accessibilityIdentifier("playSentenceButton")
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
                    Text(audioController.isRecording ? "Recording..." : (audioController.latestRecordingURL != nil ? "Recording ready" : "Tap to record"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(audioController.isRecording ? Color.themeError : Color.themeTextPrimary)

                    if audioController.isRecording {
                        Text(formattedDuration)
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(Color.themeTextPrimary)
                    } else {
                        Text("Clip length: \(formattedDuration)")
                            .font(.caption)
                            .foregroundStyle(Color.themeTextSecondary)
                    }

                    if audioController.isRecording || !audioController.audioLevels.isEmpty {
                        waveformView
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if audioController.latestRecordingURL != nil && !audioController.isRecording && compareResult == nil {
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
                    .accessibilityIdentifier("transcribeButton")
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
                    .fill(audioController.isRecording
                          ? AnyShapeStyle(Color.themeError)
                          : AnyShapeStyle(Color.themePrimaryGradient))

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
            .shadow(color: audioController.isRecording ? Color.themeError.opacity(0.3) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("recordButton")
    }

    private var waveformView: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(audioController.audioLevels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 1)
                    .fill(audioController.isRecording ? Color.themeError.opacity(0.8) : Color.themePrimary)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Comparison")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.themeTextPrimary)

                Spacer()

                if result.summary.missingCount == 0 && result.summary.wrongCount == 0 && result.summary.extraCount == 0 {
                    Label("Perfect!", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.themeSuccess)
                }
            }

            DiffSummaryChips(result: result)

            Text("You said")
                .font(.caption)
                .foregroundStyle(Color.themeTextSecondary)

            FlowLayout(spacing: 6) {
                ForEach(result.tokens) { token in
                    DiffTokenChip(text: displayText(for: token), kind: token.kind)
                }
            }

            if result.summary.missingCount > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Missing words")
                        .font(.caption)
                        .foregroundStyle(Color.themeTextSecondary)
                    FlowLayout(spacing: 6) {
                        ForEach(result.tokens.filter { $0.kind == .missing }) { token in
                            Text(token.sourceWord ?? "")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.diffMissingText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.diffMissingBg, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
        }
        .appCard()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    result.summary.missingCount == 0 && result.summary.wrongCount == 0 && result.summary.extraCount == 0
                    ? Color.themeSuccess.opacity(0.4)
                    : Color.themeWarning.opacity(0.3),
                    lineWidth: 2
                )
        )
        .accessibilityIdentifier("comparisonCard")
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
            if let result = compareResult {
                let total = result.summary.correctCount + result.summary.missingCount + result.summary.wrongCount + result.summary.extraCount
                let accuracy = total > 0 ? Int(Double(result.summary.correctCount) / Double(total) * 100) : 0
                Text("\(accuracy)% accuracy")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.themeTextSecondary)
            }
            Spacer()
            Button {
                markDoneAndNext()
            } label: {
                Label("Done and Next", systemImage: "arrow.right.circle.fill")
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
            VStack(spacing: 8) {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(Color.themeError)

                if msg.contains("Microphone permission") {
                    Button {
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsURL)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.themePrimary)
                } else if msg.contains("failed") || msg.contains("Failed") || msg.contains("error") || msg.contains("Error") {
                    Button {
                        actionErrorMessage = nil
                        audioController.errorMessage = nil
                    } label: {
                        Label("Dismiss", systemImage: "xmark.circle")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.themeTextSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.themeError.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("errorMessageView")
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
        audioController.latestRecordingURL = nil
        audioController.audioLevels = []
        audioController.recordingDuration = 0
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
                actionErrorMessage = "Transcription failed: \(error.localizedDescription)"
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
        audioController.latestRecordingURL = nil
        audioController.audioLevels = []
        audioController.recordingDuration = 0
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
