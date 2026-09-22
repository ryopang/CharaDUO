import SwiftUI

/// PRD §2.4 — Quick Play is the primary button; everything else lives behind
/// the secondary Custom Game path. No naming, no toggles on this screen.
struct HomeView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("Party Charades")
                    .font(.largeTitle.bold())
                Text("Describe it. Guess it. Don't say the word.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            Spacer()

            VStack(spacing: 16) {
                Button {
                    coordinator.startQuickPlay()
                } label: {
                    Text("Quick Play")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Custom Game") {
                    coordinator.presentCustomGame()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                if let startError = coordinator.startError {
                    Text(startError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding()
    }
}
