import Posture
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
            case .captureConsent:
                CaptureConsentView()
            case .gameplay:
                GameplayView()
            case .roundSummary:
                RoundSummaryView()
            case .matchEnd:
                MatchEndView()
            }
        }
        .environment(coordinator)
        // PRD §3.4 — the outer display is an enhancement layer hung off the
        // main scene. When the system isn't presenting it, this draws
        // nothing and the match neither knows nor cares.
        .outerDisplay(
            isActive: coordinator.isOuterDisplayActive,
            availability: coordinator.accessoryAvailability,
            onForwardCameras: { coordinator.forwardFacingCamerasChanged($0) }
        ) {
            coordinator.outerDisplayContent
        }
        // Below iOS 27.1, or on a device with no hinge, this is a no-op and
        // posture stays `.noHinge` — the single-screen path (PRD §8).
        .observingHinge(coordinator.hinge)
        .task {
            #if DEBUG
            if DebugOverrides.autoStartMatch, coordinator.screen == .home {
                coordinator.startQuickPlay()
            }
            #endif
        }
        .onChange(of: coordinator.posture) { _, newPosture in
            coordinator.postureChanged(to: newPosture)
        }
    }
}
