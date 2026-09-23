import Testing
@testable import Capture

/// PRD §5.5 / §7.2.4 / §5.3.
struct HighlightExtractorTests {
    let round = TimeSpan(start: 100, end: 160)

    @Test func singleCorrectGetsLeadInAndTail() {
        let windows = HighlightExtractor.windows(correctTimes: [120], recorded: round)
        #expect(windows == [TimeSpan(start: 118.5, end: 121)])
    }

    @Test func overlappingCorrectsMerge() {
        let windows = HighlightExtractor.windows(correctTimes: [120, 121.5], recorded: round)
        #expect(windows == [TimeSpan(start: 118.5, end: 122.5)])
    }

    @Test func windowsClampToRecordedSpan() {
        let windows = HighlightExtractor.windows(correctTimes: [100.5, 159.8], recorded: round)
        #expect(windows == [TimeSpan(start: 100, end: 101.5), TimeSpan(start: 158.3, end: 160)])
    }

    @Test func correctsOutsideRecordingAreIgnored() {
        #expect(HighlightExtractor.windows(correctTimes: [50, 200], recorded: round).isEmpty)
    }

    @Test func noCorrectsNoReel() {
        #expect(HighlightExtractor.windows(correctTimes: [], recorded: round).isEmpty)
    }

    @Test func capsAtSixEvenlySampledKeepingFirstAndLast() {
        let times = (0..<20).map { 101.5 + Double($0) * 3 }
        let windows = HighlightExtractor.windows(correctTimes: times, recorded: round)
        #expect(windows.count == 6)
        #expect(windows.first?.end == 102.5)
        #expect(windows.last?.end == 159.5)
    }

    @Test func totalNeverExceedsFifteenSeconds() {
        let times = (0..<40).map { 101.5 + Double($0) * 1.4 }
        let windows = HighlightExtractor.windows(correctTimes: times, recorded: round)
        let total = windows.reduce(0) { $0 + $1.duration }
        #expect(total <= HighlightExtractor.maxTotalDuration + 1e-9)
        for (a, b) in zip(windows, windows.dropFirst()) { #expect(a.end <= b.start) }
    }

    @Test func unsortedInputIsHandled() {
        let windows = HighlightExtractor.windows(correctTimes: [140, 120], recorded: round)
        #expect(windows.map(\.start) == [118.5, 138.5])
    }
}

struct SegmentRetentionTests {
    @Test func recentSegmentIsKeptForAFutureCorrect() {
        // Ended 1s ago — a Correct now reaches back 1.5s into it.
        #expect(!SegmentRetention.isDisposable(TimeSpan(start: 7, end: 9), now: 10, correctTimes: []))
    }

    @Test func oldUnreferencedSegmentIsDisposable() {
        #expect(SegmentRetention.isDisposable(TimeSpan(start: 2, end: 4), now: 10, correctTimes: []))
    }

    @Test func oldSegmentUnderACorrectWindowSurvives() {
        #expect(!SegmentRetention.isDisposable(TimeSpan(start: 2, end: 4), now: 10, correctTimes: [5]))
    }

    @Test func neededSelectsOverlappingSegments() {
        let segments = (0..<5).map { TimeSpan(start: Double($0) * 2, end: Double($0) * 2 + 2) }
        let needed = SegmentRetention.needed(segments, for: [TimeSpan(start: 3, end: 5.5)])
        #expect(needed == [1, 2])
    }
}

struct ThermalPolicyTests {
    @Test func stepsDownInOrder() {
        #expect(ThermalPolicy.next(current: .full, level: .fair) == .full)
        #expect(ThermalPolicy.next(current: .full, level: .serious) == .reduced)
        #expect(ThermalPolicy.next(current: .reduced, level: .critical) == .stopRecording)
        #expect(ThermalPolicy.next(current: .full, level: .shutdown) == .stopRecording)
    }

    @Test func neverStepsBackUpMidMatch() {
        #expect(ThermalPolicy.next(current: .reduced, level: .nominal) == .reduced)
        #expect(ThermalPolicy.next(current: .stopRecording, level: .fair) == .stopRecording)
    }
}
