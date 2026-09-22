import Testing
@testable import ContentPipelineCore

struct DeterministicIDTests {
    @Test func isStableAcrossCalls() {
        let first = DeterministicID.uuid(category: "Movie", english: "Inception")
        let second = DeterministicID.uuid(category: "Movie", english: "Inception")
        #expect(first == second)
    }

    @Test func differsByCategoryEvenForSameEnglishWord() {
        let movie = DeterministicID.uuid(category: "Movie", english: "Spider-Man")
        let superhero = DeterministicID.uuid(category: "Superhero", english: "Spider-Man")
        #expect(movie != superhero)
    }

    @Test func differsByEnglishWordEvenForSameCategory() {
        let a = DeterministicID.uuid(category: "Movie", english: "Titanic")
        let b = DeterministicID.uuid(category: "Movie", english: "Avatar")
        #expect(a != b)
    }
}
