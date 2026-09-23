import Foundation

/// The shape of an answer as the guessers see it on the outer display: one
/// count per word, one unit per letter or CJK character. "Avengers" is `[8]`,
/// "蛋撻" is `[2]`, "Spider-Man" is `[6, 3]`.
///
/// A parenthetical — the English original after a Chinese title, "(HK)" —
/// is a note, not part of the answer, so it is not counted: "湯姆克魯斯
/// (Tom Cruise)" is `[5]`.
///
/// Likewise the English half of a bilingual brand ("Nike / 耐吉" is `[2]`).
///
/// Only the shape crosses into the accessory scene — never the word itself,
/// which the guessers must not be able to read.
public enum WordShape {
    /// Characters that separate words. Whitespace always does; so do the
    /// hyphen, the slash, and the middle dots Chinese uses between the parts
    /// of a transliterated name (李奧納多·狄卡皮歐).
    private static let breaks: Set<Character> = ["-", "‐", "–", "—", "/", "·", "・", "•"]

    public static func groups(for text: String) -> [Int] {
        var groups: [Int] = []
        var current = 0
        let answer = chineseOnly(
            text.replacingOccurrences(
                of: "[（(][^）)]*[）)]", with: " ", options: .regularExpression
            )
        )
        for character in answer {
            if character.isWhitespace || breaks.contains(character) {
                if current > 0 { groups.append(current) }
                current = 0
            } else if character.isLetter || character.isNumber {
                // A grapheme cluster, so one Han character or one accented
                // Latin letter counts once.
                current += 1
            }
            // Anything else (apostrophes, full stops, colons, "!") is
            // dropped without breaking the word: "Ocean's" is 6.
        }
        if current > 0 { groups.append(current) }
        return groups
    }

    /// Brand entries pair the two spellings with a spaced slash — "Nike /
    /// 耐吉". When one side is Chinese, only that side is the answer.
    private static func chineseOnly(_ text: String) -> String {
        let parts = text.components(separatedBy: " / ")
        guard parts.count > 1 else { return text }
        let chinese = parts.filter { $0.unicodeScalars.contains { $0.properties.isIdeographic } }
        return chinese.isEmpty ? text : chinese.joined(separator: " ")
    }
}
