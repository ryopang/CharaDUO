import Observation

/// Tracks whether the system is currently presenting our scene accessory.
///
/// PRD §1.2.3, quoting `UISceneAccessory.h` directly: *"Scene accessories
/// enhance the app's experience when available, but the app must remain fully
/// functional without them. The system decides when and where to present
/// it."*
///
/// So this is strictly an output. **Nothing in game state may read it to
/// decide anything.** It exists so the accessory content can stop drawing —
/// not so the match can react. When the system revokes the accessory
/// mid-round, the correct behaviour is that absolutely nothing happens: no
/// error, no pause, no reconnect prompt (PRD §3.4).
@MainActor
@Observable
public final class AccessoryAvailability {
    public private(set) var isAvailable = false

    public init(isAvailable: Bool = false) {
        self.isAvailable = isAvailable
    }

    public func update(isAvailable: Bool) {
        self.isAvailable = isAvailable
    }
}
