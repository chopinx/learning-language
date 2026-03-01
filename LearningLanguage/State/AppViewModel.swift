import Foundation
import Combine
import AVFoundation

@MainActor
final class AppViewModel: ObservableObject {
    enum ImportPipelineStep: CaseIterable {
        case importingAudio
        case uploadingAudio
        case transcribing
        case generatingAudio
        case preparingSession
        case splittingSentences

        var title: String {
            switch self {
            case .importingAudio:
                return "Importing audio"
            case .uploadingAudio:
                return "Uploading audio"
            case .transcribing:
                return "Transcribing"
            case .generatingAudio:
                return "Generating audio"
            case .preparingSession:
                return "Preparing session"
            case .splittingSentences:
                return "Splitting sentences"
            }
        }
    }

    enum AppViewModelError: LocalizedError {
        case missingAPIKey
        case missingSessionTitle
        case missingSourceText
        case noSentencesGenerated
        case sessionNotFound
        case recordingTranscriptEmpty

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Set a Deepgram API key in Settings first"
            case .missingSessionTitle:
                return "Session title is required"
            case .missingSourceText:
                return "Source text is required"
            case .noSentencesGenerated:
                return "No sentences were generated from this source"
            case .sessionNotFound:
                return "Session not found"
            case .recordingTranscriptEmpty:
                return "No transcript returned for this recording"
            }
        }
    }

    private let store: LearningSessionStore
    private let deepgramClient: DeepgramTranscribing
    private let audioStore: WorkspaceAudioStore
    let apiKeyManager: APIKeyManager

    @Published var workspaceConfig: WorkspaceConfig
    @Published var selectedWorkspace: WorkspaceLanguage
    @Published var workspaceState: LanguageWorkspaceState
    @Published var sessions: [LearningSession]

    init(
        store: LearningSessionStore = LearningSessionStore(),
        deepgramClient: DeepgramTranscribing = DeepgramClient(),
        audioStore: WorkspaceAudioStore = WorkspaceAudioStore(),
        apiKeyManager: APIKeyManager? = nil
    ) {
        self.store = store
        self.deepgramClient = deepgramClient
        self.audioStore = audioStore
        self.apiKeyManager = apiKeyManager ?? APIKeyManager()

        let loadedWorkspaceConfig = WorkspaceConfig.normalized(store.loadWorkspaceConfig())
        workspaceConfig = loadedWorkspaceConfig
        let initialWorkspace = loadedWorkspaceConfig.defaultWorkspace

        selectedWorkspace = initialWorkspace
        sessions = store.loadSessions(for: initialWorkspace)
        workspaceState = store.loadWorkspaceState(for: initialWorkspace)
        sortSessions()
    }

    var activeWorkspaces: [WorkspaceLanguage] {
        workspaceConfig.activeWorkspaces
    }

    var shouldShowWorkspaceSwitcher: Bool {
        activeWorkspaces.count > 1
    }

    var shouldShowOnboardingGuide: Bool {
        !workspaceConfig.hasSeenOnboarding
    }

    var lastOpenedSession: LearningSession? {
        guard let lastOpenedSessionID = workspaceState.lastOpenedSessionID else {
            return sessions.first
        }

        return sessions.first(where: { $0.id == lastOpenedSessionID }) ?? sessions.first
    }

    func isWorkspaceActive(_ language: WorkspaceLanguage) -> Bool {
        activeWorkspaces.contains(language)
    }

    func canDeactivateWorkspace(_ language: WorkspaceLanguage) -> Bool {
        guard isWorkspaceActive(language) else {
            return true
        }

        return activeWorkspaces.count > 1
    }

    func switchWorkspace(to language: WorkspaceLanguage) {
        guard activeWorkspaces.contains(language) else {
            return
        }

        guard language != selectedWorkspace else {
            if workspaceConfig.defaultWorkspace != language {
                workspaceConfig.defaultWorkspace = language
                workspaceConfig.updatedAt = Date()
                persistWorkspaceConfig()
            }
            return
        }

        persistCurrentWorkspace()

        selectedWorkspace = language
        sessions = store.loadSessions(for: language)
        workspaceState = store.loadWorkspaceState(for: language)

        sortSessions()

        workspaceConfig.defaultWorkspace = language
        workspaceConfig.updatedAt = Date()
        persistWorkspaceConfig()
    }

    func setWorkspaceActive(_ language: WorkspaceLanguage, isActive: Bool) {
        if isActive {
            guard !activeWorkspaces.contains(language) else {
                return
            }

            workspaceConfig.activeWorkspaces.append(language)
            workspaceConfig.updatedAt = Date()
            workspaceConfig = WorkspaceConfig.normalized(workspaceConfig)
            persistWorkspaceConfig()
            return
        }

        guard activeWorkspaces.contains(language) else {
            return
        }

        guard activeWorkspaces.count > 1 else {
            return
        }

        if selectedWorkspace == language {
            persistCurrentWorkspace()
        }

        workspaceConfig.activeWorkspaces.removeAll { $0 == language }
        if workspaceConfig.defaultWorkspace == language {
            workspaceConfig.defaultWorkspace = workspaceConfig.activeWorkspaces[0]
        }

        workspaceConfig.updatedAt = Date()
        workspaceConfig = WorkspaceConfig.normalized(workspaceConfig)
        persistWorkspaceConfig()

        if selectedWorkspace == language {
            selectedWorkspace = workspaceConfig.defaultWorkspace
            sessions = store.loadSessions(for: selectedWorkspace)
            workspaceState = store.loadWorkspaceState(for: selectedWorkspace)
            sortSessions()
        }
    }

    func setDefaultWorkspace(_ language: WorkspaceLanguage) {
        guard activeWorkspaces.contains(language) else {
            return
        }

        switchWorkspace(to: language)
    }

    func markOnboardingGuideSeen() {
        guard !workspaceConfig.hasSeenOnboarding else {
            return
        }

        workspaceConfig.hasSeenOnboarding = true
        workspaceConfig.updatedAt = Date()
        persistWorkspaceConfig()
    }

    func session(for id: UUID) -> LearningSession? {
        sessions.first(where: { $0.id == id })
    }

    func setLastOpenedSession(_ sessionID: UUID) {
        workspaceState.lastOpenedSessionID = sessionID
        workspaceState.updatedAt = Date()
        persistCurrentWorkspace()
    }

    func createSessionFromImportedAudio(
        title: String,
        sourceFileURL: URL,
        progress: ((ImportPipelineStep) -> Void)? = nil
    ) async throws -> LearningSession {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw AppViewModelError.missingSessionTitle
        }

        guard let apiKey = apiKeyManager.savedKey else {
            throw AppViewModelError.missingAPIKey
        }

        let workspace = selectedWorkspace
        let sessionID = UUID()

        progress?(.importingAudio)
        let importedFileName = try audioStore.importAudioFile(
            from: sourceFileURL,
            sessionID: sessionID,
            workspace: workspace
        )

        progress?(.uploadingAudio)
        let importedAudioURL = audioStore.audioFileURL(fileName: importedFileName, workspace: workspace)

        progress?(.transcribing)
        let transcription = try await deepgramClient.transcribeAudio(
            fileURL: importedAudioURL,
            apiKey: apiKey,
            languageCode: workspace.deepgramLanguageCode
        )

        progress?(.splittingSentences)
        let sentenceSlices = SentenceSegmenter.segment(result: transcription)
        guard !sentenceSlices.isEmpty else {
            throw AppViewModelError.noSentencesGenerated
        }

        let now = Date()
        let newSession = LearningSession(
            id: sessionID,
            languageCode: workspace.rawValue,
            title: trimmedTitle,
            sourceKind: .importedAudio,
            sourceAudioFileName: importedFileName,
            sourceAudioBookmarkData: nil,
            sourceTranscript: transcription.transcript,
            sentences: sentenceSlices.map {
                SentenceItem(
                    id: UUID(),
                    text: $0.text,
                    startSec: $0.startSec,
                    endSec: $0.endSec,
                    attempts: []
                )
            },
            currentSentenceIndex: 0,
            completedSentenceIDs: [],
            createdAt: now,
            updatedAt: now
        )

        sessions.append(newSession)
        sortSessions()

        workspaceState.lastOpenedSessionID = newSession.id
        workspaceState.updatedAt = now
        persistCurrentWorkspace()

        return newSession
    }

    func createSessionFromTextInput(
        title: String,
        sourceText: String,
        progress: ((ImportPipelineStep) -> Void)? = nil
    ) async throws -> LearningSession {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw AppViewModelError.missingSessionTitle
        }

        let trimmedText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw AppViewModelError.missingSourceText
        }

        guard let apiKey = apiKeyManager.savedKey else {
            throw AppViewModelError.missingAPIKey
        }

        let workspace = selectedWorkspace
        let sessionID = UUID()

        progress?(.generatingAudio)
        let generatedAudioData = try await deepgramClient.generateSpeechAudio(
            text: trimmedText,
            apiKey: apiKey,
            model: workspace.deepgramTTSModel
        )

        progress?(.preparingSession)
        let generatedFileName = try audioStore.saveGeneratedAudioData(
            generatedAudioData,
            sessionID: sessionID,
            workspace: workspace,
            fileExtension: "wav"
        )
        let generatedAudioURL = audioStore.audioFileURL(fileName: generatedFileName, workspace: workspace)

        progress?(.splittingSentences)
        let sentenceSlices = await sentenceSlicesForGeneratedText(
            text: trimmedText,
            generatedAudioURL: generatedAudioURL
        )
        guard !sentenceSlices.isEmpty else {
            throw AppViewModelError.noSentencesGenerated
        }

        let now = Date()
        let newSession = LearningSession(
            id: sessionID,
            languageCode: workspace.rawValue,
            title: trimmedTitle,
            sourceKind: .generatedFromText,
            sourceAudioFileName: generatedFileName,
            sourceAudioBookmarkData: nil,
            sourceTranscript: trimmedText,
            sentences: sentenceSlices.map {
                SentenceItem(
                    id: UUID(),
                    text: $0.text,
                    startSec: $0.startSec,
                    endSec: $0.endSec,
                    attempts: []
                )
            },
            currentSentenceIndex: 0,
            completedSentenceIDs: [],
            createdAt: now,
            updatedAt: now
        )

        sessions.append(newSession)
        sortSessions()

        workspaceState.lastOpenedSessionID = newSession.id
        workspaceState.updatedAt = now
        persistCurrentWorkspace()

        return newSession
    }

    func sourceAudioURL(for sessionID: UUID) -> URL? {
        guard let session = session(for: sessionID) else {
            return nil
        }

        return sourceAudioURL(for: session)
    }

    func sourceAudioURL(for session: LearningSession) -> URL? {
        guard let fileName = session.sourceAudioFileName else {
            return nil
        }

        let workspace = WorkspaceLanguage(rawValue: session.languageCode) ?? selectedWorkspace
        return audioStore.audioFileURL(fileName: fileName, workspace: workspace)
    }

    func transcribeUserRecording(fileURL: URL, sessionLanguageCode: String? = nil) async throws -> String {
        guard let apiKey = apiKeyManager.savedKey else {
            throw AppViewModelError.missingAPIKey
        }

        let targetWorkspaceLanguage =
            WorkspaceLanguage(rawValue: sessionLanguageCode ?? "") ?? selectedWorkspace

        let transcription = try await deepgramClient.transcribeAudio(
            fileURL: fileURL,
            apiKey: apiKey,
            languageCode: targetWorkspaceLanguage.deepgramLanguageCode
        )

        let cleaned = transcription.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw AppViewModelError.recordingTranscriptEmpty
        }

        return cleaned
    }

    func updateSessionIndex(sessionID: UUID, newIndex: Int) {
        guard let sessionIdx = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return
        }

        guard !sessions[sessionIdx].sentences.isEmpty else {
            return
        }

        let maxIndex = sessions[sessionIdx].sentences.count - 1
        sessions[sessionIdx].currentSentenceIndex = max(0, min(newIndex, maxIndex))
        sessions[sessionIdx].updatedAt = Date()

        workspaceState.lastOpenedSessionID = sessionID
        workspaceState.updatedAt = Date()

        persistCurrentWorkspace()
    }

    func setShowOriginalByDefault(_ show: Bool) {
        workspaceState.showOriginalByDefault = show
        workspaceState.updatedAt = Date()
        persistCurrentWorkspace()
    }

    func recordAttempt(sessionID: UUID, sentenceIndex: Int, userTranscript: String, diffResult: DiffResult) {
        guard let sessionIdx = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return
        }

        guard sessions[sessionIdx].sentences.indices.contains(sentenceIndex) else {
            return
        }

        let attempt = SentenceAttempt(
            id: UUID(),
            createdAt: Date(),
            userTranscript: userTranscript,
            diffResult: diffResult
        )

        sessions[sessionIdx].sentences[sentenceIndex].attempts.append(attempt)
        sessions[sessionIdx].updatedAt = Date()
        persistCurrentWorkspace()
    }

    func markSentenceDoneAndAdvance(sessionID: UUID, sentenceIndex: Int) {
        guard let sessionIdx = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return
        }

        guard sessions[sessionIdx].sentences.indices.contains(sentenceIndex) else {
            return
        }

        let sentenceID = sessions[sessionIdx].sentences[sentenceIndex].id
        sessions[sessionIdx].completedSentenceIDs.insert(sentenceID)

        if sentenceIndex < sessions[sessionIdx].sentences.count - 1 {
            sessions[sessionIdx].currentSentenceIndex = sentenceIndex + 1
        }

        sessions[sessionIdx].updatedAt = Date()
        workspaceState.lastOpenedSessionID = sessionID
        workspaceState.updatedAt = Date()

        persistCurrentWorkspace()
        sortSessions()
    }

    private func sortSessions() {
        sessions.sort { $0.updatedAt > $1.updatedAt }
    }

    private func persistCurrentWorkspace() {
        store.saveSessions(sessions, for: selectedWorkspace)
        store.saveWorkspaceState(workspaceState, for: selectedWorkspace)
    }

    private func persistWorkspaceConfig() {
        store.saveWorkspaceConfig(workspaceConfig)
    }

    private func sentenceSlicesForGeneratedText(text: String, generatedAudioURL: URL) async -> [SentenceSlice] {
        let sentences = SentenceSegmenter.splitByPunctuation(text)
        guard !sentences.isEmpty else {
            return []
        }

        guard let totalDurationSec = await audioDurationSeconds(for: generatedAudioURL),
              totalDurationSec > 0
        else {
            return sentences.map { SentenceSlice(text: $0, startSec: nil, endSec: nil) }
        }

        let weights = sentences.map { sentence in
            let tokenCount = sentence.split(whereSeparator: \.isWhitespace).count
            return max(Double(tokenCount), 1)
        }
        let totalWeight = weights.reduce(0, +)

        var cursor = 0.0
        return sentences.enumerated().map { index, sentence in
            let start = cursor
            let segmentDuration = totalDurationSec * (weights[index] / totalWeight)
            let end = index == sentences.indices.last
                ? totalDurationSec
                : min(totalDurationSec, start + segmentDuration)

            cursor = end
            return SentenceSlice(text: sentence, startSec: start, endSec: end)
        }
    }

    private func audioDurationSeconds(for audioURL: URL) async -> Double? {
        let asset = AVURLAsset(url: audioURL)

        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            guard seconds.isFinite, seconds > 0 else {
                return nil
            }

            return seconds
        } catch {
            return nil
        }
    }
}
