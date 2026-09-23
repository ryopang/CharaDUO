import Content
import Core
import SwiftUI

struct CustomGameView: View {
    @Environment(AppCoordinator.self) private var coordinator

    @State private var teamCount = 2
    @State private var teamNames: [String] = ["", ""]
    @State private var roundsPerTeam = 2
    @State private var roundDuration = RoundDuration.default
    @State private var selectedCategories = Set<GameCategory>()
    @State private var skipPenaltyEnabled = false

    var body: some View {
        Form {
            Section("Number of Teams") {
                Picker("Number of Teams", selection: $teamCount) {
                    ForEach(1...4, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("teamCountPicker")
                .onChange(of: teamCount) { _, newValue in
                    while teamNames.count < newValue { teamNames.append("") }
                    while teamNames.count > newValue { teamNames.removeLast() }
                }
                ForEach(teamNames.indices, id: \.self) { index in
                    TextField("Team \(index + 1) name (optional)", text: $teamNames[index])
                }
            }

            Section("Rounds") {
                Picker("Rounds per team", selection: $roundsPerTeam) {
                    ForEach(1...5, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("roundsPerTeamPicker")
                Picker("Round length", selection: $roundDuration) {
                    ForEach(RoundDuration.allCases, id: \.self) { duration in
                        Text("\(duration.rawValue)s").tag(duration)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Categories") {
                ForEach(GameCategory.allCasesSortedAlphabetically, id: \.self) { category in
                    Toggle(category.emojiDisplayName, isOn: binding(for: category))
                }
                if selectedCategories.isEmpty {
                    Text("Pick at least one category.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Picker("Penalty on Skipping?", selection: $skipPenaltyEnabled) {
                    Text("No").tag(false)
                    Text("Yes (−1)").tag(true)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Penalty on Skipping?")
            } footer: {
                Text(skipPenaltyEnabled
                     ? "Tapping Skip costs the describing team 1 point."
                     : "Tapping Skip is free — it just moves to the next word.")
            }

            // PRD §7.3 — the master toggle and its audio sub-toggle, with
            // copy that states the tradeoff plainly rather than hiding it.
            Section {
                Toggle("Camera On", isOn: reactionCameraBinding)
                if coordinator.settings.reactionCameraEnabled {
                    Toggle("Sound On", isOn: reactionAudioBinding)
                }
            } header: {
                Text("Fun Cam")
            } footer: {
                Text(coordinator.settings.reactionCameraEnabled
                     ? "Films the guessing team and records the table during a round, so you get a highlight reel at the end. Everything stays on this device. This is also what powers the scoreboard on the outer display."
                     : "Off: no highlight reel, and no scoreboard on the outer display. The game plays normally.")
            }

            Section {
                HStack {
                    Spacer()
                    Button("Start Game") {
                        startMatch()
                    }
                    .disabled(selectedCategories.isEmpty)
                    Spacer()
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

    private var reactionAudioBinding: Binding<Bool> {
        Binding(
            get: { coordinator.settings.reactionAudioEnabled },
            set: { coordinator.settings.reactionAudioEnabled = $0 }
        )
    }

    private func binding(for category: GameCategory) -> Binding<Bool> {
        Binding(
            get: { selectedCategories.contains(category) },
            set: { isOn in
                if isOn {
                    selectedCategories.insert(category)
                } else {
                    selectedCategories.remove(category)
                }
            }
        )
    }

    private func startMatch() {
        let teams = teamNames.map { rawName -> Team in
            let trimmed = rawName.trimmingCharacters(in: .whitespaces)
            return Team(name: trimmed.isEmpty ? nil : trimmed)
        }
        let configuration = MatchConfiguration(
            teams: teams,
            roundsPerTeam: roundsPerTeam,
            roundDuration: roundDuration,
            categories: selectedCategories,
            language: coordinator.settings.lastUsedLanguage,
            skipPenaltyEnabled: skipPenaltyEnabled
        )
        coordinator.startCustomGame(configuration)
    }
}
