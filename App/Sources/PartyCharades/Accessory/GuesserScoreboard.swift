import Core
import SwiftUI

/// PRD §3.4 — what the guessers watch on the outer display. Passive, no
/// touch input in v1 (the platform would allow interaction; this is a
/// product decision, not a limit).
///
/// This is the surface the whole room watches, so unlike the describer's lid
/// it carries the urgency gradient at **full** strength (§3.3).
///
/// Takes an immutable `ScoreboardSnapshot`, never the engine: §10.2 says the
/// accessory scene must not own or mutate state, and a value type is how
/// that gets enforced rather than merely intended.
///
/// The live camera mirror §3.4 also calls for lands with M6, alongside the
/// preview pipeline and the direction coordinator that decides which camera
/// actually faces the guessers (§1.3).
struct GuesserScoreboard: View {
    let snapshot: ScoreboardSnapshot

    var body: some View {
        ZStack {
            CountdownColor.background(fractionElapsed: snapshot.fractionElapsed)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text(snapshot.category.displayName.uppercased())
                    .font(.title3.bold())
                    .foregroundStyle(.black.opacity(0.7))

                Text("\(snapshot.secondsRemaining)")
                    .font(.system(size: 140, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(.black)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Text(snapshot.teamName)
                        .font(.title2.bold())
                    Text("\(snapshot.score)")
                        .font(.title2.bold().monospacedDigit())
                }
                .foregroundStyle(.black.opacity(0.75))

                if snapshot.isRecording {
                    // PRD §7.3 — a persistent recording indicator belongs
                    // here, where the people being filmed are looking.
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                        Text("REC")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.black.opacity(0.7))
                }
            }
            .padding()
        }
    }
}
