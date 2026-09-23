import Testing
@testable import Core

struct WordShapeTests {
    @Test(arguments: [
        ("Avengers", [8]),
        ("蛋撻", [2]),
        ("Spider-Man", [6, 3]),
        ("X戰警", [3]),
        ("The Dark Knight", [3, 4, 6]),
        ("Ocean's Eleven", [6, 6]),
        ("李奧納多·狄卡皮歐", [4, 4]),
        ("Mr. Bean", [2, 4]),
        ("Pokémon", [7]),
        ("Apollo 13", [6, 2]),
        ("  padded   spaces ", [6, 6]),
        ("湯姆克魯斯 (Tom Cruise)", [5]),
        ("里安納度狄卡比奧（Leonardo DiCaprio）", [8]),
        ("Ossan's Love (HK)", [6, 4]),
        ("X戰警 (X-Men)", [3]),
        ("Unclosed (paren", [8, 5]),
        ("Nike / 耐吉", [2]),
        ("Land Rover / 荒原路華", [4]),
        ("AC / DC", [2, 2]),
        ("", []),
    ])
    func groups(text: String, expected: [Int]) {
        #expect(WordShape.groups(for: text) == expected)
    }
}
