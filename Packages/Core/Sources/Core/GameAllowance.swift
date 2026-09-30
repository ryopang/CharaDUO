import Foundation

/// How many matches the player may start: `freeGames` on install, `packGames`
/// more for each consumable pack bought, or unlimited once. Pure value type —
/// StoreKit and persistence live in the app target and just feed this.
///
/// A "game" is one match started (a Rematch is a new game). It is spent when
/// the match begins, not when it finishes, so quitting mid-round doesn't hand
/// it back.
public struct GameAllowance: Equatable, Codable, Sendable {
    public static let freeGames = 10
    public static let packGames = 10

    public private(set) var gamesPlayed: Int
    public private(set) var purchasedGames: Int
    public var hasUnlimited: Bool
    /// StoreKit transaction IDs already credited. A consumable is granted
    /// before it is finished, so a crash in between redelivers it; this is
    /// what stops that from granting twice.
    public private(set) var grantedTransactionIDs: Set<UInt64>

    public init(
        gamesPlayed: Int = 0,
        purchasedGames: Int = 0,
        hasUnlimited: Bool = false,
        grantedTransactionIDs: Set<UInt64> = []
    ) {
        self.gamesPlayed = gamesPlayed
        self.purchasedGames = purchasedGames
        self.hasUnlimited = hasUnlimited
        self.grantedTransactionIDs = grantedTransactionIDs
    }

    /// Games left, or nil when unlimited.
    public var remaining: Int? {
        hasUnlimited ? nil : max(0, Self.freeGames + purchasedGames - gamesPlayed)
    }

    public var canStartGame: Bool {
        remaining.map { $0 > 0 } ?? true
    }

    /// Spends one game. No-op when unlimited (nothing to count).
    public mutating func recordGameStarted() {
        guard !hasUnlimited else { return }
        gamesPlayed += 1
    }

    /// Credits one `packGames` pack. Returns false if this transaction was
    /// already credited.
    @discardableResult
    public mutating func addPack(transactionID: UInt64) -> Bool {
        guard grantedTransactionIDs.insert(transactionID).inserted else { return false }
        purchasedGames += Self.packGames
        return true
    }
}
