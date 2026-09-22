import Testing
@testable import Design

struct FeedbackEventTests {
    /// PRD §10.4 — "Correct/Skip differ by position, haptic, sound, and
    /// icon, not just green/red." This is the haptic half of that promise:
    /// they must never share a style.
    @Test func correctAndSkipUseDistinctHapticsAndChimes() {
        #expect(FeedbackEvent.correct.haptic != FeedbackEvent.skip.haptic)
        #expect(FeedbackEvent.correct.chime != FeedbackEvent.skip.chime)
    }

    @Test func correctIsHeavyImpactWithAscendingChime() {
        #expect(FeedbackEvent.correct.haptic == .impactHeavy)
        #expect(FeedbackEvent.correct.chime == .ascending)
    }

    @Test func skipIsErrorNotificationWithLowBuzz() {
        #expect(FeedbackEvent.skip.haptic == .notificationError)
        #expect(FeedbackEvent.skip.chime == .lowBuzz)
    }

    @Test func finalCountdownTickCarriesItsOwnSecondCount() {
        let event = FeedbackEvent.finalCountdownTick(secondsRemaining: 3)
        guard case .escalatingTick(let seconds) = event.haptic else {
            Issue.record("expected an escalating tick haptic")
            return
        }
        #expect(seconds == 3)
    }
}
