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
    @State private var actionErrorMessage: String?

    // Hold-to-record state
    @State private var isHolding = false
    @State private var isCancelling = false
    @State private var isProcessing = false
    @State private var dragOffset: CGFloat = 0

    private enum PracticeStep: Int, CaseIterable {
        case listen = 0
        case record = 1
        case compare = 2
    }

    private var currentStep: PracticeStep {
        if compareResult != nil { return .compare }
        if isProcessing { return .record }
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
                holdToRecordSection
                errorMessageView
            }
            .padding()
        }
        .overlay {
            if let result = compareResult {
                comparisonPopup(result: result)
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

    // MARK: - Hold-to-Record Section

    private var holdToRecordSection: some View {
        VStack(spacing: 16) {
            Text("Your recording")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.themeTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Waveform + duration while recording
            if audioController.isRecording {
                VStack(spacing: 8) {
                    Text(formattedDuration)
                        .font(.title.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.themeTextPrimary)

                    if !audioController.audioLevels.isEmpty {
                        waveformView
                    }
                }
            }

            // The hold-to-record button
            holdToRecordButton
                .accessibilityIdentifier("recordButton")

            // Caption below button
            recordButtonCaption
        }
        .appCard()
    }

    private var holdToRecordButton: some View {
        let buttonSize: CGFloat = audioController.isRecording && !isCancelling ? 80 : 72

        return ZStack {
            // Background circle
            Circle()
                .fill(buttonFillStyle)
                .frame(width: buttonSize, height: buttonSize)
                .shadow(
                    color: audioController.isRecording && !isCancelling
                        ? Color.themeError.opacity(0.4) : .clear,
                    radius: audioController.isRecording && !isCancelling ? 12 : 0
                )
                .animation(.easeInOut(duration: 0.2), value: audioController.isRecording)
                .animation(.easeInOut(duration: 0.2), value: isCancelling)

            // Icon overlay
            buttonIcon
        }
        .offset(y: audioController.isRecording ? dragOffset : 0)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDragChanged(value)
                }
                .onEnded { _ in
                    handleDragEnded()
                }
        )
        .disabled(isProcessing)
    }

    private var buttonFillStyle: AnyShapeStyle {
        if isProcessing {
            return AnyShapeStyle(Color.themePrimary.opacity(0.5))
        }
        if isCancelling {
            return AnyShapeStyle(Color(.systemGray4))
        }
        if audioController.isRecording {
            return AnyShapeStyle(Color.themeError)
        }
        return AnyShapeStyle(Color.themePrimaryGradient)
    }

    @ViewBuilder
    private var buttonIcon: some View {
        if isProcessing {
            ProgressView()
                .tint(.white)
        } else if isCancelling {
            Image(systemName: "xmark")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
        } else if audioController.isRecording {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .frame(width: 22, height: 22)
        } else {
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var recordButtonCaption: some View {
        if isProcessing {
            Text("Transcribing...")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.themeTextSecondary)
        } else if isCancelling {
            Text("Release to cancel")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.themeError)
        } else if audioController.isRecording {
            VStack(spacing: 8) {
                Text("Release to compare")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.themeTextSecondary)
                HStack(spacing: 6) {
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.bold))
                    Text("Swipe up to cancel")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(Color.themeTextSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color(.systemGray6), in: Capsule())
            }
        } else {
            Text("Hold to record")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.themeTextSecondary)
        }
    }

    private var waveformView: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(audioController.audioLevels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.themeError.opacity(0.8))
                    .frame(width: 3, height: max(4, level * 24))
            }
        }
        .frame(height: 28, alignment: .center)
    }

    private var formattedDuration: String {
        let total = Int(audioController.recordingDuration)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Gesture Handlers

    private func handleDragChanged(_ value: DragGesture.Value) {
        if !audioController.isRecording && !isProcessing {
            // Finger just pressed down — start recording
            startRecording()
            isHolding = true
            dragOffset = 0
            isCancelling = false
            return
        }

        // Track vertical drag
        dragOffset = min(0, value.translation.height)
        isCancelling = value.translation.height < -80
    }

    private func handleDragEnded() {
        guard isHolding else { return }
        isHolding = false

        if isCancelling {
            cancelRecording()
        } else if audioController.isRecording {
            stopAndProcess()
        }

        dragOffset = 0
        isCancelling = false
    }

    private func startRecording() {
        actionErrorMessage = nil
        Task { @MainActor in
            await audioController.startRecording()
        }
    }

    private func cancelRecording() {
        audioController.stopRecording()
        audioController.latestRecordingURL = nil
        audioController.audioLevels = []
        audioController.recordingDuration = 0
    }

    private func stopAndProcess() {
        audioController.stopRecording()
        isProcessing = true

        guard let recordingURL = audioController.latestRecordingURL else {
            actionErrorMessage = "No recording captured"
            isProcessing = false
            return
        }

        Task { @MainActor in
            do {
                let transcript = try await viewModel.transcribeUserRecording(
                    fileURL: recordingURL,
                    sessionLanguageCode: session?.languageCode
                )
                userTranscript = transcript
                isProcessing = false
                runComparison()
            } catch {
                actionErrorMessage = "Transcription failed: \(error.localizedDescription)"
                isProcessing = false
            }
        }
    }

    // MARK: - Comparison Popup

    private func comparisonPopup(result: DiffResult) -> some View {
        let total = result.summary.correctCount + result.summary.missingCount + result.summary.wrongCount + result.summary.extraCount
        let accuracy = total > 0 ? Int(Double(result.summary.correctCount) / Double(total) * 100) : 0
        let isPerfect = result.summary.missingCount == 0 && result.summary.wrongCount == 0 && result.summary.extraCount == 0

        return ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { } // Block taps through

            // Popup card
            VStack(spacing: 20) {
                // Score header
                VStack(spacing: 8) {
                    Text("\(accuracy)%")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(isPerfect ? Color.themeSuccess : Color.themePrimary)

                    if isPerfect {
                        Label("Perfect!", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(Color.themeSuccess)
                    } else {
                        Text("Keep practicing!")
                            .font(.headline)
                            .foregroundStyle(Color.themeTextPrimary)
                    }
                }

                // Inline markup result
                inlineComparisonText(result: result)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        // Retry: clear result, let user try again
                        compareResult = nil
                        userTranscript = ""
                        resetPracticeState()
                    } label: {
                        Label("Retry", systemImage: "arrow.counterclockwise")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.themeTextSecondary)

                    Button {
                        markDoneAndNext()
                    } label: {
                        Label("Next", systemImage: "arrow.right")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.themePrimary)
                    .accessibilityIdentifier("doneAndNextButton")
                }
            }
            .padding(24)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            .padding(.horizontal, 24)
            .accessibilityIdentifier("comparisonCard")
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.spring(duration: 0.3), value: compareResult != nil)
    }

    /// Build an inline attributed text showing the comparison like a teacher markup:
    /// - Correct: plain text
    /// - Missing: (word) in green
    /// - Extra: ~~word~~ strikethrough in purple
    /// - Wrong: ~~wrong~~ (right) strikethrough + parenthesis
    private func inlineComparisonText(result: DiffResult) -> some View {
        var parts: [Text] = []

        for token in result.tokens {
            switch token.kind {
            case .correct:
                let word = token.userWord ?? token.sourceWord ?? ""
                parts.append(Text(word + " ").foregroundColor(Color.themeTextPrimary))

            case .missing:
                let word = token.sourceWord ?? ""
                parts.append(
                    Text("(\(word)) ")
                        .foregroundColor(Color.diffMissingText)
                        .fontWeight(.semibold)
                )

            case .extra:
                let word = token.userWord ?? ""
                parts.append(
                    Text(word + " ")
                        .strikethrough(color: Color.diffExtraText)
                        .foregroundColor(Color.diffExtraText)
                )

            case .wrong:
                let wrong = token.userWord ?? ""
                let right = token.sourceWord ?? ""
                parts.append(
                    Text(wrong)
                        .strikethrough(color: Color.diffWrongText)
                        .foregroundColor(Color.diffWrongText)
                )
                parts.append(
                    Text(" (\(right)) ")
                        .foregroundColor(Color.diffCorrectText)
                        .fontWeight(.semibold)
                )
            }
        }

        let combined = parts.reduce(Text("")) { $0 + $1 }
        return combined
            .font(.body)
            .lineSpacing(6)
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
                } else {
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
        resetPracticeState()
        viewModel.updateSessionIndex(sessionID: sessionID, newIndex: newIndex)
    }

    private func resetPracticeState() {
        compareResult = nil
        userTranscript = ""
        actionErrorMessage = nil
        isProcessing = false
        isHolding = false
        isCancelling = false
        dragOffset = 0
        audioController.stopPlayback()
        audioController.latestRecordingURL = nil
        audioController.audioLevels = []
        audioController.recordingDuration = 0
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
        resetPracticeState()
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
