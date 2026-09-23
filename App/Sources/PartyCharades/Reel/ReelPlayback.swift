import AVFoundation
import AVKit
import Capture
import SwiftUI
import UIKit

/// A looping player over a reel composition. Loops by seeking rather than
/// `AVPlayerLooper`, because the looper plays *copies* of its template item
/// and the varispeed pitch algorithm has to survive every loop (PRD §5.6).
@MainActor
@Observable
final class ReelPlayback {
    let player = AVPlayer()
    private(set) var isReady = false
    private var endObserver: NSObjectProtocol?

    /// Builds the edit list for `reels` at `speed` and starts looping it.
    /// Composition only — nothing is rendered (PRD §5.4).
    func load(_ reels: [RoundReel], speed: ReelSpeed, muted: Bool) async {
        guard let composition = await ReelComposer.composition(for: reels, speed: speed) else {
            isReady = false
            return
        }
        let item = ReelComposer.playerItem(for: composition)
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.player.seek(to: .zero)
                self?.player.play()
            }
        }
        player.actionAtItemEnd = .none
        player.isMuted = muted
        player.replaceCurrentItem(with: item)
        player.play()
        isReady = true
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        isReady = false
    }
}

/// Bare video surface — no transport controls — for the inline clip.
struct PlayerSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> SurfaceView {
        let view = SurfaceView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: SurfaceView, context: Context) {
        view.playerLayer.player = player
    }

    final class SurfaceView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

/// PRD §5.6 — inline on the round summary: muted by default, looping, tap to
/// expand and unmute. Never autoplays full-screen, never blocks "Next team".
struct HighlightClipCard: View {
    let reel: RoundReel
    let title: String
    @State private var playback = ReelPlayback()
    @State private var isExpanded = false

    var body: some View {
        Button {
            isExpanded = true
        } label: {
            ZStack(alignment: .bottomLeading) {
                Color.black
                if playback.isReady {
                    PlayerSurface(player: playback.player)
                }
                HStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                    Text("Reaction Replay")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: "speaker.slash.fill")
                        .font(.caption)
                }
                .foregroundStyle(.white)
                .padding(10)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Reaction replay. Double-tap to watch with sound and save."))
        .task(id: reel.id) {
            await playback.load([reel], speed: .normal, muted: true)
        }
        .onDisappear { playback.stop() }
        .sheet(isPresented: $isExpanded) {
            ReelSheet(title: title, reels: [reel])
        }
        // The sheet takes over playback with sound; the card resumes muted.
        .onChange(of: isExpanded) { _, expanded in
            if expanded { playback.player.pause() } else { playback.player.play() }
        }
    }
}

/// The expanded player: sound on, 1×/2×/3× preview that updates live as the
/// speed changes (so the choice is made by watching), and Save (PRD §5.6).
struct ReelSheet: View {
    let title: String
    let reels: [RoundReel]

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @State private var playback = ReelPlayback()
    @State private var speed: ReelSpeed = .default
    @State private var saveState: SaveState = .idle

    enum SaveState: Equatable {
        case idle, saving, saved, photosDenied, failed
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VideoPlayer(player: playback.player)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        if !playback.isReady { ProgressView() }
                    }

                Picker("Speed", selection: $speed) {
                    ForEach(ReelSpeed.allCases) { speed in
                        Text(speed.label).tag(speed)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(Text("Playback speed"))

                Button {
                    Task { await save() }
                } label: {
                    Group {
                        if saveState == .saving {
                            ProgressView()
                        } else {
                            Label("Save to Photos", systemImage: "square.and.arrow.down")
                        }
                    }
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(saveState == .saving || !playback.isReady)

                statusLine

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task(id: speed) {
            await playback.load(reels, speed: speed, muted: false)
            if saveState != .saving { saveState = .idle }
        }
        .onDisappear { playback.stop() }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch saveState {
        case .idle, .saving:
            EmptyView()
        case .saved:
            Label("Saved to Photos at \(speed.label)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .photosDenied:
            // The only capture-related message the app shows, and only
            // because the player explicitly asked to save.
            VStack(spacing: 6) {
                Text("Allow Photos access to save your reel.")
                    .foregroundStyle(.secondary)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        case .failed:
            Text("Couldn't save this clip. Try again.")
                .foregroundStyle(.secondary)
        }
    }

    private func save() async {
        saveState = .saving
        switch await coordinator.save(reels, speed: speed) {
        case .saved: saveState = .saved
        case .photosDenied: saveState = .photosDenied
        case .failed: saveState = .failed
        }
    }
}
