import SwiftUI
import UniformTypeIdentifiers

struct ImportTranscribeView: View {
    enum SessionCreationMode: String, CaseIterable, Identifiable {
        case importAudio
        case textToAudio

        var id: String { rawValue }

        var title: String {
            switch self {
            case .importAudio:
                return "Import Audio"
            case .textToAudio:
                return "Create from Text"
            }
        }
    }

    @ObservedObject var viewModel: AppViewModel
    let onSessionCreated: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var creationMode: SessionCreationMode = .importAudio
    @State private var showFileImporter = false
    @State private var selectedFileURL: URL?
    @State private var selectedFileName: String = ""
    @State private var selectedFileSize: Int64 = 0
    @State private var sourceText: String = ""
    @State private var sessionTitle: String = ""
    @State private var isProcessing = false
    @State private var activeStep: AppViewModel.ImportPipelineStep?
    @State private var completedSteps: Set<AppViewModel.ImportPipelineStep> = []
    @State private var failedStep: AppViewModel.ImportPipelineStep?
    @State private var errorMessage: String?

    private var hasValidKey: Bool {
        viewModel.apiKeyManager.savedKey?.isEmpty == false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerSection

                        Picker("Mode", selection: $creationMode) {
                            ForEach(SessionCreationMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("creationModePicker")

                        pipelineSection
                            .appCard()

                        sourceInputSection
                            .appCard()

                        if creationMode == .importAudio && selectedFileURL != nil {
                            selectedFileCard
                                .appCard()
                        }

                        sessionTitleCard
                            .appCard()

                        if isProcessing || !completedSteps.isEmpty || failedStep != nil {
                            progressCard
                                .appCard()
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .appCard()
                        }
                    }
                    .padding()
                    .padding(.bottom, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppColors.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    createSession()
                } label: {
                    Text(actionLabel)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppTheme.primaryButton)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .disabled(!canCreateSession)
                .opacity(canCreateSession ? 1 : 0.5)
                .background(Color(.systemGroupedBackground))
                .accessibilityIdentifier("createSessionButton")
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .onChange(of: creationMode) { _, _ in
                resetPipelineState()
                errorMessage = nil
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("New Session")
                    .font(.title.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)

                Text("Workspace: \(viewModel.selectedWorkspace.displayName) \u{2022} Mode: \(creationMode.title)")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)

                if creationMode == .importAudio {
                    Text("Switch mode to \u{201C}Create from Text\u{201D} for TTS generation.")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()

            apiKeyBadge
        }
    }

    private var apiKeyBadge: some View {
        Text(hasValidKey ? "Key valid" : "Key missing")
            .font(.caption2.weight(.bold))
            .foregroundStyle(hasValidKey ? AppColors.chipGreenText : AppColors.diffWrongText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(hasValidKey ? AppColors.chipGreenBg : AppColors.diffWrongBg)
            )
    }

    // MARK: - Pipeline

    private var pipelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pipeline (\(creationMode.title))")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.textHeading)

            pipelineConnector

            HStack(spacing: 0) {
                ForEach(Array(currentPipelineSteps.enumerated()), id: \.offset) { index, step in
                    Text(step.shortLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(stepLabelColor(for: step))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private var pipelineConnector: some View {
        GeometryReader { geo in
            let steps = currentPipelineSteps
            let count = CGFloat(steps.count)
            let circleSize: CGFloat = 24
            let availableWidth = geo.size.width
            let spacing = (availableWidth - circleSize * count) / max(count - 1, 1)

            ZStack(alignment: .leading) {
                // Background connector line
                let firstCenter = circleSize / 2
                let lastCenter = availableWidth - circleSize / 2
                Path { path in
                    path.move(to: CGPoint(x: firstCenter, y: circleSize / 2))
                    path.addLine(to: CGPoint(x: lastCenter, y: circleSize / 2))
                }
                .stroke(AppColors.cardBorder, style: StrokeStyle(lineWidth: 4, lineCap: .round))

                // Active connector line
                if let activeIdx = activeStepIndex {
                    let endX = circleCenter(at: activeIdx, circleSize: circleSize, spacing: spacing)
                    Path { path in
                        path.move(to: CGPoint(x: firstCenter, y: circleSize / 2))
                        path.addLine(to: CGPoint(x: endX, y: circleSize / 2))
                    }
                    .stroke(AppColors.tealAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                } else if !completedSteps.isEmpty {
                    // All completed
                    Path { path in
                        path.move(to: CGPoint(x: firstCenter, y: circleSize / 2))
                        path.addLine(to: CGPoint(x: lastCenter, y: circleSize / 2))
                    }
                    .stroke(AppColors.tealAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                }

                // Step circles
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    let cx = circleCenter(at: index, circleSize: circleSize, spacing: spacing)
                    stepCircle(step: step, number: index + 1)
                        .position(x: cx, y: circleSize / 2)
                }
            }
        }
        .frame(height: 24)
    }

    private func circleCenter(at index: Int, circleSize: CGFloat, spacing: CGFloat) -> CGFloat {
        circleSize / 2 + CGFloat(index) * (circleSize + spacing)
    }

    private var activeStepIndex: Int? {
        guard let active = activeStep else { return nil }
        return currentPipelineSteps.firstIndex(of: active)
    }

    private func stepCircle(step: AppViewModel.ImportPipelineStep, number: Int) -> some View {
        ZStack {
            if completedSteps.contains(step) {
                Circle()
                    .fill(AppColors.tealAccent)
                    .frame(width: 24, height: 24)
                Text("\(number)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            } else if activeStep == step {
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                Circle()
                    .stroke(AppColors.tealAccent, lineWidth: 2)
                    .frame(width: 24, height: 24)
                Text("\(number)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.tealAccent)
            } else {
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                Circle()
                    .stroke(AppColors.cardBorder, lineWidth: 2)
                    .frame(width: 24, height: 24)
                Text("\(number)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private func stepLabelColor(for step: AppViewModel.ImportPipelineStep) -> Color {
        if completedSteps.contains(step) || activeStep == step {
            return AppColors.textHeading
        }
        return AppColors.textSecondary
    }

    // MARK: - Source Input

    private var sourceInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(creationMode == .importAudio ? "Source input" : "Source text")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.textHeading)

            if creationMode == .importAudio {
                importDropArea
            } else {
                TextEditor(text: $sourceText)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(AppColors.inputBg, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppColors.inputBorder, lineWidth: 1)
                    )
                    .accessibilityIdentifier("sourceTextEditor")

                Text("Your text will be converted to practice audio using Deepgram.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private var importDropArea: some View {
        Button {
            showFileImporter = true
        } label: {
            HStack(spacing: 16) {
                Circle()
                    .fill(AppColors.chipInactiveBg)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppColors.tealAccent)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Select Audio File")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.textHeading)
                    Text("Import m4a/mp3/wav or switch to Text mode")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()
            }
            .padding(16)
            .background(AppColors.inputBg, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.inputBorder, style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("selectAudioButton")
    }

    // MARK: - Selected File Card

    private var selectedFileCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected file")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            HStack {
                Text(selectedFileName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.textHeading)
                    .lineLimit(2)

                Spacer()

                if selectedFileSize > 0 {
                    Text(FileSizeFormatter.string(from: selectedFileSize))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.chipGreenText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(AppColors.chipGreenBg)
                        )
                }
            }
        }
    }

    // MARK: - Session Title

    private var sessionTitleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session title")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            TextField("Cafe and train conversation", text: $sessionTitle)
                .textInputAutocapitalization(.sentences)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.textHeading)
                .padding(12)
                .background(AppColors.inputBg, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.inputBorder, lineWidth: 1)
                )
                .accessibilityIdentifier("sessionTitleField")
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current progress")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.textHeading)

            if let activeStep {
                Text(progressStatusText(for: activeStep))
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            } else if failedStep != nil {
                Text("An error occurred")
                    .font(.caption)
                    .foregroundStyle(AppColors.diffMissingText)
            } else if completedSteps.count == currentPipelineSteps.count {
                Text("Complete")
                    .font(.caption)
                    .foregroundStyle(AppColors.validSuccessText)
            }

            progressBar

            Text("\(progressPercentage)%")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppColors.textHeading)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(AppColors.progressTrack)
                .frame(height: 12)

            GeometryReader { geo in
                Capsule()
                    .fill(AppColors.progressFill)
                    .frame(width: max(0, geo.size.width * progressFraction), height: 12)
            }
            .frame(height: 12)
        }
    }

    private var progressFraction: CGFloat {
        let total = currentPipelineSteps.count
        guard total > 0 else { return 0 }
        return CGFloat(completedSteps.count) / CGFloat(total)
    }

    private var progressPercentage: Int {
        Int(progressFraction * 100)
    }

    private func progressStatusText(for step: AppViewModel.ImportPipelineStep) -> String {
        switch step {
        case .importingAudio:
            return "Importing audio file..."
        case .uploadingAudio:
            return "Uploading audio to Deepgram..."
        case .transcribing:
            return "Transcribing audio..."
        case .generatingAudio:
            return "Generating audio from text..."
        case .preparingSession:
            return "Preparing session..."
        case .splittingSentences:
            return "Splitting into sentences..."
        }
    }

    // MARK: - Supporting Properties

    private var currentPipelineSteps: [AppViewModel.ImportPipelineStep] {
        switch creationMode {
        case .importAudio:
            return [.importingAudio, .uploadingAudio, .transcribing, .splittingSentences]
        case .textToAudio:
            return [.generatingAudio, .preparingSession, .splittingSentences]
        }
    }

    private var actionLabel: String {
        switch creationMode {
        case .importAudio:
            return "Transcribe"
        case .textToAudio:
            return "Generate"
        }
    }

    private var canCreateSession: Bool {
        guard !isProcessing else {
            return false
        }

        guard !sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        switch creationMode {
        case .importAudio:
            return selectedFileURL != nil
        case .textToAudio:
            return !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // MARK: - Actions

    private func createSession() {
        isProcessing = true
        errorMessage = nil
        resetPipelineState()

        Task { @MainActor in
            do {
                let session: LearningSession

                switch creationMode {
                case .importAudio:
                    guard let selectedFileURL else {
                        errorMessage = "Pick an audio file first"
                        isProcessing = false
                        return
                    }

                    session = try await viewModel.createSessionFromImportedAudio(
                        title: sessionTitle,
                        sourceFileURL: selectedFileURL,
                        progress: updatePipeline(step:)
                    )
                case .textToAudio:
                    session = try await viewModel.createSessionFromTextInput(
                        title: sessionTitle,
                        sourceText: sourceText,
                        progress: updatePipeline(step:)
                    )
                }

                completedSteps = Set(currentPipelineSteps)
                activeStep = nil
                isProcessing = false

                onSessionCreated(session.id)
                dismiss()
            } catch {
                if let activeStep {
                    failedStep = activeStep
                }
                isProcessing = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func updatePipeline(step: AppViewModel.ImportPipelineStep) {
        if let current = activeStep, current != step {
            completedSteps.insert(current)
        }

        activeStep = step
        failedStep = nil
    }

    private func resetPipelineState() {
        activeStep = nil
        completedSteps.removeAll()
        failedStep = nil
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                errorMessage = "No file selected"
                return
            }

            selectedFileURL = url
            selectedFileName = url.lastPathComponent

            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? Int64 {
                    selectedFileSize = size
                }
            }

            if sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sessionTitle = url.deletingPathExtension().lastPathComponent
            }
        case let .failure(error):
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Pipeline Step Short Labels

private extension AppViewModel.ImportPipelineStep {
    var shortLabel: String {
        switch self {
        case .importingAudio:
            return "Import"
        case .uploadingAudio:
            return "Upload"
        case .transcribing:
            return "Transcribe"
        case .generatingAudio:
            return "Generate"
        case .preparingSession:
            return "Prepare"
        case .splittingSentences:
            return "Sentences"
        }
    }
}
