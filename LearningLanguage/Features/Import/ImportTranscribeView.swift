import SwiftUI
import UniformTypeIdentifiers

struct ImportTranscribeView: View {
    enum SessionCreationMode: String, CaseIterable, Identifiable {
        case importAudio
        case textToAudio

        var id: String { rawValue }

        var title: String {
            switch self {
            case .importAudio: return "Import Audio"
            case .textToAudio: return "Create from Text"
            }
        }
    }

    @ObservedObject var viewModel: AppViewModel
    let onSessionCreated: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var creationMode: SessionCreationMode = .importAudio
    @State private var showFileImporter = false
    @State private var selectedFileURL: URL?
    @State private var selectedFileName = ""
    @State private var selectedFileSize: Int64 = 0
    @State private var sourceText = ""
    @State private var sessionTitle = ""
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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    modePicker

                    pipelineCard

                    sourceInputCard

                    if creationMode == .importAudio, selectedFileURL != nil {
                        selectedFileCard
                    }

                    sessionTitleCard

                    if isProcessing || !completedSteps.isEmpty || failedStep != nil {
                        progressCard
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Color.themeError)
                            .appCard()
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.themeTextSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    apiKeyBadge
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomActionButton
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

    // MARK: - Mode Picker

    private var modePicker: some View {
        Picker("Mode", selection: $creationMode) {
            ForEach(SessionCreationMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("creationModePicker")
    }

    // MARK: - API Key Badge

    private var apiKeyBadge: some View {
        Text(hasValidKey ? "Key valid" : "Key missing")
            .font(.caption2.weight(.bold))
            .foregroundStyle(hasValidKey ? Color.themeSuccess : Color.themeError)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(hasValidKey ? Color.themeSuccess.opacity(0.15) : Color.themeError.opacity(0.15))
            )
    }

    // MARK: - Pipeline Card

    private var pipelineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pipeline (\(creationMode.title))")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.themeTextPrimary)

            pipelineConnector

            HStack(spacing: 0) {
                ForEach(Array(currentPipelineSteps.enumerated()), id: \.offset) { _, step in
                    Text(step.shortLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(stepLabelColor(for: step))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .appCard()
    }

    private var pipelineConnector: some View {
        GeometryReader { geo in
            let steps = currentPipelineSteps
            let count = CGFloat(steps.count)
            let circleSize: CGFloat = 24
            let spacing = (geo.size.width - circleSize * count) / max(count - 1, 1)

            ZStack(alignment: .leading) {
                let firstCenter = circleSize / 2
                let lastCenter = geo.size.width - circleSize / 2

                // Background track
                Path { path in
                    path.move(to: CGPoint(x: firstCenter, y: circleSize / 2))
                    path.addLine(to: CGPoint(x: lastCenter, y: circleSize / 2))
                }
                .stroke(Color.themeBorder, style: StrokeStyle(lineWidth: 4, lineCap: .round))

                // Active track
                if let activeIdx = activeStepIndex {
                    let endX = circleCenter(at: activeIdx, circleSize: circleSize, spacing: spacing)
                    Path { path in
                        path.move(to: CGPoint(x: firstCenter, y: circleSize / 2))
                        path.addLine(to: CGPoint(x: endX, y: circleSize / 2))
                    }
                    .stroke(Color.themePrimary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                } else if !completedSteps.isEmpty, completedSteps.count == steps.count {
                    Path { path in
                        path.move(to: CGPoint(x: firstCenter, y: circleSize / 2))
                        path.addLine(to: CGPoint(x: lastCenter, y: circleSize / 2))
                    }
                    .stroke(Color.themePrimary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
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
                Circle().fill(Color.themePrimary).frame(width: 24, height: 24)
                Text("\(number)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            } else if activeStep == step {
                Circle().fill(Color(.systemBackground)).frame(width: 24, height: 24)
                Circle().stroke(Color.themePrimary, lineWidth: 2).frame(width: 24, height: 24)
                Text("\(number)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.themePrimary)
            } else {
                Circle().fill(Color(.systemBackground)).frame(width: 24, height: 24)
                Circle().stroke(Color.themeBorder, lineWidth: 2).frame(width: 24, height: 24)
                Text("\(number)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.themeTextTertiary)
            }
        }
    }

    private func stepLabelColor(for step: AppViewModel.ImportPipelineStep) -> Color {
        if completedSteps.contains(step) || activeStep == step {
            return .themeTextPrimary
        }
        return .themeTextTertiary
    }

    // MARK: - Source Input

    private var sourceInputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(creationMode == .importAudio ? "Source input" : "Source text")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.themeTextPrimary)

            if creationMode == .importAudio {
                audioDropArea
            } else {
                TextEditor(text: $sourceText)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.themeBorder, lineWidth: 1)
                    )
                    .accessibilityIdentifier("sourceTextEditor")

                Text("Your text will be converted to practice audio using Deepgram.")
                    .font(.caption)
                    .foregroundStyle(Color.themeTextSecondary)
            }
        }
        .appCard()
    }

    private var audioDropArea: some View {
        Button { showFileImporter = true } label: {
            HStack(spacing: 16) {
                Circle()
                    .fill(Color.themePrimary.opacity(0.12))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.themePrimary)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Select Audio File")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.themeTextPrimary)
                    Text("Import m4a/mp3/wav or switch to Text mode")
                        .font(.caption)
                        .foregroundStyle(Color.themeTextSecondary)
                }

                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.themeBorder, style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("selectAudioButton")
    }

    // MARK: - Selected File

    private var selectedFileCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected file")
                .font(.caption)
                .foregroundStyle(Color.themeTextSecondary)

            HStack {
                Text(selectedFileName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.themeTextPrimary)
                    .lineLimit(2)

                Spacer()

                if selectedFileSize > 0 {
                    Text(FileSizeFormatter.string(from: selectedFileSize))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.themeSuccess)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(Color.themeSuccess.opacity(0.15))
                        )
                }
            }
        }
        .appCard()
    }

