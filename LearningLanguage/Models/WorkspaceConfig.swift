import Foundation

struct WorkspaceConfig: Codable, Hashable {
    var activeWorkspaces: [WorkspaceLanguage]
    var defaultWorkspace: WorkspaceLanguage
    var hasSeenOnboarding: Bool
    /// Minimum sentence duration in seconds. Segments shorter than this merge with the next.
    var minSentenceDuration: Double
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case activeWorkspaces
        case defaultWorkspace
        case hasSeenOnboarding
        case minSentenceDuration
        case updatedAt
    }

    init(
        activeWorkspaces: [WorkspaceLanguage],
        defaultWorkspace: WorkspaceLanguage,
        hasSeenOnboarding: Bool = false,
        minSentenceDuration: Double = 5.0,
        updatedAt: Date = Date()
    ) {
        let normalizedActive = WorkspaceConfig.normalizedActiveWorkspaces(from: activeWorkspaces)
        self.activeWorkspaces = normalizedActive
        self.defaultWorkspace = normalizedActive.contains(defaultWorkspace) ? defaultWorkspace : normalizedActive[0]
        self.hasSeenOnboarding = hasSeenOnboarding
        self.minSentenceDuration = minSentenceDuration
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        activeWorkspaces = try container.decode([WorkspaceLanguage].self, forKey: .activeWorkspaces)
        defaultWorkspace = try container.decode(WorkspaceLanguage.self, forKey: .defaultWorkspace)
        hasSeenOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasSeenOnboarding) ?? false
        minSentenceDuration = try container.decodeIfPresent(Double.self, forKey: .minSentenceDuration) ?? 2.0
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(activeWorkspaces, forKey: .activeWorkspaces)
        try container.encode(defaultWorkspace, forKey: .defaultWorkspace)
        try container.encode(hasSeenOnboarding, forKey: .hasSeenOnboarding)
        try container.encode(minSentenceDuration, forKey: .minSentenceDuration)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    static func `default`() -> WorkspaceConfig {
        WorkspaceConfig(
            activeWorkspaces: [.japanese],
            defaultWorkspace: .japanese,
            hasSeenOnboarding: false,
            updatedAt: Date()
        )
    }

    static func normalized(_ config: WorkspaceConfig) -> WorkspaceConfig {
        WorkspaceConfig(
            activeWorkspaces: config.activeWorkspaces,
            defaultWorkspace: config.defaultWorkspace,
            hasSeenOnboarding: config.hasSeenOnboarding,
            minSentenceDuration: config.minSentenceDuration,
            updatedAt: config.updatedAt
        )
    }

    private static func normalizedActiveWorkspaces(from workspaces: [WorkspaceLanguage]) -> [WorkspaceLanguage] {
        var seen: Set<WorkspaceLanguage> = []
        var ordered: [WorkspaceLanguage] = []

        for language in workspaces where !seen.contains(language) {
            seen.insert(language)
            ordered.append(language)
        }

        if ordered.isEmpty {
            ordered = [.japanese]
        }

        return ordered
    }
}
