import SwiftUI

/// PRD §7.3 — the one-time card shown before the first match. It has to say
/// plainly that the guessing team is filmed and the table is recorded with
/// sound, that everything stays on the device, and that it can be turned
/// off. It requests camera and microphone together (§7.1), never mid-round.
///
/// Declining is a first-class outcome, not an error: the game plays normally
/// without the reel or the outer display.
struct CaptureConsentView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        ScrollableCenteredColumn {
            Spacer(minLength: 16)

            Image(systemName: "video.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("About the reaction camera")
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 16) {
                ConsentPoint(
                    icon: "person.2.fill",
                    text: "While a round is running, the guessing team is filmed and the table is recorded with sound — so the describer's voice is captured too."
                )
                ConsentPoint(
                    icon: "iphone",
                    text: "Everything stays on this device. Nothing is uploaded, analysed, or shared."
                )
                ConsentPoint(
                    icon: "trash",
                    text: "Clips you don't save are deleted when the match ends."
                )
                ConsentPoint(
                    icon: "switch.2",
                    text: "You can turn the camera off any time in Settings. The game plays fine without it."
                )
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 16)

            VStack(spacing: 12) {
                Button {
                    Task { await coordinator.acceptCaptureConsent() }
                } label: {
                    Text("Allow Camera & Mic")
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)

                Button {
                    coordinator.declineCaptureConsent()
                } label: {
                    Text("Play Without It")
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 16)
        }
        .padding()
    }
}

private struct ConsentPoint: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
