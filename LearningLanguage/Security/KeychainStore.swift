import Foundation
import Security

enum KeychainStoreError: Error {
    case unhandledStatus(OSStatus)
    case invalidData
}

protocol KeychainStoring {
    func set(value: String, service: String, account: String) throws
    func get(service: String, account: String) throws -> String?
    func delete(service: String, account: String) throws
}

final class KeychainStore: KeychainStoring {
    func set(value: String, service: String, account: String) throws {
        let data = Data(value.utf8)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        if addStatus == errSecSuccess {
            return
        }

        if addStatus == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]

            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]

            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainStoreError.unhandledStatus(updateStatus)
            }
            return
        }

        throw KeychainStoreError.unhandledStatus(addStatus)
    }

    func get(service: String, account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainStoreError.unhandledStatus(status)
        }

        guard let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            throw KeychainStoreError.invalidData
        }

        return value
    }

    func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }

        throw KeychainStoreError.unhandledStatus(status)
    }
}
