import Capture
import Content
import SwiftUI

@main
struct PartyCharadesApp: App {
    init() {
        // PRD §7.2.3 — a crash must never leave footage of someone's friends
        // on the device. Whatever a previous launch left behind goes now.
        ReelStore().purgeAll()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

@MainActor func makeStoreManager() -> StoreManager {
    #if DEBUG
    // UI tests never touch the real Keychain allowance.
    if let allowance = DebugOverrides.allowance {
        return StoreManager(storage: InMemoryAllowanceStorage(allowance))
    }
    #endif
    return StoreManager(storage: KeychainAllowanceStorage())
}

/// PRD §1.2.4 / §8: there is no Duo device-capability key, so this must be a
/// hard failure the app cannot silently swallow — if the bundled JSON is
/// missing or malformed, something is wrong with the build itself, not a
/// runtime condition to degrade from.
func loadBundledContentStoreOrFail() -> ContentStore {
    do {
        return try ContentStore.loadBundled()
    } catch {
        fatalError("Bundled vocabulary.json failed to load: \(error)")
    }
}
