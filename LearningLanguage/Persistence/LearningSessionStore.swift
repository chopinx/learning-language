import Foundation

final class LearningSessionStore {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let baseDirectoryURL: URL

    init(fileManager: FileManager = .default, baseDirectoryURL: URL? = nil) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.baseDirectoryURL = baseDirectoryURL ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadSessions(for language: WorkspaceLanguage) -> [LearningSession] {
        let fileURL = sessionsFileURL(for: language)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode([LearningSession].self, from: data)
        } catch {
            return []
        }
    }

    func saveSessions(_ sessions: [LearningSession], for language: WorkspaceLanguage) {
        do {
            try ensureWorkspaceDirectory(for: language)
            let data = try encoder.encode(sessions)
            try data.write(to: sessionsFileURL(for: language), options: .atomic)
        } catch {
            print("[LearningSessionStore] Failed to save sessions: \(error)")
        }
    }

    func loadWorkspaceState(for language: WorkspaceLanguage) -> LanguageWorkspaceState {
        let fileURL = workspaceStateFileURL(for: language)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return LanguageWorkspaceState(
                languageCode: language.rawValue,
                lastOpenedSessionID: nil,
                showOriginalByDefault: true,
                updatedAt: Date()
            )
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(LanguageWorkspaceState.self, from: data)
        } catch {
            return LanguageWorkspaceState(
                languageCode: language.rawValue,
                lastOpenedSessionID: nil,
                showOriginalByDefault: true,
                updatedAt: Date()
            )
        }
    }

    func saveWorkspaceState(_ state: LanguageWorkspaceState, for language: WorkspaceLanguage) {
        do {
            try ensureWorkspaceDirectory(for: language)
            let data = try encoder.encode(state)
            try data.write(to: workspaceStateFileURL(for: language), options: .atomic)
        } catch {
            print("[LearningSessionStore] Failed to save workspace state: \(error)")
        }
    }

    func loadWorkspaceConfig() -> WorkspaceConfig {
        let fileURL = workspaceConfigFileURL()

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return WorkspaceConfig.default()
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let config = try decoder.decode(WorkspaceConfig.self, from: data)
            return WorkspaceConfig.normalized(config)
        } catch {
            return WorkspaceConfig.default()
        }
    }

    func saveWorkspaceConfig(_ config: WorkspaceConfig) {
        do {
            try ensureBaseDirectory()
            let data = try encoder.encode(WorkspaceConfig.normalized(config))
            try data.write(to: workspaceConfigFileURL(), options: .atomic)
        } catch {
            print("[LearningSessionStore] Failed to save workspace config: \(error)")
        }
    }

    private func ensureBaseDirectory() throws {
        try fileManager.createDirectory(
            at: baseDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    private func ensureWorkspaceDirectory(for language: WorkspaceLanguage) throws {
        try fileManager.createDirectory(
            at: workspaceDirectory(for: language),
            withIntermediateDirectories: true
        )
    }

    private func sessionsFileURL(for language: WorkspaceLanguage) -> URL {
        workspaceDirectory(for: language).appendingPathComponent("sessions.json")
    }

    private func workspaceStateFileURL(for language: WorkspaceLanguage) -> URL {
        workspaceDirectory(for: language).appendingPathComponent("workspace_state.json")
    }

    private func workspaceConfigFileURL() -> URL {
        baseDirectoryURL.appendingPathComponent("workspace_config.json")
    }

    private func workspaceDirectory(for language: WorkspaceLanguage) -> URL {
        baseDirectoryURL
            .appendingPathComponent("workspaces", isDirectory: true)
            .appendingPathComponent(language.rawValue, isDirectory: true)
    }
}
