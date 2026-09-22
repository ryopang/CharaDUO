import CoreGraphics
import Testing
@testable import Posture

struct FoldGeometryTests {
    private let container = CGSize(width: 400, height: 900)

    @Test func splitsAroundTheReportedCreaseNotAMidpoint() {
        // Deliberately off-centre: an implementation that assumed 50/50 would
        // pass a centred fixture and fail here.
        let division = CGRect(x: 0, y: 380, width: 400, height: 40)
        let split = FoldGeometry.split(container: container, division: division)

        #expect(split?.lid == CGRect(x: 0, y: 0, width: 400, height: 380))
        #expect(split?.crease == CGRect(x: 0, y: 380, width: 400, height: 40))
        #expect(split?.flat == CGRect(x: 0, y: 420, width: 400, height: 480))
    }

    @Test func returnsNilWithoutADivision() {
        #expect(FoldGeometry.split(container: container, division: nil) == nil)
    }

    @Test func returnsNilForACreaseRunningTheWrongWay() {
        // A narrow vertical crease can't produce a lid-over-table split.
        let vertical = CGRect(x: 190, y: 0, width: 20, height: 900)
        #expect(FoldGeometry.split(container: container, division: vertical) == nil)
    }

    @Test func returnsNilWhenTheCreaseLeavesNoRoomOnOneSide() {
        let atTop = CGRect(x: 0, y: 0, width: 400, height: 40)
        let atBottom = CGRect(x: 0, y: 860, width: 400, height: 40)
        #expect(FoldGeometry.split(container: container, division: atTop) == nil)
        #expect(FoldGeometry.split(container: container, division: atBottom) == nil)
    }

    @Test func returnsNilForAnEmptyContainer() {
        let division = CGRect(x: 0, y: 380, width: 400, height: 40)
        #expect(FoldGeometry.split(container: .zero, division: division) == nil)
    }

    @Test func flatHalfPutsFarEdgeAtTheCreaseAndSplitsHitZonesEvenly() {
        let flat = CGRect(x: 0, y: 420, width: 400, height: 480)
        let layout = FoldGeometry.flatHalfLayout(flat: flat, farEdgeFraction: 0.25)

        // Far edge is adjacent to the crease (PRD §3.2), rotated 180° for the
        // guessers by the view layer.
        #expect(layout.farEdge == CGRect(x: 0, y: 420, width: 400, height: 120))
        // Correct sits toward the crease, Skip toward the describer.
        #expect(layout.correct == CGRect(x: 0, y: 540, width: 400, height: 180))
        #expect(layout.skip == CGRect(x: 0, y: 720, width: 400, height: 180))
    }

    @Test func hitZonesConsumeEverythingLeftWithNoDeadSpace() {
        // PRD §2.1 — no margins or dead space; a blind, angled stab must land.
        let flat = CGRect(x: 0, y: 100, width: 400, height: 500)
        let layout = FoldGeometry.flatHalfLayout(flat: flat)

        #expect(layout.farEdge.minY == flat.minY)
        #expect(layout.correct.minY == layout.farEdge.maxY)
        #expect(layout.skip.minY == layout.correct.maxY)
        #expect(layout.skip.maxY == flat.maxY)
        #expect(layout.correct.height == layout.skip.height)
    }

    @Test func farEdgeFractionIsClamped() {
        let flat = CGRect(x: 0, y: 0, width: 400, height: 400)
        let negative = FoldGeometry.flatHalfLayout(flat: flat, farEdgeFraction: -1)
        #expect(negative.farEdge.height == 0)
        #expect(negative.correct.height == 200)

        let huge = FoldGeometry.flatHalfLayout(flat: flat, farEdgeFraction: 5)
        #expect(huge.farEdge.height == 240) // clamped to 0.6
        #expect(huge.skip.height == 80)
    }
}
