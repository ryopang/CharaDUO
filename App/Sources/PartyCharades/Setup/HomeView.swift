import SwiftUI

/// PRD §2.4 — Quick Play is the primary button; everything else lives behind
/// the secondary Custom Game path. No naming, no toggles on this screen.
/// Quick Play's actual defaults (2 teams, 2 rounds each, 1 random topic) live
/// in `AppCoordinator.startQuickPlay()` — the caption text here just states
/// them.
struct HomeView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Text("Party Charades")
                        .font(.system(size: 72, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.4)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Describe it. Guess it. Don't say the word.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                buttons
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding()
    }

    private var buttons: some View {
        VStack(spacing: 20) {
                VStack(spacing: 8) {
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

                    // 2 teams / 2 rounds each / 1 random topic — PRD §2.4.
                    Text("2 teams · 2 rounds each · 1 random topic")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 8) {
                    Button {
                        coordinator.presentCustomGame()
                    } label: {
                        Text("Custom Game")
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)

                    Text("Choose your own teams, rounds, topics, and language")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let startError = coordinator.startError {
                    Text(startError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }
}
