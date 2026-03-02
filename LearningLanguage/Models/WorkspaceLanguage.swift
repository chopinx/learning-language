import Foundation

enum WorkspaceLanguage: String, CaseIterable, Codable, Identifiable {
    case english
    case spanish
    case japanese
    case german

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .spanish:
            return "Spanish"
        case .japanese:
            return "Japanese"
        case .german:
            return "German"
        }
    }

    var shortCode: String {
        switch self {
        case .english:
            return "EN"
        case .spanish:
            return "ES"
        case .japanese:
            return "JP"
        case .german:
            return "DE"
        }
    }

    var deepgramLanguageCode: String {
        switch self {
        case .english:
            return "en"
        case .spanish:
            return "es"
        case .japanese:
            return "ja"
        case .german:
            return "de"
        }
    }

    var deepgramTTSModel: String {
        switch self {
        case .english:
            return "aura-2-thalia-en"
        case .spanish:
            return "aura-2-thalia-en"
        case .japanese:
            return "aura-2-thalia-en"
        case .german:
            return "aura-2-viktoria-de"
        }
    }
}
