import Foundation
import Combine

@MainActor
final class APIKeyManager: ObservableObject {
    enum ValidationState: Equatable {
        case unknown
        case valid(message: String)
        case invalid(message: String)
    }

    private let keychainStore: KeychainStoring
    private let validator: DeepgramTranscribing
    private let service = "me.xiao.qinbang.LearningLanguage"
    private let account = "deepgram_api_key"

    @Published private(set) var storedKey: String = ""
    @Published var validationState: ValidationState = .unknown
    @Published var isValidating: Bool = false
    @Published private(set) var lastValidatedAt: Date?

    init(
        keychainStore: KeychainStoring = KeychainStore(),
        validator: DeepgramTranscribing = DeepgramClient()
    ) {
        self.keychainStore = keychainStore
        self.validator = validator
        loadSavedKey()
    }

    var hasSavedKey: Bool {
        savedKey != nil
    }

    var savedKey: String? {
        let trimmed = storedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func saveKey(_ rawInput: String) {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationState = .invalid(message: "API key cannot be empty")
            return
        }

        do {
            try keychainStore.set(value: trimmed, service: service, account: account)
            storedKey = trimmed
            validationState = .valid(message: "API key saved")
        } catch let KeychainStoreError.unhandledStatus(status) {
            validationState = .invalid(message: "Failed to save key (\(status))")
        } catch {
            validationState = .invalid(message: "Failed to save key")
        }
    }

    func clearKey() {
        do {
            try keychainStore.delete(service: service, account: account)
            storedKey = ""
            validationState = .unknown
        } catch let KeychainStoreError.unhandledStatus(status) {
            validationState = .invalid(message: "Failed to clear key (\(status))")
        } catch {
            validationState = .invalid(message: "Failed to clear key")
        }
    }

    func validateKey(_ rawInput: String) async {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyToValidate = trimmed.isEmpty ? savedKey : trimmed
        guard let keyToValidate else {
            validationState = .invalid(message: "API key is empty")
            return
        }

        isValidating = true
        defer { isValidating = false }

        do {
            let isValid = try await validator.validateAPIKey(keyToValidate)
            lastValidatedAt = Date()
            validationState = isValid
                ? .valid(message: "API key validated")
                : .invalid(message: "API key was rejected")
        } catch {
            lastValidatedAt = Date()
            validationState = .invalid(message: "Validation failed: \(error.localizedDescription)")
        }
    }

    private func loadSavedKey() {
        do {
            storedKey = try keychainStore.get(service: service, account: account) ?? ""
            validationState = .unknown
        } catch let KeychainStoreError.unhandledStatus(status) {
            storedKey = ""
            validationState = .invalid(message: "Failed to load key from Keychain (\(status))")
        } catch {
            storedKey = ""
            validationState = .invalid(message: "Failed to load key from Keychain")
        }
    }
}
