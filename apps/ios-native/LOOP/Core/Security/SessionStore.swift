import Foundation
import Security

/// Keychain-backed session storage. Tokens never touch UserDefaults or logs.
nonisolated struct SessionStore: Sendable {
    private let service = "com.loop.app.ios.session"
    private let account = "primary"

    func save(_ session: LoopSession) throws {
        try KeychainValueStore(service: service).save(try JSONEncoder().encode(session), account: account)
    }

    func load() -> LoopSession? {
        guard let data = KeychainValueStore(service: service).load(account: account) else { return nil }
        return try? JSONDecoder().decode(LoopSession.self, from: data)
    }

    func clear() {
        KeychainValueStore(service: service).delete(account: account)
    }
}

/// Short-lived PKCE verifier storage survives an app process restart while the
/// system browser is open. The verifier is removed immediately after exchange.
nonisolated struct PKCEVerifierStore: Sendable {
    private let keychain = KeychainValueStore(service: "com.loop.app.ios.pkce")
    private let account = "google-oauth"

    func save(_ verifier: String) throws {
        guard let data = verifier.data(using: .utf8) else { throw LoopError.invalidData }
        try keychain.save(data, account: account)
    }

    func load() -> String? {
        guard let data = keychain.load(account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func clear() { keychain.delete(account: account) }
}

private nonisolated struct KeychainValueStore: Sendable {
    let service: String

    func save(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw LoopError.serviceUnavailable("LOOP couldn't securely store authentication state on this device.")
        }
    }

    func load(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
