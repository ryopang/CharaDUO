import Testing
@testable import Posture

struct PostureResolverTests {
    @Test func closedHingeIsTheOnlyPausingPosture() {
        #expect(PostureResolver.resolve(status: .closed, angleDegrees: 0) == .closed)
    }

    @Test func tabletopBandMatchesThePRDRange() {
        #expect(PostureResolver.resolve(status: .partiallyOpen, angleDegrees: 75) == .tabletop)
        #expect(PostureResolver.resolve(status: .partiallyOpen, angleDegrees: 90) == .tabletop)
        #expect(PostureResolver.resolve(status: .partiallyOpen, angleDegrees: 115) == .tabletop)
    }

    @Test func partiallyOpenOutsideTheBandDegradesToFlat() {
        // Neither tabletop nor literally flat — single-screen is the
        // always-playable layout, so it degrades there.
        #expect(PostureResolver.resolve(status: .partiallyOpen, angleDegrees: 40) == .flat)
        #expect(PostureResolver.resolve(status: .partiallyOpen, angleDegrees: 150) == .flat)
    }

    @Test func fullyOpenIsFlat() {
        #expect(PostureResolver.resolve(status: .fullyOpen, angleDegrees: 180) == .flat)
    }

    @Test func unknownStatusFallsBackToNoHinge() {
        // A status the SDK adds later must not be guessed at.
        #expect(PostureResolver.resolve(status: .unknown, angleDegrees: 90) == .noHinge)
    }
}

@MainActor
struct HingeObserverTests {
    @Test func startsWithNoHinge() {
        #expect(HingeObserver().posture == .noHinge)
    }

    @Test func updatesPostureFromStatusAndAngle() {
        let observer = HingeObserver()
        observer.update(status: .partiallyOpen, angleDegrees: 95)
        #expect(observer.posture == .tabletop)

        observer.update(status: .fullyOpen, angleDegrees: 180)
        #expect(observer.posture == .flat)

        observer.clearHinge()
        #expect(observer.posture == .noHinge)
    }
}