    // MARK: - Session Title

    private var sessionTitleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session title")
                .font(.caption)
                .foregroundStyle(Color.themeTextSecondary)

            TextField("Cafe and train conversation", text: $sessionTitle)
                .textInputAutocapitalization(.sentences)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.themeTextPrimary)
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.themeBorder, lineWidth: 1)
                )
                .accessibilityIdentifier("sessionTitleField")
        }
        .appCard()
    }

    // MARK: - Progress

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current progress")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.themeTextPrimary)

            if let activeStep {
                Text(activeStep.statusMessage)
                    .font(.caption)
                    .foregroundStyle(Color.themeTextSecondary)
            } else if failedStep != nil {
                Text("An error occurred")
                    .font(.caption)
                    .foregroundStyle(Color.themeError)
            } else if completedSteps.count == currentPipelineSteps.count {
                Text("Complete")
                    .font(.caption)
                    .foregroundStyle(Color.themeSuccess)
            }

            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5)).frame(height: 12)
                GeometryReader { geo in
                    Capsule()
                        .fill(Color.themePrimary)
                        .frame(width: max(0, geo.size.width * progressFraction), height: 12)
                }
                .frame(height: 12)
            }

            Text("\(progressPercentage)%")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.themeTextPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .appCard()
    }

    private var progressFraction: CGFloat {
        let total = currentPipelineSteps.count
        guard total > 0 else { return 0 }
        return CGFloat(completedSteps.count) / CGFloat(total)
    }

    private var progressPercentage: Int {
        Int(progressFraction * 100)
    }

    // MARK: - Bottom Action

    private var bottomActionButton: some View {
        Button { createSession() } label: {
            Text(actionLabel)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Color.themePrimaryGradient, in: RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(.plain)
        .disabled(!canCreateSession)
        .opacity(canCreateSession ? 1 : 0.5)
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
        .accessibilityIdentifier("createSessionButton")
    }

    // MARK: - Computed Properties

    private var currentPipelineSteps: [AppViewModel.ImportPipelineStep] {
        switch creationMode {
        case .importAudio:
            return [.importingAudio, .uploadingAudio, .transcribing, .splittingSentences]
        case .textToAudio:
            return [.generatingAudio, .preparingSession, .splittingSentences]
        }
    }

    private var actionLabel: String {
        creationMode == .importAudio ? "Transcribe" : "Generate"
    }

    private var canCreateSession: Bool {
        guard !isProcessing else { return false }
        guard !sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
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
                    guard let fileURL = selectedFileURL else {
                        errorMessage = "Pick an audio file first"
                        isProcessing = false
                        return
                    }
                    session = try await viewModel.createSessionFromImportedAudio(
                        title: sessionTitle,
                        sourceFileURL: fileURL,
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
                if let current = activeStep {
                    failedStep = current
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

// MARK: - Pipeline Step Helpers

private extension AppViewModel.ImportPipelineStep {
    var shortLabel: String {
        switch self {
        case .importingAudio: return "Import"
        case .uploadingAudio: return "Upload"
        case .transcribing: return "Transcribe"
        case .generatingAudio: return "Generate"
        case .preparingSession: return "Prepare"
        case .splittingSentences: return "Sentences"
        }
    }

    var statusMessage: String {
        switch self {
        case .importingAudio: return "Importing audio file..."
        case .uploadingAudio: return "Uploading audio to Deepgram..."
        case .transcribing: return "Transcribing audio..."
        case .generatingAudio: return "Generating audio from text..."
        case .preparingSession: return "Preparing session..."
        case .splittingSentences: return "Splitting into sentences..."
        }
    }
}
