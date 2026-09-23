import AVFoundation
import Foundation

/// PRD §5.4 / §5.6 — turns kept segments into something playable **without
/// rendering anything**. A composition is an edit list over the segment
/// files; `AVPlayer` plays it directly, and only `ReelExporter` ever renders
/// it, at the moment the player taps Save.
///
/// Speed is `scaleTimeRange(_:toDuration:)` over the whole edit, so 1×/2×/3×
/// are three edit lists over the same 1× footage and switching between them
/// costs nothing. Pair it with `AVAudioTimePitchAlgorithm.varispeed` on the
/// player item or export session: pitch rises with speed, deliberately.
@MainActor
public enum ReelComposer {
    public static func composition(for reels: [RoundReel], speed: ReelSpeed) async -> AVComposition? {
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return nil
        }
        let wantsAudio = reels.contains(where: \.hasAudio)
        let audioTrack = wantsAudio
            ? composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            : nil

        var cursor = CMTime.zero
        var transformSet = false
        let timescale: CMTimeScale = 600

        for reel in reels {
            for window in reel.windows {
                for segment in reel.segments where segment.span.overlaps(window) {
                    let asset = AVURLAsset(url: segment.url)
                    guard let sourceVideo = try? await asset.loadTracks(withMediaType: .video).first,
                          let trackRange = try? await sourceVideo.load(.timeRange) else { continue }

                    let from = max(window.start, segment.span.start) - segment.span.start
                    let to = min(window.end, segment.span.end) - segment.span.start
                    let start = CMTime(seconds: from, preferredTimescale: timescale)
                    let end = min(CMTime(seconds: to, preferredTimescale: timescale), trackRange.end)
                    guard end > start else { continue }
                    let range = CMTimeRange(start: start, end: end)

                    do {
                        try videoTrack.insertTimeRange(range, of: sourceVideo, at: cursor)
                    } catch {
                        continue
                    }
                    if !transformSet, let transform = try? await sourceVideo.load(.preferredTransform) {
                        videoTrack.preferredTransform = transform
                        transformSet = true
                    }
                    if let audioTrack, let sourceAudio = try? await asset.loadTracks(withMediaType: .audio).first,
                       let audioRange = try? await sourceAudio.load(.timeRange) {
                        let clipped = CMTimeRange(start: start, end: min(end, audioRange.end))
                        if clipped.duration > .zero {
                            try? audioTrack.insertTimeRange(clipped, of: sourceAudio, at: cursor)
                        }
                    }
                    cursor = cursor + range.duration
                }
            }
        }

        guard cursor > .zero else { return nil }
        if let audioTrack, audioTrack.segments.isEmpty {
            composition.removeTrack(audioTrack)
        }
        if speed != .normal {
            let full = CMTimeRange(start: .zero, duration: composition.duration)
            composition.scaleTimeRange(full, toDuration: CMTimeMultiplyByFloat64(composition.duration, multiplier: 1 / speed.rawValue))
        }
        return composition.copy() as? AVComposition
    }

    /// A player item for the in-app preview, with the same varispeed pitch
    /// the export will have — the choice is made by watching (PRD §5.6).
    public static func playerItem(for composition: AVComposition) -> AVPlayerItem {
        let item = AVPlayerItem(asset: composition)
        item.audioTimePitchAlgorithm = .varispeed
        return item
    }
}

/// PRD §5.4 — the only render pass in the whole pipeline, and it happens
/// only when the player taps Save.
@MainActor
public enum ReelExporter {
    public enum ExportError: Error { case unavailable }

    public static func export(_ composition: AVComposition, to url: URL) async throws {
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ExportError.unavailable
        }
        // Chipmunked audio is the joke. Do not "fix" this (CLAUDE.md §4).
        session.audioTimePitchAlgorithm = .varispeed
        try await session.export(to: url, as: .mov)
    }
}
