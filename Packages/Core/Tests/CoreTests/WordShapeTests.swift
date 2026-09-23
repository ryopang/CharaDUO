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
        ("", []),
    ])
    func groups(text: String, expected: [Int]) {
        #expect(WordShape.groups(for: text) == expected)
    }
}
