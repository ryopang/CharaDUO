/// A span of capture-clock time, in seconds. Plain `Double`s rather than
/// `CMTime` so the extraction and retention rules stay pure and testable on
/// any platform; the recorder converts at the boundary.
public struct TimeSpan: Sendable, Equatable {
    public var start: Double
    public var end: Double

    public init(start: Double, end: Double) {
        self.start = start
        self.end = end
    }

    public var duration: Double { max(0, end - start) }

    public func overlaps(_ other: TimeSpan) -> Bool {
        start < other.end && other.start < end
    }
}

/// PRD §5.5 — the moment of the guess is the funny part, so a round keeps
/// only a window around each **Correct**, never the whole round.
public enum HighlightExtractor {
    public static let leadIn: Double = 1.5
    public static let tail: Double = 1.0
    public static let maxClips = 6
    public static let maxTotalDuration: Double = 15

    /// - Parameters:
    ///   - correctTimes: capture-clock instants of each Correct tap.
    ///   - recorded: the span footage actually exists for. Windows are
    ///     clamped to it — a Correct in the first second of a round has less
    ///     than 1.5s of lead-in to give.
    /// - Returns: non-overlapping windows in chronological order, at most
    ///   `maxClips`, totalling at most `maxTotalDuration`.
    public static func windows(correctTimes: [Double], recorded: TimeSpan) -> [TimeSpan] {
        let sorted = correctTimes.sorted().filter { $0 >= recorded.start && $0 <= recorded.end }
        let sampled = evenlySampled(sorted, count: maxClips)

        var merged: [TimeSpan] = []
        for time in sampled {
            let window = TimeSpan(
                start: max(recorded.start, time - leadIn),
                end: min(recorded.end, time + tail)
            )
            guard window.duration > 0 else { continue }
            // Two quick Corrects produce overlapping windows; playing the
            // shared second twice would read as a glitch, so they fuse.
            if let last = merged.last, window.start <= last.end {
                merged[merged.count - 1].end = max(last.end, window.end)
            } else {
                merged.append(window)
            }
        }

        // 6 × 2.5s is exactly 15s and merging/clamping only shrink, so this
        // never fires today — it guards against the constants drifting.
        var total = 0.0
        var capped: [TimeSpan] = []
        for window in merged {
            let remaining = maxTotalDuration - total
            guard remaining > 0 else { break }
            var window = window
            window.end = min(window.end, window.start + remaining)
            total += window.duration
            capped.append(window)
        }
        return capped
    }

    /// "Evenly sampled if there were more" — keeps the first and last and
    /// spreads the rest across the round, so a 20-Correct round still
    /// represents its whole arc rather than just its opening.
    static func evenlySampled(_ values: [Double], count: Int) -> [Double] {
        guard values.count > count, count > 1 else { return Array(values.prefix(max(count, 0))) }
        let step = Double(values.count - 1) / Double(count - 1)
        return (0..<count).map { values[Int((Double($0) * step).rounded())] }
    }
}

/// PRD §7.2.4 — the rolling buffer is an intermediate. These rules decide
/// which recorded segments may be deleted while a round is still going and
/// which survive once it ends.
public enum SegmentRetention {
    /// A segment can go once no *future* Correct could reach back into it
    /// (it ended more than `leadIn` ago) and no Correct already recorded
    /// needs it. Keeps disk use at a handful of segments however long the
    /// round runs.
    public static func isDisposable(_ segment: TimeSpan, now: Double, correctTimes: [Double]) -> Bool {
        guard segment.end < now - HighlightExtractor.leadIn else { return false }
        return !correctTimes.contains { time in
            segment.overlaps(TimeSpan(start: time - HighlightExtractor.leadIn, end: time + HighlightExtractor.tail))
        }
    }

    /// At round end: the indices of segments any final window touches.
    public static func needed(_ segments: [TimeSpan], for windows: [TimeSpan]) -> [Int] {
        segments.indices.filter { index in windows.contains { segments[index].overlaps($0) } }
    }
}

/// PRD §5.3 — under thermal load, step down rather than let the countdown
/// stutter. Gameplay smoothness outranks the reel. Driven by
/// `AVCaptureDevice.systemPressureState.level`; `systemPressureCost` is
/// `AVCaptureMultiCamSession`-only in the 27.1 SDK and doesn't apply to the
/// single-camera session used here.
public enum ThermalPolicy: Sendable, Equatable, Comparable {
    /// 720p30.
    case full
    /// 540p, 24fps cap.
    case reduced
    /// No more recording this match. The session keeps running if the
    /// system allows, so the outer display can survive.
    case stopRecording

    public enum Level: Sendable, Equatable {
        case nominal, fair, serious, critical, shutdown
    }

    /// Never steps back up mid-match: a device that got hot once will get
    /// hot again, and flapping between presets costs more than it saves.
    public static func next(current: ThermalPolicy, level: Level) -> ThermalPolicy {
        let target: ThermalPolicy
        switch level {
        case .nominal, .fair: target = .full
        case .serious: target = .reduced
        case .critical, .shutdown: target = .stopRecording
        }
        return max(current, target)
    }
}
