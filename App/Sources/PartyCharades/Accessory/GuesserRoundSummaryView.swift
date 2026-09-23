import Core
import SwiftUI

/// The outer display's round-summary mirror. Embeds the exact same
/// `RoundSummaryHeaderView` the inner screen's upper half shows, off the
/// same `RoundSummarySnapshot`, so both surfaces read identically — this
/// view only supplies the full-bleed dark background the outer display
/// always uses (PRD §3.4: "the whole room watches this").
struct GuesserRoundSummaryView: View {
    let snapshot: RoundSummarySnapshot

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RoundSummaryHeaderView(snapshot: snapshot)
                .foregroundStyle(.white)
        }
    }
}
