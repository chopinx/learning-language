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
    @State private var sourceText: String = ""
    @State private var sessionTitle: String = ""
    @State private var isProcessing = false
    @State private var activeStep: AppViewModel.ImportPipelineStep?
    @State private var completedSteps: Set<AppViewModel.ImportPipelineStep> = []
    @State private var failedStep: AppViewModel.ImportPipelineStep?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
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

                        sessionSection
                            .appCard()

                        statusSection
                            .appCard()

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .appCard()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 96)
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(actionLabel) {
                    createSession()
                }
                .buttonStyle(.plain)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AppTheme.primaryButton)
                )
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .disabled(!canCreateSession)
                .opacity(canCreateSession ? 1 : 0.5)
                .background(
                    LinearGradient(
                        colors: [Color.clear, Color.white.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("New Session")
                .font(.largeTitle.weight(.bold))
            Text("Workspace: \(viewModel.selectedWorkspace.displayName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: viewModel.apiKeyManager.savedKey?.isEmpty == false ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(viewModel.apiKeyManager.savedKey?.isEmpty == false ? .green : .orange)
                Text(viewModel.apiKeyManager.savedKey?.isEmpty == false ? "Key available" : "Key missing")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sourceInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(creationMode == .importAudio ? "Source input" : "Source text")
                .font(.headline)

            if creationMode == .importAudio {
                Button {
                    showFileImporter = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform.badge.plus")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedFileName.isEmpty ? "Select Audio File" : selectedFileName)
                                .font(.body.weight(.semibold))
                                .lineLimit(2)
                            Text("Supported formats: m4a, mp3, wav")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .padding(10)
                .background(Color(red: 0.95, green: 0.97, blue: 0.99), in: RoundedRectangle(cornerRadius: 14))
            } else {
                TextEditor(text: $sourceText)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(red: 0.95, green: 0.97, blue: 0.99), in: RoundedRectangle(cornerRadius: 14))

                Text("Your text will be converted to practice audio using Deepgram.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session")
                .font(.headline)
            TextField("Session title", text: $sessionTitle)
                .textInputAutocapitalization(.sentences)
                .padding(10)
                .background(Color(red: 0.95, green: 0.97, blue: 0.99), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current progress")
                .font(.headline)
            ForEach(currentPipelineSteps, id: \.self) { step in
                HStack(spacing: 8) {
                    Image(systemName: iconName(for: step))
                        .foregroundStyle(color(for: step))
                    Text(step.title)
                        .foregroundStyle(color(for: step))
                    Spacer()
                }
            }
        }
    }

    private var pipelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pipeline (\(creationMode.title))")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(Array(currentPipelineSteps.enumerated()), id: \.offset) { index, step in
                    Circle()
                        .fill(stepCircleColor(for: step))
                        .frame(width: 18, height: 18)
                        .overlay {
                            Text("\(index + 1)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(stepCircleTextColor(for: step))
                        }

                    if index < currentPipelineSteps.count - 1 {
                        Rectangle()
                            .fill(stepConnectorColor(for: step))
                            .frame(height: 3)
                    }
                }
            }

            HStack(alignment: .top, spacing: 8) {
                ForEach(currentPipelineSteps, id: \.self) { step in
                    Text(step.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(color(for: step))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

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

            if sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sessionTitle = url.deletingPathExtension().lastPathComponent
            }
        case let .failure(error):
            errorMessage = error.localizedDescription
        }
    }

    private func iconName(for step: AppViewModel.ImportPipelineStep) -> String {
        if failedStep == step {
            return "xmark.circle.fill"
        }
        if completedSteps.contains(step) {
            return "checkmark.circle.fill"
        }
        if activeStep == step {
            return "hourglass.circle.fill"
        }
        return "circle"
    }

    private func color(for step: AppViewModel.ImportPipelineStep) -> Color {
        if failedStep == step {
            return .red
        }
        if completedSteps.contains(step) {
            return .green
        }
        if activeStep == step {
            return .orange
        }
        return .secondary
    }

    private func stepCircleColor(for step: AppViewModel.ImportPipelineStep) -> Color {
        if completedSteps.contains(step) {
            return Color(red: 0.11, green: 0.42, blue: 0.55)
        }
        if activeStep == step {
            return Color.white
        }
        return Color(red: 0.9, green: 0.93, blue: 0.95)
    }

    private func stepCircleTextColor(for step: AppViewModel.ImportPipelineStep) -> Color {
        if completedSteps.contains(step) {
            return .white
        }
        if activeStep == step {
            return Color(red: 0.11, green: 0.42, blue: 0.55)
        }
        return .secondary
    }

    private func stepConnectorColor(for step: AppViewModel.ImportPipelineStep) -> Color {
        if completedSteps.contains(step) || activeStep == step {
            return Color(red: 0.11, green: 0.42, blue: 0.55)
        }
        return Color(red: 0.82, green: 0.88, blue: 0.91)
    }
}
