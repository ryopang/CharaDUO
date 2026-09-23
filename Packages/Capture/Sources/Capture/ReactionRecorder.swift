import AVFoundation
import CoreMedia
import Foundation

/// The encoder ceiling. PRD §5.2 caps capture at 720p30; §5.3 steps down to
/// 540p under thermal load.
public struct VideoEncoding: Sendable, Equatable {
    public let maxLongEdge: Int
    public let maxShortEdge: Int
    public let maxFrameRate: Double
    public let averageBitRate: Int

    public static let full = VideoEncoding(maxLongEdge: 1280, maxShortEdge: 720, maxFrameRate: 30, averageBitRate: 3_000_000)
    public static let reduced = VideoEncoding(maxLongEdge: 960, maxShortEdge: 540, maxFrameRate: 24, averageBitRate: 1_600_000)
}

/// PRD §5.4 / §5.5 — the rolling buffer.
///
/// Sample buffers are written straight into a chain of short, self-contained
/// segment files by rotating `AVAssetWriter`s. Each new writer starts on a
/// fresh keyframe because it encodes from raw frames, so the segments are
/// gapless and independently playable — no concatenation or render pass
/// happens during a round, only encoding the camera would need anyway.
///
/// Segments no Correct could ever reach are deleted as the round goes
/// (`SegmentRetention`), so disk use stays at a few seconds of footage
/// however long the round runs. At round end the survivors that the final
/// highlight windows need become a `RoundReel`; everything else is deleted.
///
/// **Threading:** every piece of mutable state is confined to `queue`, which
/// is also the capture outputs' delegate queue. The public entry points hop
/// onto it; the `append` methods are called on it.
public final class ReactionRecorder: NSObject, @unchecked Sendable {
    public static let segmentLength: Double = 2.0

    public let queue = DispatchQueue(label: "com.ryopang.partycharades.recorder", qos: .userInitiated)

    // MARK: Queue-confined state

    private var directory: URL?
    private var isArmed = false
    private var recordsAudio = false
    private var encoding: VideoEncoding = .full
    private var transform: CGAffineTransform = .identity
    private var rotationRequested = false

    private var current: SegmentWriter?
    /// The previous segment, kept open for audio until audio passes its
    /// boundary — audio lags video slightly, and cutting it at the video
    /// boundary would leave an audible click every two seconds.
    private var closing: SegmentWriter?
    private var finished: [RoundReel.Segment] = []
    private var correctTimes: [Double] = []
    private var latestTime: Double = 0
    private var lastVideoTime: CMTime?
    private var lastVideoDuration = CMTime(value: 1, timescale: 30)
    private var audioFormat: CMFormatDescription?
    private var framesAwaitingAudio = 0
    private var segmentCounter = 0
    private var segmentsHadAudio = false
    private let finishGroup = DispatchGroup()

    // MARK: Round lifecycle

    /// Starts a new round's buffer in `directory`. Discards whatever a
    /// previous round left un-harvested. With `armed: false` nothing is
    /// written until `resume(recordsAudio:)` — the controller holds off until
    /// it knows which camera faces the guessers.
    public func beginRound(directory: URL, recordsAudio: Bool, armed: Bool = true) {
        queue.async { [self] in
            resetRound()
            self.directory = directory
            self.recordsAudio = recordsAudio
            self.isArmed = armed
        }
    }

    /// Mid-round stop (pause, camera lost, thermal): closes the open segment
    /// but keeps the round's footage for `endRound()`.
    public func suspend() {
        queue.async { [self] in
            isArmed = false
            closeOpenSegments()
        }
    }

    /// Picks up again in the same round after `suspend()`.
    public func resume(recordsAudio: Bool) {
        queue.async { [self] in
            guard directory != nil else { return }
            self.recordsAudio = recordsAudio
            isArmed = true
        }
    }

    /// A Correct tap, in seconds on the same clock the sample buffers are
    /// stamped with (the session's `synchronizationClock`).
    public func markHighlight(at time: Double) {
        queue.async { [self] in
            guard directory != nil else { return }
            correctTimes.append(time)
        }
    }

