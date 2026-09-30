import SwiftUI

/// A tappable heads-up shown when the allowance is nearly (or fully) spent,
/// so the paywall is never the first sign the games are running out. Draws
/// nothing above the threshold and for unlimited players.
struct LowGamesNotice: View {
    static let threshold = 3

    @Environment(AppCoordinator.self) private var coordinator

    /// True when this view will draw something; lets a caller show a plain
    /// count instead when it won't.
    static func isVisible(remaining: Int?) -> Bool {
        remaining.map { $0 <= threshold } ?? false
    }

    var body: some View {
        if let remaining = coordinator.store.allowance.remaining, Self.isVisible(remaining: remaining) {
            Button {
                coordinator.presentPaywall()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Theme.pill)
                    message(remaining)
                        .font(.footnote.weight(.semibold))
                    Text("Get More")
                        .font(.footnote.bold())
                        .underline()
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 4)
            }
            .buttonStyle(.glass)
            .accessibilityIdentifier("lowGamesNotice")
        }
    }

    private func message(_ remaining: Int) -> Text {
        switch remaining {
        case 0: Text("No games left")
        case 1: Text("Only 1 game left")
        default: Text("Only \(remaining) games left")
        }
    }
}
