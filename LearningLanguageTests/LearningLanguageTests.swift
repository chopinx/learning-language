import Foundation
import Testing
@testable import LearningLanguage

struct LearningLanguageTests {

    @Test
    func keychainStoreSetAndGetRoundTrip() throws {
        let store = KeychainStore()
        let service = "learning-language-tests-\(UUID().uuidString)"
        let account = "api-key-\(UUID().uuidString)"
        defer { try? store.delete(service: service, account: account) }

        try store.set(value: "dg_live_roundtrip", service: service, account: account)

        let loaded = try store.get(service: service, account: account)
        #expect(loaded == "dg_live_roundtrip")
    }

    @Test
    func keychainStoreSetUpdatesExistingValue() throws {
        let store = KeychainStore()
        let service = "learning-language-tests-\(UUID().uuidString)"
        let account = "api-key-\(UUID().uuidString)"
        defer { try? store.delete(service: service, account: account) }

        try store.set(value: "dg_live_old_value", service: service, account: account)
        try store.set(value: "dg_live_new_value", service: service, account: account)

        let loaded = try store.get(service: service, account: account)
        #expect(loaded == "dg_live_new_value")
    }

    @Test
    func keychainStoreDeleteRemovesStoredValue() throws {
        let store = KeychainStore()
        let service = "learning-language-tests-\(UUID().uuidString)"
        let account = "api-key-\(UUID().uuidString)"

        try store.set(value: "dg_live_delete", service: service, account: account)
        try store.delete(service: service, account: account)

        let loaded = try store.get(service: service, account: account)
        #expect(loaded == nil)
    }

    @Test
    @MainActor
    func apiKeyManagerSavesAndLoadsUsingKeychainStore() {
        let keychain = InMemoryKeychainStore()

        let manager = APIKeyManager(
            keychainStore: keychain,
            validator: MockDeepgramClient()
        )
        manager.saveKey("any-string-is-allowed")

        #expect(manager.savedKey == "any-string-is-allowed")
        #expect(manager.validationState == .valid(message: "API key saved"))

        let reloaded = APIKeyManager(
            keychainStore: keychain,
            validator: MockDeepgramClient()
        )
        #expect(reloaded.savedKey == "any-string-is-allowed")
    }

    @Test
    @MainActor
    func apiKeyManagerClearRemovesStoredKey() {
        let keychain = InMemoryKeychainStore()
        let manager = APIKeyManager(
            keychainStore: keychain,
            validator: MockDeepgramClient()
        )
        manager.saveKey("temp-value")
        manager.clearKey()

        #expect(manager.savedKey == nil)
        #expect(manager.storedKey.isEmpty)

        let reloaded = APIKeyManager(
            keychainStore: keychain,
            validator: MockDeepgramClient()
        )
        #expect(reloaded.savedKey == nil)
    }

    @Test
    func transcriptDifferFindsCorrectAndMissingWords() {
        let source = "kyo wa densha de eki made ikimasu"
        let user = "kyo wa de eki made"

        let result = TranscriptDiffer.compare(source: source, user: user)

        #expect(result.summary.correctCount == 5) // kyo, wa, de, eki, made
        #expect(result.summary.missingCount == 2) // densha, ikimasu
        #expect(result.summary.wrongCount == 0)
        #expect(result.summary.extraCount == 0)
    }

    @Test
    func transcriptDifferIgnoresCaseAndPunctuationNoise() {
        let source = "Hello, WORLD!"
        let user = "hello world"

        let result = TranscriptDiffer.compare(source: source, user: user)

        #expect(result.summary.correctCount == 2)
        #expect(result.summary.missingCount == 0)
    }

    @Test
    func transcriptDifferFuzzyMatchesAt70Percent() {
        // "densh" vs "densha" → LCS "densh" = 5/6 = 83% → match
        #expect(TranscriptDiffer.fuzzyMatch("densh", "densha") == true)

        // "den" vs "densha" → LCS "den" = 3/6 = 50% → no match
        #expect(TranscriptDiffer.fuzzyMatch("den", "densha") == false)

        // exact match
        #expect(TranscriptDiffer.fuzzyMatch("hello", "hello") == true)

        // completely different
        #expect(TranscriptDiffer.fuzzyMatch("abc", "xyz") == false)
    }

    @Test
    func transcriptDifferLCSFindsSkippedWords() {
        // User skips first word but says the rest — LCS should match b, c, d
        let source = "a b c d"
        let user = "b c d"

        let result = TranscriptDiffer.compare(source: source, user: user)

        #expect(result.summary.correctCount == 3) // b, c, d
        #expect(result.summary.missingCount == 1) // a
    }

