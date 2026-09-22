import SwiftUI

/// PRD §2.4 — Quick Play is the primary button; everything else lives behind
/// the secondary Custom Game path. No naming, no toggles on this screen.
struct HomeView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        ScrollableCenteredColumn(spacing: 32) {
            Spacer(minLength: 24)

            VStack(spacing: 8) {
                Text("Party Charades")
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text("Describe it. Guess it. Don't say the word.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)

            Spacer(minLength: 24)

            VStack(spacing: 16) {
                Button {
                    coordinator.startQuickPlay()
                } label: {
                    Text("Quick Play")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)

                Button {
                    coordinator.presentCustomGame()
                } label: {
                    Text("Custom Game")
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.glass)
                .controlSize(.large)

                if let startError = coordinator.startError {
                    Text(startError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 24)
        }
        .padding()
    }
}
