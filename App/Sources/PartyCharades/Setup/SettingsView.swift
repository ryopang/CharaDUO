import SwiftUI

/// A minimal stand-in for a real Settings screen — the app doesn't have one
/// yet, only the durable prefs already living on `AppSettings`. Reached from
/// the Game Over screen's "Settings" button; presented as a sheet so it
/// doesn't disturb the match-end flow underneath.
struct SettingsView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Reaction Camera", isOn: reactionCameraBinding)
                    if coordinator.settings.reactionCameraEnabled {
                        Toggle("Record Sound", isOn: reactionAudioBinding)
                    }
                } header: {
                    Text("Reaction Camera")
                } footer: {
                    Text(coordinator.settings.reactionCameraEnabled
                         ? "Films the guessing team and records the table during a round, so you get a highlight reel at the end. Everything stays on this device. This is also what powers the scoreboard on the outer display."
                         : "Off: no highlight reel, and no scoreboard on the outer display. The game plays normally.")
                }
                Section {
                    Toggle("Tick Sound", isOn: tickSoundBinding)
                } header: {
                    Text("Sound")
                } footer: {
                    Text("A soft tick every second during a round, sharper in the last 10 seconds. Follows your silent switch.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var reactionCameraBinding: Binding<Bool> {
        Binding(
            get: { coordinator.settings.reactionCameraEnabled },
            set: { coordinator.settings.reactionCameraEnabled = $0 }
        )
    }

    private var tickSoundBinding: Binding<Bool> {
        Binding(
            get: { coordinator.settings.tickSoundEnabled },
            set: { coordinator.settings.tickSoundEnabled = $0 }
        )
    }

    private var reactionAudioBinding: Binding<Bool> {
        Binding(
            get: { coordinator.settings.reactionAudioEnabled },
            set: { coordinator.settings.reactionAudioEnabled = $0 }
        )
    }
}
