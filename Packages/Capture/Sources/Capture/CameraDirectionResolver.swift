/// PRD §1.3 — which camera films the guessers is never hardcoded. The
/// `AVCaptureDeviceDirectionCoordinator` bound to the outer accessory scene
/// says which cameras face whatever is in front of that display; this only
/// picks *among* those.
public enum CameraDirectionResolver {
    /// A forward-facing camera as the coordinator described it.
    public struct Candidate: Sendable, Equatable {
        public let uniqueID: String
        public let deviceType: String

        public init(uniqueID: String, deviceType: String) {
            self.uniqueID = uniqueID
            self.deviceType = deviceType
        }
    }

    /// Prefers an ultra-wide — a whole guessing team across a table needs
    /// the field of view — and otherwise takes the coordinator's first
    /// choice. `nil` for an empty list means "no reel" (PRD §5.7).
    public static func preferred(from candidates: [Candidate]) -> Candidate? {
        candidates.first { $0.deviceType.localizedCaseInsensitiveContains("UltraWide") } ?? candidates.first
    }
}
