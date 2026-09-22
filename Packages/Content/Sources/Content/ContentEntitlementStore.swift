/// PRD §9 — every content-availability check routes through this protocol so a
/// real entitlement/StoreKit-backed implementation can replace `AlwaysUnlocked`
/// later without touching call sites.
public protocol ContentEntitlementStore: Sendable {
    func isUnlocked(packID: String) -> Bool
}

public struct AlwaysUnlocked: ContentEntitlementStore {
    public init() {}

    public func isUnlocked(packID: String) -> Bool { true }
}
