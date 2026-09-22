import Observation

/// Holds the current posture for the view layer to read. Kept free of any
/// SDK-gated types so it compiles and can be driven directly in tests; the
/// `DeviceHinge` bridging lives in `HingeObservation+iOS.swift`.
@MainActor
@Observable
public final class HingeObserver {
    public private(set) var posture: PostureState

    public init(initialPosture: PostureState = .noHinge) {
        self.posture = initialPosture
    }

    public func update(status: HingeStatusKind, angleDegrees: Double) {
        posture = PostureResolver.resolve(status: status, angleDegrees: angleDegrees)
    }

    public func clearHinge() {
        posture = .noHinge
    }
}
