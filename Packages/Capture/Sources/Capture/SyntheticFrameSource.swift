#if DEBUG
import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

/// CLAUDE.md §6 — the simulator has no camera, and the capture path must be
/// exercisable anyway. This feeds the **real** `ReactionRecorder` with
/// generated frames (a colour cycling with a sweeping bar, so motion and
/// speed-up are visible) and a warbling tone (so 2×/3× varispeed pitch is
/// audible), stamped on the host clock. Everything downstream — segments,
/// retention, highlight extraction, composition, export — is the production
/// code.
///
/// DEBUG-only: none of this compiles into a release build.
public final class SyntheticFrameSource: @unchecked Sendable {
    public let clock: CMClock = CMClockGetHostTimeClock()

    private let recorder: ReactionRecorder
    private let width: Int
    private let height: Int
    private let frameRate: Double
    private let includeAudio: Bool
    private var timer: DispatchSourceTimer?
    private var pixelPool: CVPixelBufferPool?
    private var videoFormat: CMFormatDescription?
    private var audioFormat: CMFormatDescription?
    private var nextAudioTime: CMTime?
    private var sampleCursor: Int64 = 0

    private static let sampleRate: Double = 44_100
    private static let audioChunk = 1_024

    public init(recorder: ReactionRecorder, width: Int = 1280, height: Int = 720, frameRate: Double = 30, includeAudio: Bool = true) {
        self.recorder = recorder
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.includeAudio = includeAudio
    }

    public var now: Double { CMClockGetTime(clock).seconds }

    public func start() {
        recorder.queue.async { [self] in
            guard timer == nil else { return }
            let timer = DispatchSource.makeTimerSource(queue: recorder.queue)
            timer.schedule(deadline: .now(), repeating: 1 / frameRate, leeway: .milliseconds(2))
            timer.setEventHandler { [weak self] in self?.tick() }
            self.timer = timer
            timer.resume()
        }
    }

    public func stop() {
        recorder.queue.async { [self] in
            timer?.cancel()
            timer = nil
            nextAudioTime = nil
        }
    }

    private func tick() {
        let time = CMClockGetTime(clock)
        if includeAudio { emitAudio(upTo: time) }
        if let buffer = makeVideoBuffer(at: time) { recorder.appendVideo(buffer) }
    }

    // MARK: Video

    private func makeVideoBuffer(at time: CMTime) -> CMSampleBuffer? {
        if pixelPool == nil {
            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
            ]
            CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pixelPool)
        }
        guard let pixelPool else { return nil }
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pixelPool, &pixelBuffer)
        guard let pixelBuffer else { return nil }

        let seconds = time.seconds
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            let hue = seconds.truncatingRemainder(dividingBy: 6) / 6
            let (r, g, b) = Self.rgb(hue: hue)
            let barX = Int((seconds.truncatingRemainder(dividingBy: 2) / 2) * Double(width))
            // Every row is identical, so build one and copy it down — a
            // per-pixel loop is far too slow for 30fps in a debug build.
            var row = [UInt8](repeating: 255, count: width * 4)
            for x in 0..<width {
                let onBar = abs(x - barX) < 24
                row[x * 4 + 0] = onBar ? 255 : b
                row[x * 4 + 1] = onBar ? 255 : g
                row[x * 4 + 2] = onBar ? 255 : r
            }
            row.withUnsafeBytes { source in
                for y in 0..<height {
                    base.advanced(by: y * bytesPerRow).copyMemory(from: source.baseAddress!, byteCount: width * 4)
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        if videoFormat == nil {
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &videoFormat)
        }
        guard let videoFormat else { return nil }
        var timing = CMSampleTimingInfo(
            duration: CMTime(seconds: 1 / frameRate, preferredTimescale: 600),
            presentationTimeStamp: time,
            decodeTimeStamp: .invalid
        )
        var sample: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: nil,
            imageBuffer: pixelBuffer,
            formatDescription: videoFormat,
            sampleTiming: &timing,
            sampleBufferOut: &sample
        )
        return sample
    }

    private static func rgb(hue: Double) -> (UInt8, UInt8, UInt8) {
        let h = hue * 6
        let x = 1 - abs(h.truncatingRemainder(dividingBy: 2) - 1)
        let (r, g, b): (Double, Double, Double)
        switch Int(h) {
        case 0: (r, g, b) = (1, x, 0)
        case 1: (r, g, b) = (x, 1, 0)
        case 2: (r, g, b) = (0, 1, x)
        case 3: (r, g, b) = (0, x, 1)
        case 4: (r, g, b) = (x, 0, 1)
        default: (r, g, b) = (1, 0, x)
        }
        return (UInt8(r * 200 + 30), UInt8(g * 200 + 30), UInt8(b * 200 + 30))
    }

    // MARK: Audio

    private func emitAudio(upTo time: CMTime) {
        if nextAudioTime == nil { nextAudioTime = time }
        while let next = nextAudioTime, next < time {
            guard let buffer = makeAudioBuffer(at: next) else { return }
            recorder.appendAudio(buffer)
            nextAudioTime = next + CMTime(value: CMTimeValue(Self.audioChunk), timescale: CMTimeScale(Self.sampleRate))
        }
    }

    private func makeAudioBuffer(at time: CMTime) -> CMSampleBuffer? {
        if audioFormat == nil {
            var asbd = AudioStreamBasicDescription(
                mSampleRate: Self.sampleRate,
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                mBytesPerPacket: 2,
                mFramesPerPacket: 1,
                mBytesPerFrame: 2,
                mChannelsPerFrame: 1,
                mBitsPerChannel: 16,
                mReserved: 0
            )
            CMAudioFormatDescriptionCreate(
                allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil,
                magicCookieSize: 0, magicCookie: nil, extensions: nil,
                formatDescriptionOut: &audioFormat
            )
        }
        guard let audioFormat else { return nil }

        let frames = Self.audioChunk
        var samples = [Int16](repeating: 0, count: frames)
        for index in 0..<frames {
            let t = Double(sampleCursor + Int64(index)) / Self.sampleRate
            // A tone that warbles between 330 and 550 Hz — at 2×/3× the
            // varispeed pitch shift is unmistakable.
            let frequency = 440 + 110 * sin(2 * .pi * 0.5 * t)
            samples[index] = Int16(sin(2 * .pi * frequency * t) * 6_000)
        }
        sampleCursor += Int64(frames)

        let byteCount = frames * MemoryLayout<Int16>.size
        var blockBuffer: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(
            allocator: nil, memoryBlock: nil, blockLength: byteCount, blockAllocator: nil,
            customBlockSource: nil, offsetToData: 0, dataLength: byteCount, flags: 0,
            blockBufferOut: &blockBuffer
        ) == noErr, let blockBuffer else { return nil }
        samples.withUnsafeBytes { raw in
            _ = CMBlockBufferReplaceDataBytes(with: raw.baseAddress!, blockBuffer: blockBuffer, offsetIntoDestination: 0, dataLength: byteCount)
        }

        var sample: CMSampleBuffer?
        CMAudioSampleBufferCreateReadyWithPacketDescriptions(
            allocator: nil, dataBuffer: blockBuffer, formatDescription: audioFormat,
            sampleCount: frames, presentationTimeStamp: time, packetDescriptions: nil,
            sampleBufferOut: &sample
        )
        return sample
    }
}
#endif