    @Test
    func transcriptDifferLCSHandlesOutOfOrderWords() {
        // User says words in different order — LCS finds best subsequence
        let source = "one two three four five"
        let user = "one three five"

        let result = TranscriptDiffer.compare(source: source, user: user)

        #expect(result.summary.correctCount == 3) // one, three, five
        #expect(result.summary.missingCount == 2) // two, four
    }

    @Test
    func transcriptDifferPerfectMatch() {
        let source = "hello world"
        let user = "hello world"

        let result = TranscriptDiffer.compare(source: source, user: user)

        #expect(result.summary.correctCount == 2)
        #expect(result.summary.missingCount == 0)
    }

    @Test
    func transcriptDifferAllMissing() {
        let source = "hello world"
        let user = ""

        let result = TranscriptDiffer.compare(source: source, user: user)

        #expect(result.summary.correctCount == 0)
        #expect(result.summary.missingCount == 2)
    }

    @Test
    func transcriptDifferFuzzyMatchInContext() {
        // "ikimas" is close enough to "ikimasu" (6/7 = 86%)
        let source = "kyo wa ikimasu"
        let user = "kyo wa ikimas"

        let result = TranscriptDiffer.compare(source: source, user: user)

        #expect(result.summary.correctCount == 3) // all match fuzzy
        #expect(result.summary.missingCount == 0)
    }

    @Test
    func learningSessionStoreKeepsWorkspaceDataIsolated() {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("learning-language-tests-\(UUID().uuidString)", isDirectory: true)

        defer { try? fileManager.removeItem(at: tempDir) }

        let store = LearningSessionStore(fileManager: fileManager, baseDirectoryURL: tempDir)

        let japaneseSession = LearningSession.demo(
            language: .japanese,
            title: "JP Session",
            sentenceTexts: ["a", "b", "c"],
            currentSentence: 1,
            completedCount: 1
        )

        let spanishSession = LearningSession.demo(
            language: .spanish,
            title: "ES Session",
            sentenceTexts: ["uno", "dos"],
            currentSentence: 0,
            completedCount: 0
        )

        store.saveSessions([japaneseSession], for: .japanese)
        store.saveSessions([spanishSession], for: .spanish)

        let loadedJapanese = store.loadSessions(for: .japanese)
        let loadedSpanish = store.loadSessions(for: .spanish)

        #expect(loadedJapanese.count == 1)
        #expect(loadedSpanish.count == 1)
        #expect(loadedJapanese.first?.title == "JP Session")
        #expect(loadedSpanish.first?.title == "ES Session")

        let japaneseState = LanguageWorkspaceState(
            languageCode: WorkspaceLanguage.japanese.rawValue,
            lastOpenedSessionID: japaneseSession.id,
            showOriginalByDefault: false,
            updatedAt: Date()
        )

        store.saveWorkspaceState(japaneseState, for: .japanese)

        let loadedJapaneseState = store.loadWorkspaceState(for: .japanese)
        let loadedSpanishState = store.loadWorkspaceState(for: .spanish)

        #expect(loadedJapaneseState.showOriginalByDefault == false)
        #expect(loadedJapaneseState.lastOpenedSessionID == japaneseSession.id)
        #expect(loadedSpanishState.showOriginalByDefault == true)
        #expect(loadedSpanishState.lastOpenedSessionID == nil)
    }

