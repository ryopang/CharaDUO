import Content

public enum RoundEventKind: Sendable, Equatable {
    case correct
    case skip
}

public struct RoundEvent: Sendable, Equatable {
    public let word: GameWord
    public let kind: RoundEventKind

    public init(word: GameWord, kind: RoundEventKind) {
        self.word = word
        self.kind = kind
    }
}
