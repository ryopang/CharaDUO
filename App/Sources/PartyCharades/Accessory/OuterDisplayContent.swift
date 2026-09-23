import Core

/// What the outer display draws right now. The accessory scene switches on
/// this rather than owning any screen-routing logic of its own — it just
/// renders whichever read-only projection `AppCoordinator.outerDisplayContent`
/// hands it.
enum OuterDisplayContent: Equatable {
    case liveRound(ScoreboardSnapshot)
    case roundSummary(RoundSummarySnapshot)
    case matchEnd(MatchEndSnapshot)
}
