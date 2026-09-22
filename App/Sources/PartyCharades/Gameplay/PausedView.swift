import SwiftUI

/// PRD §3.1 — folding the device shut pauses the match and shows a resume
/// affordance on wake. Resuming is explicit: the round doesn't restart its
/// clock the instant the device reopens in someone's hands.
struct PausedView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "pause.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Paused")
                .font(.largeTitle.bold())

            Text("The round is on hold. Pick up where you left off when everyone's ready.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                coordinator.resumeFromPause()
            } label: {
                Text("Resume Round")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}
