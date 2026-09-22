/// PRD §9 — content is modeled as packs from day one so a paid pack later is
/// data, not a refactor. v1 ships a single free pack.
public struct ContentPack: Codable, Sendable, Hashable {
    public let packID: String
    public let price: PackPrice
    public let words: [GameWord]

    public init(packID: String, price: PackPrice, words: [GameWord]) {
        self.packID = packID
        self.price = price
        self.words = words
    }
}

public enum PackPrice: Codable, Sendable, Hashable {
    case free
}
