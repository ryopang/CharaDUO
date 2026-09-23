import AudioToolbox
import Foundation

/// The round's clock tick. Synthesized at first use — a short, damped sine
/// "tock" written to a temp WAV — rather than shipped as an audio asset.
/// Played through `AudioServices`, which honours the silent switch even while
/// the capture session has `.playAndRecord` active. Two loudnesses: a soft one
/// for most of the round, a more present one for the final 10 seconds. (Ticks
/// are audible on the reaction reel; that is accepted.)
@MainActor
final class TickSound {
    static let shared = TickSound()

    private lazy var softID: SystemSoundID? = Self.makeSound(name: "tick-soft", frequency: 900, amplitude: 0.16)
    private lazy var presentID: SystemSoundID? = Self.makeSound(name: "tick-present", frequency: 1250, amplitude: 0.42)

    func play(urgent: Bool) {
        guard let id = urgent ? presentID : softID else { return }
        AudioServicesPlaySystemSound(id)
    }

    private nonisolated static func makeSound(name: String, frequency: Double, amplitude: Double) -> SystemSoundID? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).wav")
        do {
            try wavData(frequency: frequency, amplitude: amplitude).write(to: url, options: .atomic)
        } catch {
            return nil
        }
        var id: SystemSoundID = 0
        return AudioServicesCreateSystemSoundID(url as CFURL, &id) == noErr ? id : nil
    }

    /// 16-bit mono PCM, 44.1 kHz, ~60 ms, exponentially damped with a 2 ms
    /// attack so it clicks softly rather than pops.
    nonisolated static func wavData(frequency: Double, amplitude: Double) -> Data {
        let rate = 44_100.0
        let count = Int(rate * 0.06)
        var samples = [Int16]()
        samples.reserveCapacity(count)
        for i in 0..<count {
            let t = Double(i) / rate
            let attack = min(1, t / 0.002)
            let envelope = attack * exp(-t * 70)
            let value = sin(2 * .pi * frequency * t) * envelope * amplitude
            samples.append(Int16(max(-1, min(1, value)) * Double(Int16.max)))
        }
        var data = Data()
        func append<T: FixedWidthInteger>(_ v: T) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        let byteCount = UInt32(count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); append(36 + byteCount)
        data.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16))
        append(UInt16(1)); append(UInt16(1)); append(UInt32(44_100)); append(UInt32(88_200)); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(byteCount)
        for s in samples { append(s) }
        return data
    }
}
