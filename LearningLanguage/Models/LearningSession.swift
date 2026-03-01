import Foundation

enum SessionSourceKind: String, Codable, Hashable {
    case importedAudio
    case generatedFromText
}

struct LearningSession: Codable, Hashable, Identifiable {
    var id: UUID
    var languageCode: String
    var title: String
    var sourceKind: SessionSourceKind
    var sourceAudioFileName: String?
    var sourceAudioBookmarkData: Data?
    var sourceTranscript: String
    var sentences: [SentenceItem]
    var currentSentenceIndex: Int
    var completedSentenceIDs: Set<UUID>
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        languageCode: String,
        title: String,
        sourceKind: SessionSourceKind = .importedAudio,
        sourceAudioFileName: String?,
        sourceAudioBookmarkData: Data?,
        sourceTranscript: String,
        sentences: [SentenceItem],
        currentSentenceIndex: Int,
        completedSentenceIDs: Set<UUID>,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.languageCode = languageCode
        self.title = title
        self.sourceKind = sourceKind
        self.sourceAudioFileName = sourceAudioFileName
        self.sourceAudioBookmarkData = sourceAudioBookmarkData
        self.sourceTranscript = sourceTranscript
        self.sentences = sentences
        self.currentSentenceIndex = currentSentenceIndex
        self.completedSentenceIDs = completedSentenceIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case languageCode
        case title
        case sourceKind
        case sourceAudioFileName
        case sourceAudioBookmarkData
        case sourceTranscript
        case sentences
        case currentSentenceIndex
        case completedSentenceIDs
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        languageCode = try container.decode(String.self, forKey: .languageCode)
        title = try container.decode(String.self, forKey: .title)
        sourceKind = try container.decodeIfPresent(SessionSourceKind.self, forKey: .sourceKind) ?? .importedAudio
        sourceAudioFileName = try container.decodeIfPresent(String.self, forKey: .sourceAudioFileName)
        sourceAudioBookmarkData = try container.decodeIfPresent(Data.self, forKey: .sourceAudioBookmarkData)
        sourceTranscript = try container.decode(String.self, forKey: .sourceTranscript)
        sentences = try container.decode([SentenceItem].self, forKey: .sentences)
        currentSentenceIndex = try container.decode(Int.self, forKey: .currentSentenceIndex)
        completedSentenceIDs = try container.decode(Set<UUID>.self, forKey: .completedSentenceIDs)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    var progress: Double {
        guard !sentences.isEmpty else {
            return 0
        }

        return Double(completedSentenceIDs.count) / Double(sentences.count)
    }
}

struct SentenceItem: Codable, Hashable, Identifiable {
    var id: UUID
    var text: String
    var startSec: Double?
    var endSec: Double?
    var attempts: [SentenceAttempt]
}

struct SentenceAttempt: Codable, Hashable, Identifiable {
    var id: UUID
    var createdAt: Date
    var userTranscript: String
    var diffResult: DiffResult
}

struct LanguageWorkspaceState: Codable, Hashable {
    var languageCode: String
    var lastOpenedSessionID: UUID?
    var showOriginalByDefault: Bool
    var updatedAt: Date
}

extension LearningSession {
    static func demo(language: WorkspaceLanguage, title: String, sentenceTexts: [String], currentSentence: Int, completedCount: Int) -> LearningSession {
        let sentenceItems = sentenceTexts.map {
            SentenceItem(id: UUID(), text: $0, startSec: nil, endSec: nil, attempts: [])
        }

        let doneIDs = Set(sentenceItems.prefix(max(0, min(completedCount, sentenceItems.count))).map(\.id))

        return LearningSession(
            id: UUID(),
            languageCode: language.rawValue,
            title: title,
            sourceKind: .importedAudio,
            sourceAudioFileName: nil,
            sourceAudioBookmarkData: nil,
            sourceTranscript: sentenceTexts.joined(separator: " "),
            sentences: sentenceItems,
            currentSentenceIndex: max(0, min(currentSentence, max(sentenceItems.count - 1, 0))),
            completedSentenceIDs: doneIDs,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
