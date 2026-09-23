import AVFoundation
import Foundation
import Testing
@testable import Capture

/// End to end through the production recorder and composer, fed by the
/// DEBUG synthetic source — the same path `-uiTestSyntheticCamera` drives
/// in the simulator. Real time, so these take a few seconds each.
@Suite(.serialized)
struct ReactionRecorderTests {
    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReactionRecorderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func files(in directory: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
    }

    @Test @MainActor func correctProducesTrimmedReelAndSpeedScales() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let recorder = ReactionRecorder()
        let source = SyntheticFrameSource(recorder: recorder, width: 320, height: 180)

        recorder.beginRound(directory: directory, recordsAudio: true)
        source.start()
        try await Task.sleep(for: .seconds(5))
        recorder.markHighlight(at: source.now)
        try await Task.sleep(for: .seconds(1.6))
        source.stop()

        let reel = try #require(await recorder.endRound())
        #expect(reel.windows.count == 1)
        #expect(abs(reel.nominalDuration - 2.5) < 0.05)
        #expect(reel.hasAudio)

        // Rolling-buffer retention: the opening seconds nobody needed are
        // gone from disk; only the segments under the window survive.
        let remaining = files(in: directory)
        #expect(remaining.count == reel.segments.count)
        #expect(reel.segments.count <= 3)

        let normal = try #require(await ReelComposer.composition(for: [reel], speed: .normal))
        let double = try #require(await ReelComposer.composition(for: [reel], speed: .double))
        let triple = try #require(await ReelComposer.composition(for: [reel], speed: .triple))
        #expect(abs(normal.duration.seconds - 2.5) < 0.2)
        #expect(abs(double.duration.seconds - normal.duration.seconds / 2) < 0.05)
        #expect(abs(triple.duration.seconds - normal.duration.seconds / 3) < 0.05)
        #expect(!normal.tracks(withMediaType: .audio).isEmpty)
    }

    @Test @MainActor func roundWithoutCorrectsLeavesNothingOnDisk() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let recorder = ReactionRecorder()
        let source = SyntheticFrameSource(recorder: recorder, width: 320, height: 180, includeAudio: false)

        recorder.beginRound(directory: directory, recordsAudio: false)
        source.start()
        try await Task.sleep(for: .seconds(3))
        source.stop()

        #expect(await recorder.endRound() == nil)
        #expect(files(in: directory).isEmpty)
    }

    @Test @MainActor func silentStateProducesVideoOnlyReel() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let recorder = ReactionRecorder()
        let source = SyntheticFrameSource(recorder: recorder, width: 320, height: 180)

        // The synthetic source still emits audio; the recorder must ignore
        // it, exactly as with a real microphone in the Silent state.
        recorder.beginRound(directory: directory, recordsAudio: false)
        source.start()
        try await Task.sleep(for: .seconds(2))
        recorder.markHighlight(at: source.now)
        try await Task.sleep(for: .seconds(1.2))
        source.stop()

        let reel = try #require(await recorder.endRound())
        #expect(!reel.hasAudio)
        let composition = try #require(await ReelComposer.composition(for: [reel], speed: .normal))
        #expect(composition.tracks(withMediaType: .audio).isEmpty)
    }

    @Test func storePurgeRemovesEverything() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReelStoreTests-\(UUID().uuidString)")
        let store = ReelStore(root: root)
        let match = try #require(store.makeMatchDirectory())
        try Data([1, 2, 3]).write(to: match.appendingPathComponent("segment.mov"))
        #expect(FileManager.default.fileExists(atPath: match.path))
        #expect(try root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)

        store.purgeAll()
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    @Test func directionPrefersUltraWide() {
        let candidates = [
            CameraDirectionResolver.Candidate(uniqueID: "a", deviceType: "AVCaptureDeviceTypeBuiltInWideAngleCamera"),
            CameraDirectionResolver.Candidate(uniqueID: "b", deviceType: "AVCaptureDeviceTypeBuiltInOuterUltraWideCamera"),
        ]
        #expect(CameraDirectionResolver.preferred(from: candidates)?.uniqueID == "b")
        #expect(CameraDirectionResolver.preferred(from: [candidates[0]])?.uniqueID == "a")
        #expect(CameraDirectionResolver.preferred(from: []) == nil)
    }
}
