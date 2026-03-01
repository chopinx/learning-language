import Foundation

enum UITestBootstrapper {
    private static let bootstrapFlag = "UITEST_BOOTSTRAP"
    private static let practiceSessionFlag = "UITEST_MODE_PRACTICE_SESSION"
    private static let multiWorkspaceFlag = "UITEST_MODE_MULTI_WORKSPACE"
    private static let showOnboardingFlag = "UITEST_MODE_SHOW_ONBOARDING"

    static func bootstrapIfNeeded(arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard arguments.contains(bootstrapFlag) else {
            return
        }

        let fileManager = FileManager.default
        let baseDirectoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let store = LearningSessionStore(fileManager: fileManager, baseDirectoryURL: baseDirectoryURL)

        resetWorkspaceData(fileManager: fileManager, baseDirectoryURL: baseDirectoryURL)
        seedWorkspaceConfig(store: store, arguments: arguments)

        if arguments.contains(practiceSessionFlag) {
            seedPracticeSession(store: store)
        }
    }

    private static func resetWorkspaceData(fileManager: FileManager, baseDirectoryURL: URL) {
        let workspacesDirectory = baseDirectoryURL.appendingPathComponent("workspaces", isDirectory: true)
        let workspaceConfigFile = baseDirectoryURL.appendingPathComponent("workspace_config.json")

        try? fileManager.removeItem(at: workspacesDirectory)
        try? fileManager.removeItem(at: workspaceConfigFile)
    }

    private static func seedWorkspaceConfig(store: LearningSessionStore, arguments: [String]) {
        let hasSeenOnboarding = !arguments.contains(showOnboardingFlag)

        if arguments.contains(multiWorkspaceFlag) {
            store.saveWorkspaceConfig(
                WorkspaceConfig(
                    activeWorkspaces: [.japanese, .english],
                    defaultWorkspace: .japanese,
                    hasSeenOnboarding: hasSeenOnboarding
                )
            )
            return
        }

        store.saveWorkspaceConfig(
            WorkspaceConfig(
                activeWorkspaces: [.japanese],
                defaultWorkspace: .japanese,
                hasSeenOnboarding: hasSeenOnboarding
            )
        )
    }

    private static func seedPracticeSession(store: LearningSessionStore) {
        let now = Date()
        let sentences = [
            SentenceItem(id: UUID(), text: "hello world", startSec: nil, endSec: nil, attempts: []),
            SentenceItem(id: UUID(), text: "this is sentence two", startSec: nil, endSec: nil, attempts: []),
            SentenceItem(id: UUID(), text: "practice makes progress", startSec: nil, endSec: nil, attempts: [])
        ]

        let session = LearningSession(
            id: UUID(),
            languageCode: WorkspaceLanguage.japanese.rawValue,
            title: "UI Test Practice Session",
            sourceKind: .generatedFromText,
            sourceAudioFileName: nil,
            sourceAudioBookmarkData: nil,
            sourceTranscript: sentences.map(\.text).joined(separator: ". "),
            sentences: sentences,
            currentSentenceIndex: 0,
            completedSentenceIDs: [],
            createdAt: now,
            updatedAt: now
        )

        store.saveSessions([session], for: .japanese)
        store.saveWorkspaceState(
            LanguageWorkspaceState(
                languageCode: WorkspaceLanguage.japanese.rawValue,
                lastOpenedSessionID: session.id,
                showOriginalByDefault: true,
                updatedAt: now
            ),
            for: .japanese
        )
    }
}
