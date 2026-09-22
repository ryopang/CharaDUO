import SwiftUI

struct RootView: View {
    @State private var coordinator = AppCoordinator(contentStore: loadBundledContentStoreOrFail())

    var body: some View {
        Group {
            switch coordinator.screen {
            case .home:
                HomeView()
            case .customGame:
                NavigationStack {
                    CustomGameView()
                        .navigationTitle("Custom Game")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { coordinator.returnHome() }
                            }
                        }
                }
            case .gameplay:
                GameplayView()
            case .roundSummary:
                RoundSummaryView()
            case .matchEnd:
                MatchEndView()
            }
        }
        .environment(coordinator)
    }
}
