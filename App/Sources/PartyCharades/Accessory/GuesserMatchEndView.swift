import Core
import SwiftUI

/// The outer display's Game Over mirror. Embeds the exact same
/// `MatchEndHeaderView` the inner screen's upper half shows.
struct GuesserMatchEndView: View {
    let snapshot: MatchEndSnapshot

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MatchEndHeaderView(snapshot: snapshot)
                .foregroundStyle(.white)
        }
    }
}
