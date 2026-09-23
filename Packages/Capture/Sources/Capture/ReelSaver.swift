#if os(iOS)
import AVFoundation
import Photos

/// Save → Photos, end to end: compose, render once, hand the file to Photos,
/// delete the render. PRD §7.1 — Photos add-only access is requested here,
/// at the moment the player taps Save, and nowhere else.
@MainActor
public enum ReelSaver {
    public enum Outcome: Sendable, Equatable {
        case saved
        /// Photos access refused — the only capture-related message the app
        /// ever shows, and only because the player explicitly asked to save.
        case photosDenied
        case failed
    }

    public static func save(_ reels: [RoundReel], speed: ReelSpeed, store: ReelStore) async -> Outcome {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return .photosDenied }

        guard let composition = await ReelComposer.composition(for: reels, speed: speed),
              let exportURL = store.makeExportURL() else { return .failed }
        defer { store.remove(exportURL) }

        do {
            try await ReelExporter.export(composition, to: exportURL)
            try await PHPhotoLibrary.shared().performChanges(creationRequest(for: exportURL))
            return .saved
        } catch {
            return .failed
        }
    }

    /// Photos runs the change block on its own background queue. Written
    /// inline in this `@MainActor` type, Swift 6 would infer main-actor
    /// isolation for the closure and trap on that queue — so it is built
    /// here, nonisolated.
    private nonisolated static func creationRequest(for url: URL) -> @Sendable () -> Void {
        {
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
        }
    }
}
#endif
