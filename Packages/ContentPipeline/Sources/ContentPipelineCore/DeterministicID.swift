import CryptoKit
import Foundation

/// `GameWord.id` must be stable across regenerations — random UUIDs would
/// churn the bundled JSON (and any future SwiftData relations that reference
/// a word) on every pipeline run for no reason. Derive a UUID deterministically
/// from (category, English) — the pair validated unique by `Validator` — via
/// SHA-256, with RFC 4122 version/variant bits set for a well-formed UUID.
public enum DeterministicID {
    public static func uuid(category: String, english: String) -> UUID {
        let seed = "\(category)\u{0}\(english)"
        let digest = SHA256.hash(data: Data(seed.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50 // version 5 (name-based, SHA-1/256 derived)
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // RFC 4122 variant
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
