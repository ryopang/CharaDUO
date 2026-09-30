import Foundation
import Testing
@testable import Core

struct GameAllowanceTests {
    @Test func startsWithTenFreeGames() {
        let allowance = GameAllowance()
        #expect(allowance.remaining == 10)
        #expect(allowance.canStartGame)
    }

    @Test func tenthGameIsLastFreeOne() {
        var allowance = GameAllowance()
        for _ in 0..<9 { allowance.recordGameStarted() }
        #expect(allowance.remaining == 1)
        #expect(allowance.canStartGame)
        allowance.recordGameStarted()
        #expect(allowance.remaining == 0)
        #expect(!allowance.canStartGame)
    }

    @Test func packAddsTenGames() {
        var allowance = GameAllowance(gamesPlayed: 10)
        #expect(!allowance.canStartGame)
        let granted = allowance.addPack(transactionID: 1)
        #expect(granted)
        #expect(allowance.remaining == 10)
        #expect(allowance.canStartGame)
    }

    @Test func packsStack() {
        var allowance = GameAllowance(gamesPlayed: 4)
        allowance.addPack(transactionID: 1)
        allowance.addPack(transactionID: 2)
        #expect(allowance.remaining == 26)
    }

    @Test func redeliveredTransactionIsNotGrantedTwice() {
        var allowance = GameAllowance()
        let first = allowance.addPack(transactionID: 7)
        let second = allowance.addPack(transactionID: 7)
        #expect(first)
        #expect(!second)
        #expect(allowance.remaining == 20)
    }

    @Test func unlimitedNeverRunsOutAndDoesNotCount() {
        var allowance = GameAllowance(gamesPlayed: 10, hasUnlimited: true)
        #expect(allowance.remaining == nil)
        #expect(allowance.canStartGame)
        allowance.recordGameStarted()
        #expect(allowance.gamesPlayed == 10)
    }

    @Test func revokedUnlimitedFallsBackToRemainingGames() {
        var allowance = GameAllowance(gamesPlayed: 12, purchasedGames: 10, hasUnlimited: true)
        allowance.hasUnlimited = false
        #expect(allowance.remaining == 8)
    }

    @Test func codableRoundTrip() throws {
        var allowance = GameAllowance(gamesPlayed: 3, hasUnlimited: true)
        allowance.addPack(transactionID: 9)
        let decoded = try JSONDecoder().decode(GameAllowance.self, from: JSONEncoder().encode(allowance))
        #expect(decoded == allowance)
    }
}
