public struct TurnResult: Sendable, Equatable {
    public let teamIndex: Int
    public let roundIndex: Int
    public let events: [RoundEvent]
    public let score: Int
    public let deckReshuffled: Bool

    public init(teamIndex: Int, roundIndex: Int, events: [RoundEvent], score: Int, deckReshuffled: Bool) {
        self.teamIndex = teamIndex
        self.roundIndex = roundIndex
        self.events = events
        self.score = score
        self.deckReshuffled = deckReshuffled
    }
}
