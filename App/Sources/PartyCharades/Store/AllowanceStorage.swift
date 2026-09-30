import Core
import Foundation
import Security

/// Where the `GameAllowance` lives between launches. The Keychain, not
/// UserDefaults: it survives delete-and-reinstall, so neither the free games
/// nor a pack the player paid for come back or vanish with the app.
@MainActor
protocol AllowanceStorage {
    func load() -> GameAllowance
    func save(_ allowance: GameAllowance)
}

struct KeychainAllowanceStorage: AllowanceStorage {
    private let service = "com.ryopang.partycharades.allowance"
    private let account = "gameAllowance"

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func load() -> GameAllowance {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let allowance = try? JSONDecoder().decode(GameAllowance.self, from: data) else {
            return GameAllowance()
        }
        return allowance
    }

    func save(_ allowance: GameAllowance) {
        guard let data = try? JSONEncoder().encode(allowance) else { return }
        let update = [kSecValueData as String: data]
        if SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}

/// Never touches the Keychain. Used by UI tests, which would otherwise burn
/// through the real free games on the simulator.
final class InMemoryAllowanceStorage: AllowanceStorage {
    private var allowance: GameAllowance

    init(_ allowance: GameAllowance = GameAllowance()) { self.allowance = allowance }

    func load() -> GameAllowance { allowance }
    func save(_ allowance: GameAllowance) { self.allowance = allowance }
}