    public func setEncoding(_ encoding: VideoEncoding) {
        queue.async { [self] in
            guard self.encoding != encoding else { return }
            self.encoding = encoding
            rotationRequested = true
        }
    }

    /// The camera's rotation for horizon-level video, applied as the track's
    /// display transform rather than by rotating every frame.
    public func setRotationAngle(degrees: Double) {
        let transform = CGAffineTransform(rotationAngle: degrees * .pi / 180)
        queue.async { [self] in
            guard self.transform != transform else { return }
            self.transform = transform
            rotationRequested = true
        }
    }

    /// Start a new segment at the next frame — after a camera swap the
    /// dimensions can change, and a writer's input can't.
    public func requestNewSegment() {
        queue.async { [self] in rotationRequested = true }
    }

    /// Closes the round and returns its highlights, or nil when there is
    /// nothing worth showing (no Corrects, no footage, or capture failed).
    public func endRound() async -> RoundReel? {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                isArmed = false
                closeOpenSegments()
                finishGroup.notify(queue: queue) { [self] in
                    continuation.resume(returning: harvest())
                }
            }
        }
    }

    /// Drops the round without producing a reel (match abandoned).
    public func discardRound() {
        queue.async { [self] in
            isArmed = false
            closeOpenSegments()
            finishGroup.notify(queue: queue) { [self] in
                for segment in finished { try? FileManager.default.removeItem(at: segment.url) }
                resetRound()
            }
        }
    }

    // MARK: Sample input (on `queue`)

    public func appendVideo(_ buffer: CMSampleBuffer) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard isArmed, let directory else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(buffer)
        guard time.isNumeric else { return }

        // Frame-rate ceiling for the reduced encoding. Half a millisecond of
        // tolerance so a steady 30fps source isn't decimated unevenly.
        if let last = lastVideoTime, (time - last).seconds < (1 / encoding.maxFrameRate) - 0.0005 {
            return
        }

        // Give the microphone a moment to deliver its format so the first
        // segment isn't silent; half a second at most.
        if recordsAudio, audioFormat == nil, framesAwaitingAudio < 15 {
            framesAwaitingAudio += 1
            return
        }

        if let current {
            if rotationRequested || (time - current.start).seconds >= Self.segmentLength {
                rotate(at: time, directory: directory, sample: buffer)
            }
        } else {
            current = makeWriter(at: time, directory: directory, sample: buffer)
            rotationRequested = false
        }

        guard let current else { return }
        current.appendVideo(buffer)
        let duration = CMSampleBufferGetDuration(buffer)
        if duration.isNumeric, duration > .zero { lastVideoDuration = duration }
        if let last = lastVideoTime, time > last { lastVideoDuration = time - last }
        lastVideoTime = time
        latestTime = max(latestTime, time.seconds)
    }

    public func appendAudio(_ buffer: CMSampleBuffer) {
        dispatchPrecondition(condition: .onQueue(queue))
        if audioFormat == nil, let format = CMSampleBufferGetFormatDescription(buffer) {
            audioFormat = format
        }
        guard recordsAudio else { return }
        let start = CMSampleBufferGetPresentationTimeStamp(buffer)
        guard start.isNumeric else { return }
        let duration = CMSampleBufferGetDuration(buffer)
        let end = duration.isNumeric ? start + duration : start

        if let closing, let boundary = closing.boundary {
            if start < boundary {
                closing.appendAudio(buffer)
                // A buffer straddling the boundary goes to both writers; each
                // one's session range trims it to its own side.
                if end > boundary { current?.appendAudio(buffer) }
                return
            }
            finalize(closing, end: boundary)
            self.closing = nil
        }

        if let current, end > current.start {
            current.appendAudio(buffer)
        }
    }

    // MARK: Segments

    private func rotate(at time: CMTime, directory: URL, sample: CMSampleBuffer) {
        guard let old = current else { return }
        old.boundary = time
        old.finishVideo()
        if let closing, let boundary = closing.boundary {
            finalize(closing, end: boundary)
            self.closing = nil
        }
        if old.hasAudio {
            closing = old
        } else {
            finalize(old, end: time)
        }
        current = makeWriter(at: time, directory: directory, sample: sample)
        rotationRequested = false
        pruneDisposableSegments()
    }

    private func closeOpenSegments() {
        let end = lastVideoTime.map { $0 + lastVideoDuration }
        if let closing, let boundary = closing.boundary {
            finalize(closing, end: boundary)
        }
        closing = nil
        if let current, let end {
            current.finishVideo()
            finalize(current, end: end)
        } else if let current {
            current.cancel()
        }
        current = nil
        lastVideoTime = nil
        framesAwaitingAudio = 0
    }

    private func makeWriter(at time: CMTime, directory: URL, sample: CMSampleBuffer) -> SegmentWriter? {
        guard let format = CMSampleBufferGetFormatDescription(sample) else { return nil }
        segmentCounter += 1
        let url = directory.appendingPathComponent(String(format: "segment-%05d.mov", segmentCounter))
        let writer = SegmentWriter(
            url: url,
            start: time,
            videoFormat: format,
            audioFormat: recordsAudio ? audioFormat : nil,
            encoding: encoding,
            transform: transform
        )
        if writer?.hasAudio == true { segmentsHadAudio = true }
        return writer
    }

    private func finalize(_ writer: SegmentWriter, end: CMTime) {
        finishGroup.enter()
        writer.finish(at: end) { [self] succeeded in
            queue.async { [self] in
                if succeeded {
                    finished.append(RoundReel.Segment(url: writer.url, span: TimeSpan(start: writer.start.seconds, end: end.seconds)))
                    pruneDisposableSegments()
                } else {
                    try? FileManager.default.removeItem(at: writer.url)
                }
                finishGroup.leave()
            }
        }
    }

    private func pruneDisposableSegments() {
        finished.removeAll { segment in
            guard SegmentRetention.isDisposable(segment.span, now: latestTime, correctTimes: correctTimes) else { return false }
            try? FileManager.default.removeItem(at: segment.url)
            return true
        }
    }

    private func harvest() -> RoundReel? {
        defer { resetRound() }
        let segments = finished.sorted { $0.span.start < $1.span.start }
        guard let first = segments.first, let last = segments.last else { return nil }
        let windows = HighlightExtractor.windows(
            correctTimes: correctTimes,
            recorded: TimeSpan(start: first.span.start, end: last.span.end)
        )
        let needed = Set(SegmentRetention.needed(segments.map(\.span), for: windows))
        var kept: [RoundReel.Segment] = []
        for (index, segment) in segments.enumerated() {
            if needed.contains(index) {
                kept.append(segment)
            } else {
                try? FileManager.default.removeItem(at: segment.url)
            }
        }
        finished = []
        guard !windows.isEmpty, !kept.isEmpty else { return nil }
        return RoundReel(segments: kept, windows: windows, hasAudio: segmentsHadAudio)
    }

    private func resetRound() {
        current?.cancel()
        closing?.cancel()
        current = nil
        closing = nil
        finished = []
        correctTimes = []
        latestTime = 0
        lastVideoTime = nil
        framesAwaitingAudio = 0
        segmentsHadAudio = false
        rotationRequested = false
        directory = nil
    }
}

