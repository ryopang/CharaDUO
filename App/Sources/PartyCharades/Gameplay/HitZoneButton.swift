import SwiftUI

/// Shared by both layouts. PRD §2.1 — sized for a standing, angled, blind
/// stab: the whole zone is the target, no competing controls. PRD §11.1 —
/// Correct/Skip differ by position, haptic, sound, **icon and label**, not
/// colour alone.
///
/// Design refresh: each zone is a large rounded card floating on the deep
/// purple backdrop. Correct is a violet→magenta gradient — deliberately not
/// green, so it never merges with the countdown colour above it. Skip is a
/// quiet dark-glass card. The card is only the visual; the tappable area is
/// the entire zone including the gutter around it.
struct HitZoneButton: View {
    enum Kind {
        case correct
        case skip

        var title: LocalizedStringKey {
            switch self {
            case .correct: return "Correct"
            case .skip: return "Skip"
            }
        }

        var symbol: String {
            switch self {
            case .correct: return "checkmark"
            case .skip: return "forward.fill"
            }
        }
    }

    let kind: Kind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Color.clear
                .contentShape(Rectangle())
                .overlay { HitZoneCard(kind: kind) }
        }
        .buttonStyle(HitZoneButtonStyle())
        .background(Theme.backgroundDeep)
        .accessibilityLabel(Text(kind.title))
        .accessibilityAddTraits(.isButton)
    }
}

private struct HitZoneCard: View {
    let kind: HitZoneButton.Kind

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 36, style: .continuous) }

    var body: some View {
        // Tall zones stack icon over label; short, wide ones (tabletop) put
        // them side by side instead of squashing the label.
        ViewThatFits(in: .vertical) {
            VStack(spacing: 14) {
                chip(size: 76)
                label
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 18) {
                chip(size: 64)
                label
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { cardFill }
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(kind == .correct ? 0.55 : 0.28), .white.opacity(0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
        }
        .clipShape(shape)
        .shadow(color: kind == .correct ? Theme.accent.opacity(0.55) : .black.opacity(0.4), radius: 22, y: 8)
        .padding(12)
    }

    private func chip(size: CGFloat) -> some View {
        Image(systemName: kind.symbol)
            .font(.system(size: size * 0.45, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(chipFill))
            .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1.5))
            .accessibilityHidden(true)
    }

    private var label: some View {
        Text(kind.title)
            .font(.system(size: 60, weight: .heavy, design: .rounded))
            // "Correct" can wrap mid-word at large Dynamic Type sizes in a
            // narrow zone; shrink to one line instead.
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .foregroundStyle(.white.opacity(kind == .correct ? 1 : 0.92))
    }

    private var chipFill: Color {
        kind == .correct ? .white.opacity(0.22) : .white.opacity(0.12)
    }

    @ViewBuilder
    private var cardFill: some View {
        switch kind {
        case .correct:
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.55, green: 0.32, blue: 1.0), Color(red: 0.86, green: 0.24, blue: 0.72)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                // Soft top-leading glow, echoing the reference cards.
                RadialGradient(
                    colors: [.white.opacity(0.38), .clear],
                    center: .topLeading, startRadius: 0, endRadius: 420
                )
            }
        case .skip:
            ZStack {
                Color(red: 0.13, green: 0.09, blue: 0.22)
                RadialGradient(
                    colors: [Theme.accent.opacity(0.22), .clear],
                    center: .bottomTrailing, startRadius: 0, endRadius: 380
                )
            }
        }
    }
}

private struct HitZoneButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
