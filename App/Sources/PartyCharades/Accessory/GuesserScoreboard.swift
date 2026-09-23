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
/// Top to bottom: category name, countdown, the answer's shape as a row of
/// category emoji (one per letter or CJK character, a gap between words;
/// the biggest thing on screen), then team and score.
struct GuesserScoreboard: View {
    let snapshot: ScoreboardSnapshot

    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 88
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let increaseContrast = colorSchemeContrast == .increased
        let foreground = CountdownColor.foreground(fractionElapsed: snapshot.fractionElapsed, increaseContrast: increaseContrast)

        ZStack {
            CountdownColor.background(fractionElapsed: snapshot.fractionElapsed, increaseContrast: increaseContrast)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                Text(snapshot.category.displayName.uppercased())
                    .font(.title3.bold())
                    .foregroundStyle(foreground.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text("\(snapshot.secondsRemaining)")
                    .font(.system(size: timerSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(foreground)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .countdownPulse(secondsRemaining: snapshot.secondsRemaining)

                WordShapeRow(emoji: snapshot.category.emoji, groups: snapshot.wordShape)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Scoreboard pill: who's up, then their live score in its
                // own inset badge, so the number can't read as part of the
                // team name.
                HStack(spacing: 12) {
                    Text(snapshot.teamName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(foreground.opacity(0.8))
                    Text("\(snapshot.score)")
                        .font(.title2.weight(.heavy).monospacedDigit())
                        .contentTransition(.numericText())
                        .foregroundStyle(foreground)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 2)
                        .background(foreground.opacity(0.14), in: Capsule())
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.leading, 18)
                .padding(.trailing, 6)
                .padding(.vertical, 6)
                .background(foreground.opacity(0.08), in: Capsule())
                .accessibilityElement(children: .combine)
            }
            .padding()
            .overlay(alignment: .topLeading) {
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
                    .foregroundStyle(foreground.opacity(0.75))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(foreground.opacity(0.08), in: Capsule())
                    .padding(16)
                }
            }

            ScoreFeedbackOverlay(feedback: snapshot.lastFeedback)
        }
    }
}

/// The answer's shape, drawn as one category emoji per letter or character.
/// Sized to the largest emoji that fits the space it's given, wrapping only
/// between words. A word is broken across lines only when keeping it whole
/// would shrink the emoji below `WordShapeLayout.legibleEmojiSize` — a
/// mid-word break reads like a word gap, so it is the last resort.
private struct WordShapeRow: View {
    let emoji: String
    let groups: [Int]

    var body: some View {
        GeometryReader { proxy in
            let fit = WordShapeLayout.fit(groups: groups, in: proxy.size)
            VStack(spacing: fit.lineSpacing) {
                ForEach(fit.lines.indices, id: \.self) { lineIndex in
                    HStack(spacing: fit.wordGap) {
                        ForEach(fit.lines[lineIndex].indices, id: \.self) { chunkIndex in
                            HStack(spacing: fit.letterSpacing) {
                                ForEach(0..<fit.lines[lineIndex][chunkIndex], id: \.self) { _ in
                                    // Emoji glyphs advance wider than their
                                    // point size; 0.78 keeps one inside its
                                    // square, and fixedSize stops SwiftUI
                                    // truncating (clipping) a glyph that
                                    // still overhangs slightly.
                                    Text(emoji)
                                        .font(.system(size: fit.emojiSize * 0.78))
                                        .fixedSize()
                                        .frame(width: fit.emojiSize, height: fit.emojiSize)
                                }
                            }
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("Answer length: \(groups.reduce(0, +))"))
    }
}

/// Pure sizing for `WordShapeRow`. Every spacing is a fixed fraction of the
/// emoji size, so the one unknown is that size: binary-search the largest
/// one whose greedy word-wrap fits both dimensions.
enum WordShapeLayout {
    struct Fit: Equatable {
        var emojiSize: CGFloat
        /// Each line is a list of chunks; a chunk is a count of emoji drawn
        /// tight together. Chunks are separated by a word gap.
        var lines: [[Int]]
        var letterSpacing: CGFloat { emojiSize * 0.06 }
        var wordGap: CGFloat { emojiSize * 0.55 }
        var lineSpacing: CGFloat { emojiSize * 0.18 }
    }

    static let maximumEmojiSize: CGFloat = 240
    static let minimumEmojiSize: CGFloat = 6
    /// Below this, whole words give way to mid-word breaks.
    static let legibleEmojiSize: CGFloat = 36

    static func fit(groups: [Int], in size: CGSize) -> Fit {
        let groups = groups.filter { $0 > 0 }
        guard !groups.isEmpty, size.width > 0, size.height > 0 else {
            return Fit(emojiSize: 0, lines: [])
        }
        if let whole = search(groups, in: size, splitWords: false),
           whole.emojiSize >= legibleEmojiSize {
            return whole
        }
        return search(groups, in: size, splitWords: true)
            ?? Fit(emojiSize: minimumEmojiSize, lines: [groups])
    }

    private static func search(_ groups: [Int], in size: CGSize, splitWords: Bool) -> Fit? {
        var low = minimumEmojiSize
        var high = min(maximumEmojiSize, size.height)
        var best: Fit?
        // 20 halvings of a ≤240pt range is well under a point of error.
        for _ in 0..<20 {
            let mid = (low + high) / 2
            if let lines = wrap(groups, emojiSize: mid, width: size.width, splitWords: splitWords),
               height(lines: lines.count, emojiSize: mid) <= size.height {
                best = Fit(emojiSize: mid, lines: lines)
                low = mid
            } else {
                high = mid
            }
        }
        return best
    }

    /// Greedy wrap. Returns nil if not even one emoji fits on a line, or —
    /// without `splitWords` — if some word is longer than a line.
    static func wrap(_ groups: [Int], emojiSize s: CGFloat, width: CGFloat, splitWords: Bool) -> [[Int]]? {
        let probe = Fit(emojiSize: s, lines: [])
        let perLine = Int(((width + probe.letterSpacing) / (s + probe.letterSpacing)).rounded(.down))
        guard perLine >= 1 else { return nil }
        if !splitWords, groups.contains(where: { $0 > perLine }) { return nil }

        func chunkWidth(_ count: Int) -> CGFloat {
            CGFloat(count) * s + CGFloat(count - 1) * probe.letterSpacing
        }

        var lines: [[Int]] = []
        var line: [Int] = []
        var lineWidth: CGFloat = 0
        for group in groups {
            // A word longer than a whole line is split into line-sized chunks.
            var remaining = group
            while remaining > 0 {
                let chunk = min(remaining, perLine)
                let added = (line.isEmpty ? 0 : probe.wordGap) + chunkWidth(chunk)
                if !line.isEmpty, lineWidth + added > width {
                    lines.append(line)
                    line = []
                    lineWidth = 0
                    continue
                }
                line.append(chunk)
                lineWidth += line.count == 1 ? chunkWidth(chunk) : added
                remaining -= chunk
            }
        }
        if !line.isEmpty { lines.append(line) }
        return lines
    }

    static func height(lines: Int, emojiSize s: CGFloat) -> CGFloat {
        CGFloat(lines) * s + CGFloat(max(lines - 1, 0)) * s * 0.18
    }
}
