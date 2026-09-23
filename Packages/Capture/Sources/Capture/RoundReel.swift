import Foundation

/// One round's highlight footage, as it sits on disk before anything is
/// rendered (PRD §5.4 — export is deferred to Save).
///
/// It is just the recorded segment files that survived retention plus the
/// windows to cut from them. Turning this into something playable is a
/// composition (`ReelComposer`), which is an edit list, not a render pass.
public struct RoundReel: Sendable, Equatable, Identifiable {
    public struct Segment: Sendable, Equatable {
        public let url: URL
        /// Capture-clock span this file covers. File time zero is
        /// `span.start` — the writer's session begins at the first sample.
        public let span: TimeSpan

        public init(url: URL, span: TimeSpan) {
            self.url = url
            self.span = span
        }
    }

    public let id: UUID
    public let segments: [Segment]
    public let windows: [TimeSpan]
    public let hasAudio: Bool

    public init(id: UUID = UUID(), segments: [Segment], windows: [TimeSpan], hasAudio: Bool) {
        self.id = id
        self.segments = segments
        self.windows = windows
        self.hasAudio = hasAudio
    }

    /// Length at 1×. Windows can straddle a gap left by a pause, so this is
    /// an upper bound; the composition is the authority on exact length.
    public var nominalDuration: Double { windows.reduce(0) { $0 + $1.duration } }
}

/// PRD §5.6 — speed is a render parameter, never baked into the capture.
public enum ReelSpeed: Double, Sendable, CaseIterable, Identifiable {
    case normal = 1
    case double = 2
    case triple = 3

    public var id: Double { rawValue }
    /// Default the picker to 2× — the funniest setting for reaction footage.
    public static let `default`: ReelSpeed = .double
    public var label: String { "\(Int(rawValue))×" }
}

/// PRD §7.2 — where footage of people who never installed the app lives,
/// and the guarantee that it doesn't outlive the match.
///
/// Everything sits under one temporary directory, excluded from backup.
/// `purgeAll()` runs on launch (a crash must never leave footage behind),
/// when a match starts, and whenever the match-end screen is left.
public struct ReelStore: Sendable {
    public let root: URL

    public init(root: URL = FileManager.default.temporaryDirectory.appendingPathComponent("ReactionReel", isDirectory: true)) {
        self.root = root
    }

    /// A fresh directory for one match's footage.
    public func makeMatchDirectory() -> URL? {
        directory(named: UUID().uuidString)
    }

    /// Scratch space for a Save export, deleted once Photos has it.
    public func makeExportURL() -> URL? {
        guard let directory = directory(named: "exports") else { return nil }
        return directory.appendingPathComponent("\(UUID().uuidString).mov")
    }

    public func purgeAll() {
        try? FileManager.default.removeItem(at: root)
    }

    public func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func directory(named name: String) -> URL? {
        var rootURL = root
        do {
            try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try rootURL.setResourceValues(values)
            let directory = rootURL.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            // Silent (CLAUDE.md §4): no directory means no reel, not an error.
            return nil
        }
    }
}
