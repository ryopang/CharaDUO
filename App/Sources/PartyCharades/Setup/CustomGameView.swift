import Content
import Core
import SwiftUI

struct CustomGameView: View {
    @Environment(AppCoordinator.self) private var coordinator

    @State private var teamCount = 2
    @State private var teamNames: [String] = ["", ""]
    @State private var roundsPerTeam = 3
    @State private var roundDuration = RoundDuration.default
    @State private var selectedCategories = Set(GameCategory.allCases)
    @State private var language: ContentLanguage
    @State private var skipPenaltyEnabled = false

    init() {
        // Placeholder; corrected in `.onAppear` to the coordinator's
        // last-used language once the environment object is available.
        _language = State(initialValue: .english)
    }

    var body: some View {
        Form {
            Section("Teams") {
                Stepper("Teams: \(teamCount)", value: $teamCount, in: 1...4)
                    .onChange(of: teamCount) { _, newValue in
                        while teamNames.count < newValue { teamNames.append("") }
                        while teamNames.count > newValue { teamNames.removeLast() }
                    }
                ForEach(teamNames.indices, id: \.self) { index in
                    TextField("Team \(index + 1) name (optional)", text: $teamNames[index])
                }
            }

            Section("Rounds") {
                Stepper("Rounds per team: \(roundsPerTeam)", value: $roundsPerTeam, in: 1...5)
                    .accessibilityIdentifier("roundsPerTeamStepper")
                Picker("Round length", selection: $roundDuration) {
                    ForEach(RoundDuration.allCases, id: \.self) { duration in
                        Text("\(duration.rawValue)s").tag(duration)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Categories") {
                ForEach(GameCategory.allCases, id: \.self) { category in
                    Toggle(category.displayName, isOn: binding(for: category))
                }
                if selectedCategories.isEmpty {
                    Text("Pick at least one category.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("Language") {
                Picker("Word language", selection: $language) {
                    ForEach(ContentLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
            }

            Section {
                Toggle("Skip Penalty (−1)", isOn: $skipPenaltyEnabled)
            }

            Section {
                Button("Start Match") {
                    startMatch()
                }
                .disabled(selectedCategories.isEmpty)
            }
        }
        .onAppear {
            language = coordinator.settings.lastUsedLanguage
        }
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
            language: language,
            skipPenaltyEnabled: skipPenaltyEnabled
        )
        coordinator.startCustomGame(configuration)
    }
}
