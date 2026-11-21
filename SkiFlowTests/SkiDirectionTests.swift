import Foundation
import Testing
@testable import SkiFlow

struct SkiDirectionTests {
    @Test func hasNinePositionsFromHardLeftToHardRight() {
        #expect(SkiDirection.allCases.count == 9)
        #expect(SkiDirection.allCases.first == .hardLeft)
        #expect(SkiDirection.allCases.last == .hardRight)
    }

    @Test func anglesGoFromMinusNinetyToNinetyDegrees() {
        #expect(SkiDirection.down.angle == 0)
        #expect(abs(SkiDirection.hardLeft.angle + .pi / 2) < 1e-12)
        #expect(abs(SkiDirection.hardRight.angle - .pi / 2) < 1e-12)
    }

    @Test func unitVectorPointsDownhillAndToTheCorrectSide() {
        let down = SkiDirection.down.unitVector
        #expect(abs(down.dx) < 1e-12)
        #expect(down.dy == -1)

        #expect(SkiDirection.left2.unitVector.dx < 0)
        #expect(SkiDirection.right2.unitVector.dx > 0)
        #expect(abs(SkiDirection.hardRight.unitVector.dy) < 1e-12)
    }

    @Test func turningIsClampedAtTheSideways() {
        #expect(SkiDirection.hardLeft.turnedLeft() == .hardLeft)
        #expect(SkiDirection.hardRight.turnedRight() == .hardRight)
        #expect(SkiDirection.down.turnedLeft() == .left1)
        #expect(SkiDirection.down.turnedRight() == .right1)
    }

    @Test func brakingKeepsTheSideYouFace() {
        #expect(SkiDirection.right2.braking() == .hardRight)
        #expect(SkiDirection.left3.braking() == .hardLeft)
        #expect(SkiDirection.down.braking() == .hardLeft)
        #expect(SkiDirection.hardLeft.isSideways)
        #expect(!SkiDirection.right3.isSideways)
    }
}