    @Test
    func learningSessionStorePersistsWorkspaceConfig() {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("learning-language-workspace-config-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        let store = LearningSessionStore(fileManager: fileManager, baseDirectoryURL: tempDir)
        let config = WorkspaceConfig(
            activeWorkspaces: [.english, .japanese],
            defaultWorkspace: .english,
            hasSeenOnboarding: true
        )

        store.saveWorkspaceConfig(config)
        let loaded = store.loadWorkspaceConfig()

        #expect(loaded.activeWorkspaces == [.english, .japanese])
        #expect(loaded.defaultWorkspace == .english)
        #expect(loaded.hasSeenOnboarding == true)
    }

    @Test
    func workspaceConfigDecodingDefaultsOnboardingFlagForLegacyPayload() throws {
        let legacyPayload = """
        {
          "activeWorkspaces": ["japanese"],
          "defaultWorkspace": "japanese",
          "updatedAt": "2026-03-01T00:00:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try #require(legacyPayload.data(using: .utf8))
        let decoded = try decoder.decode(WorkspaceConfig.self, from: data)

        #expect(decoded.activeWorkspaces == [.japanese])
        #expect(decoded.defaultWorkspace == .japanese)
        #expect(decoded.hasSeenOnboarding == false)
    }

    @Test
    func sentenceSegmenterUsesUtterancesWhenAvailable() {
        let result = DeepgramTranscriptionResult(
            transcript: "fallback transcript",
            utterances: [
                DeepgramUtterance(transcript: "Hello world.", startSec: 0, endSec: 1.2),
                DeepgramUtterance(transcript: "How are you?", startSec: 1.3, endSec: 2.4)
            ]
        )

        let slices = SentenceSegmenter.segment(result: result)

        #expect(slices.count == 2)
        #expect(slices[0].text == "Hello world.")
        #expect(slices[0].startSec == 0)
        #expect(slices[0].endSec == 1.2)
        #expect(slices[1].text == "How are you?")
    }

    @Test
    func sentenceSegmenterMergesUtterancesAtSentenceBoundary() {
        // Two utterances form one sentence — should merge
        let utterances = [
            DeepgramUtterance(transcript: "Hello", startSec: 0, endSec: 0.5),
            DeepgramUtterance(transcript: "world.", startSec: 0.6, endSec: 1.2),
            DeepgramUtterance(transcript: "How are you?", startSec: 1.3, endSec: 2.4)
        ]

        let slices = SentenceSegmenter.mergeUtterancesAtSentenceBoundaries(utterances)

        #expect(slices.count == 2)
        #expect(slices[0].text == "Hello world.")
        #expect(slices[0].startSec == 0)
        #expect(slices[0].endSec == 1.2)
        #expect(slices[1].text == "How are you?")
        #expect(slices[1].startSec == 1.3)
    }

    @Test
    func sentenceSegmenterMergesMultipleUtterancesIntoOneSentence() {
        // Three utterances, no sentence-ending punctuation until the last
        let utterances = [
            DeepgramUtterance(transcript: "I went", startSec: 0, endSec: 1.0),
            DeepgramUtterance(transcript: "to the", startSec: 1.1, endSec: 2.0),
            DeepgramUtterance(transcript: "store.", startSec: 2.1, endSec: 3.0)
        ]

        let slices = SentenceSegmenter.mergeUtterancesAtSentenceBoundaries(utterances)

        #expect(slices.count == 1)
        #expect(slices[0].text == "I went to the store.")
        #expect(slices[0].startSec == 0)
        #expect(slices[0].endSec == 3.0)
    }

    @Test
    func sentenceSegmenterHandlesNoPunctuationInUtterances() {
        // No sentence-ending punctuation — everything becomes one segment
        let utterances = [
            DeepgramUtterance(transcript: "hello", startSec: 0, endSec: 0.5),
            DeepgramUtterance(transcript: "world", startSec: 0.6, endSec: 1.0)
        ]

        let slices = SentenceSegmenter.mergeUtterancesAtSentenceBoundaries(utterances)

        #expect(slices.count == 1)
        #expect(slices[0].text == "hello world")
    }

    @Test
    func sentenceSegmenterMergesShortSentencesByDuration() {
        let slices = [
            SentenceSlice(text: "Hi.", startSec: 0, endSec: 1.0),       // 1s — short
            SentenceSlice(text: "Hello.", startSec: 1.1, endSec: 2.0),  // 0.9s — short
            SentenceSlice(text: "How are you doing today?", startSec: 2.1, endSec: 7.0)  // 4.9s
        ]

        let merged = SentenceSegmenter.mergeShortSegments(slices, minDuration: 5.0)

        // First two merge with third: "Hi. Hello. How are you doing today?" (0-7s = 7s ≥ 5s)
        #expect(merged.count == 1)
        #expect(merged[0].text == "Hi. Hello. How are you doing today?")
        #expect(merged[0].startSec == 0)
        #expect(merged[0].endSec == 7.0)
    }

    @Test
    func sentenceSegmenterFullPipelineMergesUtterancesThenDuration() {
        let result = DeepgramTranscriptionResult(
            transcript: "",
            utterances: [
                DeepgramUtterance(transcript: "Hello.", startSec: 0, endSec: 0.8),
                DeepgramUtterance(transcript: "I am fine.", startSec: 1.0, endSec: 2.5),
                DeepgramUtterance(transcript: "Thank you very much for asking.", startSec: 3.0, endSec: 6.0)
            ]
        )

        // Step 1: merge at sentence boundaries → 3 sentences (each ends with .)
        // Step 2: merge by minDuration=5.0 → "Hello." (0.8s) + "I am fine." (1.5s) = 2.3s < 5s
        //   → merge with next: "Hello. I am fine. Thank you very much for asking." (0-6s = 6s ≥ 5s)
        let slices = SentenceSegmenter.segment(result: result, minDuration: 5.0)

        #expect(slices.count == 1)
        #expect(slices[0].text.contains("Hello."))
        #expect(slices[0].text.contains("Thank you"))
        #expect(slices[0].startSec == 0)
        #expect(slices[0].endSec == 6.0)
    }

    @Test
    func sentenceSegmenterFallsBackToPunctuationSplit() {
        let result = DeepgramTranscriptionResult(
            transcript: "Hello world. This is a test! Last one?",
            utterances: []
        )

        let slices = SentenceSegmenter.segment(result: result)

        #expect(slices.count == 3)
        #expect(slices.map(\.text) == ["Hello world.", "This is a test!", "Last one?"])
        #expect(slices.allSatisfy { $0.startSec == nil && $0.endSec == nil })
    }

    @Test
    func deepgramResponseMapperPrefersUtterancesAndBuildsTranscript() throws {
        let payload = """
        {
          "results": {
            "channels": [
              {
                "alternatives": [
                  { "transcript": "fallback text" }
                ]
              }
            ],
            "utterances": [
              { "transcript": "First sentence.", "start": 0.0, "end": 1.0 },
              { "transcript": "Second sentence.", "start": 1.1, "end": 2.0 }
            ]
          }
        }
        """

        let data = try #require(payload.data(using: .utf8))
        let mapped = try DeepgramResponseMapper.mapListenResponse(data: data)

        #expect(mapped.transcript == "First sentence. Second sentence.")
        #expect(mapped.utterances.count == 2)
        #expect(mapped.utterances[1].transcript == "Second sentence.")
    }

    @Test
    func deepgramResponseMapperFallsBackToChannelTranscript() throws {
        let payload = """
        {
          "results": {
            "channels": [
              {
                "alternatives": [
                  { "transcript": "Single fallback transcript" }
                ]
              }
            ]
          }
        }
        """

        let data = try #require(payload.data(using: .utf8))
        let mapped = try DeepgramResponseMapper.mapListenResponse(data: data)

        #expect(mapped.transcript == "Single fallback transcript")
        #expect(mapped.utterances.isEmpty)
    }

    @Test
    func deepgramFixtureResponseMapsAndSegments() throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/test-audio/deepgram_english_test_response.json")
        let fixtureData = try Data(contentsOf: fixtureURL)
        let mapped = try DeepgramResponseMapper.mapListenResponse(data: fixtureData)
        let slices = SentenceSegmenter.segment(result: mapped)

        #expect(!mapped.transcript.isEmpty)
        #expect(mapped.transcript.contains("English test audio"))
        #expect(!mapped.utterances.isEmpty)
        #expect(!slices.isEmpty)
    }

    @Test
    func learningSessionDecodingDefaultsSourceKindForLegacyPayload() throws {
        let legacyPayload = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "languageCode": "english",
          "title": "Legacy Session",
          "sourceAudioFileName": "legacy.wav",
          "sourceAudioBookmarkData": null,
          "sourceTranscript": "Hello world.",
          "sentences": [
            {
              "id": "00000000-0000-0000-0000-000000000010",
              "text": "Hello world.",
              "startSec": 0,
              "endSec": 1,
              "attempts": []
            }
          ],
          "currentSentenceIndex": 0,
          "completedSentenceIDs": [],
          "createdAt": "2026-02-28T00:00:00Z",
          "updatedAt": "2026-02-28T00:00:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try #require(legacyPayload.data(using: .utf8))
        let decoded = try decoder.decode(LearningSession.self, from: data)

        #expect(decoded.sourceKind == .importedAudio)
    }

    @Test
    @MainActor
    func appViewModelAppliesConditionalWorkspaceSelectionRules() {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("learning-language-workspace-rules-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        let store = LearningSessionStore(fileManager: fileManager, baseDirectoryURL: tempDir)
        store.saveWorkspaceConfig(
            WorkspaceConfig(
                activeWorkspaces: [.japanese],
                defaultWorkspace: .japanese
            )
        )

        let viewModel = AppViewModel(
            store: store,
            deepgramClient: MockDeepgramClient(),
            audioStore: WorkspaceAudioStore(fileManager: fileManager, baseDirectoryURL: tempDir),
            apiKeyManager: APIKeyManager(validator: MockDeepgramClient())
        )

        #expect(viewModel.shouldShowWorkspaceSwitcher == false)
        #expect(viewModel.activeWorkspaces == [.japanese])
        #expect(viewModel.selectedWorkspace == .japanese)

        viewModel.setWorkspaceActive(.english, isActive: true)
        #expect(viewModel.shouldShowWorkspaceSwitcher == true)
        #expect(viewModel.activeWorkspaces == [.japanese, .english])

        viewModel.setDefaultWorkspace(.english)
        #expect(viewModel.selectedWorkspace == .english)
        #expect(viewModel.workspaceConfig.defaultWorkspace == .english)

        viewModel.setWorkspaceActive(.japanese, isActive: false)
        #expect(viewModel.activeWorkspaces == [.english])
        #expect(viewModel.shouldShowWorkspaceSwitcher == false)
        #expect(viewModel.canDeactivateWorkspace(.english) == false)

        viewModel.setWorkspaceActive(.english, isActive: false)
        #expect(viewModel.activeWorkspaces == [.english])
    }

    @Test
    @MainActor
    func appViewModelRestoresWorkspaceFromSavedConfigOnRelaunch() {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("learning-language-workspace-restore-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        let store = LearningSessionStore(fileManager: fileManager, baseDirectoryURL: tempDir)
        let mockClient = MockDeepgramClient()
        let firstLaunch = AppViewModel(
            store: store,
            deepgramClient: mockClient,
            audioStore: WorkspaceAudioStore(fileManager: fileManager, baseDirectoryURL: tempDir),
            apiKeyManager: APIKeyManager(validator: mockClient)
        )

        firstLaunch.setWorkspaceActive(.english, isActive: true)
        firstLaunch.setDefaultWorkspace(.english)

        let secondLaunch = AppViewModel(
            store: store,
            deepgramClient: mockClient,
            audioStore: WorkspaceAudioStore(fileManager: fileManager, baseDirectoryURL: tempDir),
            apiKeyManager: APIKeyManager(validator: mockClient)
        )

        #expect(secondLaunch.selectedWorkspace == .english)
        #expect(secondLaunch.workspaceConfig.defaultWorkspace == .english)
        #expect(secondLaunch.activeWorkspaces.contains(.english))
    }

    @Test
    @MainActor
    func appViewModelMarksOnboardingGuideSeenAndPersists() {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("learning-language-onboarding-flag-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        let store = LearningSessionStore(fileManager: fileManager, baseDirectoryURL: tempDir)
        store.saveWorkspaceConfig(
            WorkspaceConfig(
                activeWorkspaces: [.japanese],
                defaultWorkspace: .japanese,
                hasSeenOnboarding: false
            )
        )

        let viewModel = AppViewModel(
            store: store,
            deepgramClient: MockDeepgramClient(),
            audioStore: WorkspaceAudioStore(fileManager: fileManager, baseDirectoryURL: tempDir),
            apiKeyManager: APIKeyManager(validator: MockDeepgramClient())
        )
        #expect(viewModel.shouldShowOnboardingGuide == true)

        viewModel.markOnboardingGuideSeen()

        #expect(viewModel.shouldShowOnboardingGuide == false)
        #expect(viewModel.workspaceConfig.hasSeenOnboarding == true)

        let relaunched = AppViewModel(
            store: store,
            deepgramClient: MockDeepgramClient(),
            audioStore: WorkspaceAudioStore(fileManager: fileManager, baseDirectoryURL: tempDir),
            apiKeyManager: APIKeyManager(validator: MockDeepgramClient())
        )
        #expect(relaunched.shouldShowOnboardingGuide == false)
        #expect(relaunched.workspaceConfig.hasSeenOnboarding == true)
    }

    @Test
    @MainActor
    func appViewModelCreatesSessionFromTextInputWithGeneratedAudio() async throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("learning-language-text-session-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        let store = LearningSessionStore(fileManager: fileManager, baseDirectoryURL: tempDir)
        let audioStore = WorkspaceAudioStore(fileManager: fileManager, baseDirectoryURL: tempDir)
        let mockClient = MockDeepgramClient()
        let fixtureAudioURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/test-audio/deepgram_english_test.wav")
        let fixtureAudioData = try Data(contentsOf: fixtureAudioURL)
        mockClient.generatedAudioData = fixtureAudioData

        let apiKeyManager = APIKeyManager(
            keychainStore: InMemoryKeychainStore(),
            validator: mockClient
        )
        apiKeyManager.saveKey("dg_test_key_123456789012345")

        let viewModel = AppViewModel(
            store: store,
            deepgramClient: mockClient,
            audioStore: audioStore,
            apiKeyManager: apiKeyManager
        )

        viewModel.setWorkspaceActive(.english, isActive: true)
        viewModel.switchWorkspace(to: .english)

        var pipelineSteps: [AppViewModel.ImportPipelineStep] = []
        let session = try await viewModel.createSessionFromTextInput(
            title: "Generated Test Session",
            sourceText: "Hello world. This is generated.",
            progress: { pipelineSteps.append($0) }
        )

        #expect(pipelineSteps == [.generatingAudio, .preparingSession, .splittingSentences])
        #expect(mockClient.lastGeneratedText == "Hello world. This is generated.")
        #expect(mockClient.lastGeneratedModel == WorkspaceLanguage.english.deepgramTTSModel)
        #expect(mockClient.lastGeneratedAPIKey == "dg_test_key_123456789012345")

        #expect(session.title == "Generated Test Session")
        #expect(session.sourceKind == .generatedFromText)
        #expect(session.sourceTranscript == "Hello world. This is generated.")
        #expect(session.sentences.count == 2)
        #expect(session.sentences.map(\.text) == ["Hello world.", "This is generated."])
        #expect(session.sentences.allSatisfy { $0.startSec != nil && $0.endSec != nil })
        #expect((session.sentences.first?.startSec ?? 1) <= 0.001)
        #expect((session.sentences.first?.endSec ?? 0) > (session.sentences.first?.startSec ?? 0))
        #expect(session.sourceAudioFileName != nil)

        let audioURL = try #require(viewModel.sourceAudioURL(for: session))
        let storedAudio = try Data(contentsOf: audioURL)
        #expect(storedAudio == fixtureAudioData)
    }

    @Test
    @MainActor
    func appViewModelCreatesSessionFromImportedAudioAndCapturesPipeline() async throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("learning-language-import-session-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let sourceURL = tempDir.appendingPathComponent("source.wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: sourceURL, options: .atomic)

        let store = LearningSessionStore(fileManager: fileManager, baseDirectoryURL: tempDir)
        let audioStore = WorkspaceAudioStore(fileManager: fileManager, baseDirectoryURL: tempDir)
        let mockClient = MockDeepgramClient()
        mockClient.transcriptionResult = DeepgramTranscriptionResult(
            transcript: "First sentence. Second sentence.",
            utterances: [
                DeepgramUtterance(transcript: "First sentence.", startSec: 0, endSec: 1.1),
                DeepgramUtterance(transcript: "Second sentence.", startSec: 1.2, endSec: 2.4)
            ]
        )

        let apiKeyManager = APIKeyManager(
            keychainStore: InMemoryKeychainStore(),
            validator: mockClient
        )
        apiKeyManager.saveKey("dg_test_key_import_1234567890")

        let viewModel = AppViewModel(
            store: store,
            deepgramClient: mockClient,
            audioStore: audioStore,
            apiKeyManager: apiKeyManager
        )

        viewModel.setWorkspaceActive(.english, isActive: true)
        viewModel.switchWorkspace(to: .english)
        viewModel.setMinSentenceDuration(0) // Disable merging for this test

        var pipelineSteps: [AppViewModel.ImportPipelineStep] = []
        let session = try await viewModel.createSessionFromImportedAudio(
            title: "Imported Audio Session",
            sourceFileURL: sourceURL,
            progress: { pipelineSteps.append($0) }
        )

        #expect(pipelineSteps == [.importingAudio, .uploadingAudio, .transcribing, .splittingSentences])
        #expect(session.sourceKind == .importedAudio)
        #expect(session.sentences.map(\.text) == ["First sentence.", "Second sentence."])
        #expect(mockClient.lastTranscribeLanguageCode == WorkspaceLanguage.english.deepgramLanguageCode)
        #expect(mockClient.lastTranscribeAPIKey == "dg_test_key_import_1234567890")

        let storedURL = try #require(viewModel.sourceAudioURL(for: session))
        #expect(fileManager.fileExists(atPath: storedURL.path))
    }

    @Test
    @MainActor
    func appViewModelRestoresLastSessionAndSentenceIndexOnRelaunch() {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("learning-language-relaunch-restore-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        let store = LearningSessionStore(fileManager: fileManager, baseDirectoryURL: tempDir)
        let session = LearningSession.demo(
            language: .english,
            title: "Resume Target",
            sentenceTexts: ["one", "two", "three"],
            currentSentence: 2,
            completedCount: 2
        )

        store.saveWorkspaceConfig(
            WorkspaceConfig(activeWorkspaces: [.english], defaultWorkspace: .english)
        )
        store.saveSessions([session], for: .english)
        store.saveWorkspaceState(
            LanguageWorkspaceState(
                languageCode: WorkspaceLanguage.english.rawValue,
                lastOpenedSessionID: session.id,
                showOriginalByDefault: false,
                updatedAt: Date()
            ),
            for: .english
        )

        let viewModel = AppViewModel(
            store: store,
            deepgramClient: MockDeepgramClient(),
            audioStore: WorkspaceAudioStore(fileManager: fileManager, baseDirectoryURL: tempDir),
            apiKeyManager: APIKeyManager(validator: MockDeepgramClient())
        )

        #expect(viewModel.selectedWorkspace == .english)
        #expect(viewModel.lastOpenedSession?.id == session.id)
        #expect(viewModel.lastOpenedSession?.currentSentenceIndex == 2)
        #expect(viewModel.workspaceState.showOriginalByDefault == false)
    }

    @Test
    @MainActor
    func appViewModelTranscribesRecordingUsingSessionWorkspaceLanguage() async throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("learning-language-transcribe-recording-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let recordingURL = tempDir.appendingPathComponent("recording.m4a")
        try Data([0x00, 0x01, 0x02]).write(to: recordingURL, options: .atomic)

        let store = LearningSessionStore(fileManager: fileManager, baseDirectoryURL: tempDir)
        let mockClient = MockDeepgramClient()
        mockClient.transcriptionResult = DeepgramTranscriptionResult(
            transcript: "hallo welt",
            utterances: []
        )
        let germanSession = LearningSession.demo(
            language: .german,
            title: "German Session",
            sentenceTexts: ["hallo welt"],
            currentSentence: 0,
            completedCount: 0
        )
        store.saveWorkspaceConfig(
            WorkspaceConfig(
                activeWorkspaces: [.english, .german],
                defaultWorkspace: .english
            )
        )
        store.saveSessions([germanSession], for: .german)

        let apiKeyManager = APIKeyManager(
            keychainStore: InMemoryKeychainStore(),
            validator: mockClient
        )
        apiKeyManager.saveKey("dg_test_key_transcribe_123456")

        let viewModel = AppViewModel(
            store: store,
            deepgramClient: mockClient,
            audioStore: WorkspaceAudioStore(fileManager: fileManager, baseDirectoryURL: tempDir),
            apiKeyManager: apiKeyManager
        )

        #expect(viewModel.selectedWorkspace == .english)

        let transcript = try await viewModel.transcribeUserRecording(
            fileURL: recordingURL,
            sessionLanguageCode: germanSession.languageCode
        )
        #expect(transcript == "hallo welt")
        #expect(mockClient.lastTranscribeLanguageCode == WorkspaceLanguage.german.deepgramLanguageCode)
        #expect(mockClient.lastTranscribeAPIKey == "dg_test_key_transcribe_123456")
    }

    // MARK: - Design System Utility Tests

    @Test
    func relativeTimeFormatterReturnsJustNowForRecentDates() {
        let now = Date()
        #expect(RelativeTimeFormatter.string(from: now) == "Just now")
    }

    @Test
    func relativeTimeFormatterReturnsMinutesAgo() {
        let fiveMinAgo = Date(timeIntervalSinceNow: -300)
        #expect(RelativeTimeFormatter.string(from: fiveMinAgo) == "5 min ago")
    }

    @Test
    func relativeTimeFormatterReturnsHoursAgo() {
        let twoHoursAgo = Date(timeIntervalSinceNow: -7200)
        #expect(RelativeTimeFormatter.string(from: twoHoursAgo) == "2h ago")
    }

    @Test
    func relativeTimeFormatterReturnsYesterday() {
        let yesterday = Date(timeIntervalSinceNow: -100_000)
        #expect(RelativeTimeFormatter.string(from: yesterday) == "Yesterday")
    }

    @Test
    func relativeTimeFormatterReturnsDaysAgo() {
        let threeDaysAgo = Date(timeIntervalSinceNow: -259_200)
        #expect(RelativeTimeFormatter.string(from: threeDaysAgo) == "3 days ago")
    }

    @Test
    func fileSizeFormatterFormatsBytes() {
        #expect(FileSizeFormatter.string(from: 500) == "500 B")
        #expect(FileSizeFormatter.string(from: 2048) == "2 KB")
        #expect(FileSizeFormatter.string(from: 1_500_000) == "1 MB")
        #expect(FileSizeFormatter.string(from: 35_000_000) == "33 MB")
    }

    @Test
    func workspaceLanguageShortCodesAreCorrect() {
        #expect(WorkspaceLanguage.english.shortCode == "EN")
        #expect(WorkspaceLanguage.spanish.shortCode == "ES")
        #expect(WorkspaceLanguage.japanese.shortCode == "JP")
        #expect(WorkspaceLanguage.german.shortCode == "DE")
    }

    @Test
    func workspaceLanguageGermanUsesGermanTTSModel() {
        #expect(WorkspaceLanguage.german.deepgramTTSModel == "aura-2-viktoria-de")
    }

    @Test
    @MainActor
    func apiKeyManagerTracksLastValidatedAt() async {
        let keychain = InMemoryKeychainStore()
        let mockClient = MockDeepgramClient()
        let manager = APIKeyManager(
            keychainStore: keychain,
            validator: mockClient
        )

        #expect(manager.lastValidatedAt == nil)

        manager.saveKey("dg_test_validation_timestamp")
        await manager.validateKey("dg_test_validation_timestamp")

        #expect(manager.lastValidatedAt != nil)
    }

    // MARK: - Recording Rejection

    @Test
    @MainActor
    func appViewModelRejectsEmptyRecordingTranscript() async throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("learning-language-empty-recording-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let recordingURL = tempDir.appendingPathComponent("recording.m4a")
        try Data([0x00, 0x01]).write(to: recordingURL, options: .atomic)

        let store = LearningSessionStore(fileManager: fileManager, baseDirectoryURL: tempDir)
        let mockClient = MockDeepgramClient()
        mockClient.transcriptionResult = DeepgramTranscriptionResult(
            transcript: "   ",
            utterances: []
        )

        let apiKeyManager = APIKeyManager(
            keychainStore: InMemoryKeychainStore(),
            validator: mockClient
        )
        apiKeyManager.saveKey("dg_test_key_empty_transcript")

        let viewModel = AppViewModel(
            store: store,
            deepgramClient: mockClient,
            audioStore: WorkspaceAudioStore(fileManager: fileManager, baseDirectoryURL: tempDir),
            apiKeyManager: apiKeyManager
        )

        do {
            _ = try await viewModel.transcribeUserRecording(fileURL: recordingURL)
            #expect(Bool(false))
        } catch {
            #expect(
                error.localizedDescription ==
                    AppViewModel.AppViewModelError.recordingTranscriptEmpty.localizedDescription
            )
        }
    }
}

final class MockDeepgramClient: DeepgramTranscribing {
    var generatedAudioData: Data = Data()
    var transcriptionResult: DeepgramTranscriptionResult = .init(transcript: "", utterances: [])
    var isValidAPIKey: Bool = true
    var transcribeError: Error?

    var lastGeneratedText: String?
    var lastGeneratedAPIKey: String?
    var lastGeneratedModel: String?
    var lastTranscribeFileURL: URL?
    var lastTranscribeAPIKey: String?
    var lastTranscribeLanguageCode: String?

    func transcribeAudio(fileURL: URL, apiKey: String, languageCode: String?) async throws -> DeepgramTranscriptionResult {
        lastTranscribeFileURL = fileURL
        lastTranscribeAPIKey = apiKey
        lastTranscribeLanguageCode = languageCode

        if let transcribeError {
            throw transcribeError
        }

        return transcriptionResult
    }

    func generateSpeechAudio(text: String, apiKey: String, model: String) async throws -> Data {
        lastGeneratedText = text
        lastGeneratedAPIKey = apiKey
        lastGeneratedModel = model
        return generatedAudioData
    }

    func validateAPIKey(_: String) async throws -> Bool {
        isValidAPIKey
    }
}

final class InMemoryKeychainStore: KeychainStoring {
    private var storage: [String: String] = [:]

    func set(value: String, service: String, account: String) throws {
        storage[makeKey(service: service, account: account)] = value
    }

    func get(service: String, account: String) throws -> String? {
        storage[makeKey(service: service, account: account)]
    }

    func delete(service: String, account: String) throws {
        storage.removeValue(forKey: makeKey(service: service, account: account))
    }

    private func makeKey(service: String, account: String) -> String {
        "\(service)::\(account)"
    }
}