// MARK: - Capture output delegate

extension ReactionRecorder: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output is AVCaptureAudioDataOutput {
            appendAudio(sampleBuffer)
        } else {
            appendVideo(sampleBuffer)
        }
    }
}

// MARK: - One segment file

/// One `AVAssetWriter` and its inputs. Only ever touched on the recorder's
/// queue (plus the writer's own completion callback).
private final class SegmentWriter: @unchecked Sendable {
    let url: URL
    let start: CMTime
    /// Where the next segment took over; set when this one stops taking video.
    var boundary: CMTime?

    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let audioInput: AVAssetWriterInput?
    private var videoFinished = false

    var hasAudio: Bool { audioInput != nil }

    init?(
        url: URL,
        start: CMTime,
        videoFormat: CMFormatDescription,
        audioFormat: CMFormatDescription?,
        encoding: VideoEncoding,
        transform: CGAffineTransform
    ) {
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mov) else { return nil }
        self.url = url
        self.start = start
        self.writer = writer

        let dimensions = CMVideoFormatDescriptionGetDimensions(videoFormat)
        let size = Self.fitted(width: Int(dimensions.width), height: Int(dimensions.height), within: encoding)
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspect,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: encoding.averageBitRate,
                AVVideoExpectedSourceFrameRateKey: Int(encoding.maxFrameRate),
                AVVideoMaxKeyFrameIntervalKey: Int(encoding.maxFrameRate),
            ],
        ], sourceFormatHint: videoFormat)
        videoInput.expectsMediaDataInRealTime = true
        videoInput.transform = transform
        guard writer.canAdd(videoInput) else { return nil }
        writer.add(videoInput)
        self.videoInput = videoInput

        // PRD §5.2 — mono. Sample rate follows the source; resampling the
        // microphone buys nothing for a party reel.
        if let audioFormat, let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormat)?.pointee {
            var layout = AudioChannelLayout()
            layout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 1,
                AVSampleRateKey: asbd.mSampleRate > 0 ? asbd.mSampleRate : 44_100,
                AVEncoderBitRateKey: 64_000,
                AVChannelLayoutKey: Data(bytes: &layout, count: MemoryLayout<AudioChannelLayout>.size),
            ], sourceFormatHint: audioFormat)
            audioInput.expectsMediaDataInRealTime = true
            if writer.canAdd(audioInput) {
                writer.add(audioInput)
                self.audioInput = audioInput
            } else {
                self.audioInput = nil
            }
        } else {
            self.audioInput = nil
        }

        guard writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: start)
    }

    func appendVideo(_ buffer: CMSampleBuffer) {
        guard !videoFinished, writer.status == .writing, videoInput.isReadyForMoreMediaData else { return }
        videoInput.append(buffer)
    }

    func appendAudio(_ buffer: CMSampleBuffer) {
        guard let audioInput, writer.status == .writing, audioInput.isReadyForMoreMediaData else { return }
        audioInput.append(buffer)
    }

    func finishVideo() {
        guard !videoFinished else { return }
        videoFinished = true
        if writer.status == .writing { videoInput.markAsFinished() }
    }

    func finish(at end: CMTime, completion: @escaping @Sendable (Bool) -> Void) {
        guard writer.status == .writing else {
            completion(false)
            return
        }
        finishVideo()
        audioInput?.markAsFinished()
        writer.endSession(atSourceTime: end)
        // `self` is @unchecked Sendable (queue-confined); capturing it
        // rather than the non-Sendable writer keeps strict concurrency happy.
        writer.finishWriting { [self] in
            completion(self.writer.status == .completed)
        }
    }

    func cancel() {
        if writer.status == .writing { writer.cancelWriting() }
        try? FileManager.default.removeItem(at: url)
    }

    /// Fit the source inside the encoding's box, keeping aspect and
    /// orientation, rounded to even dimensions for H.264.
    static func fitted(width: Int, height: Int, within encoding: VideoEncoding) -> (width: Int, height: Int) {
        guard width > 0, height > 0 else { return (encoding.maxLongEdge, encoding.maxShortEdge) }
        let landscape = width >= height
        let maxW = Double(landscape ? encoding.maxLongEdge : encoding.maxShortEdge)
        let maxH = Double(landscape ? encoding.maxShortEdge : encoding.maxLongEdge)
        let scale = min(1, min(maxW / Double(width), maxH / Double(height)))
        func even(_ value: Double) -> Int { max(2, Int(value / 2) * 2) }
        return (even(Double(width) * scale), even(Double(height) * scale))
    }
}
