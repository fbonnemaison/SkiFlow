import Testing
@testable import SkiFlow

struct FixedTimestepTests {
    @Test func accumulatesPartialFrames() {
        var timestep = FixedTimestep(step: 0.01)
        #expect(timestep.advance(by: 0.004) == 0)
        #expect(timestep.advance(by: 0.004) == 0)
        #expect(timestep.advance(by: 0.004) == 1)
        #expect(timestep.advance(by: 0.035) == 3)
    }

    @Test func clampsLongFramesAndNegativeDeltas() {
        var timestep = FixedTimestep(step: 0.01, maxFrameDelta: 0.1)
        #expect(timestep.advance(by: 5) == 10)
        #expect(timestep.advance(by: -1) == 0)
    }
}

struct SkierControllerTests {
    @Test func pressTurnsImmediately() {
        var controller = SkierController()
        var direction = SkiDirection.down
        controller.press(.left, direction: &direction)
        #expect(direction == .left1)
        controller.press(.down, direction: &direction)
        #expect(direction == .down)
        controller.press(.right, direction: &direction)
        controller.press(.brake, direction: &direction)
        #expect(direction == .hardRight)
    }

    @Test func holdingRepeatsAfterDelay() {
        var controller = SkierController(repeatDelay: 0.2, repeatInterval: 0.1)
        var direction = SkiDirection.down
        controller.press(.right, direction: &direction)

        controller.update(held: [.right], dt: 0.15, direction: &direction)
        #expect(direction == .right1)

        controller.update(held: [.right], dt: 0.1, direction: &direction)
        #expect(direction == .right2)

        controller.update(held: [.right], dt: 0.1, direction: &direction)
        #expect(direction == .right3)
    }

    @Test func holdingBothSidesDoesNothing() {
        var controller = SkierController(repeatDelay: 0, repeatInterval: 0.01)
        var direction = SkiDirection.down
        controller.update(held: [.left, .right], dt: 1, direction: &direction)
        #expect(direction == .down)
    }
}

struct InputActionTests {
    @Test func mapsArrowsAndWASD() {
        #expect(InputAction(keyCode: 123) == .left)
        #expect(InputAction(keyCode: 0) == .left)
        #expect(InputAction(keyCode: 124) == .right)
        #expect(InputAction(keyCode: 2) == .right)
        #expect(InputAction(keyCode: 125) == .down)
        #expect(InputAction(keyCode: 1) == .down)
        #expect(InputAction(keyCode: 126) == .brake)
        #expect(InputAction(keyCode: 13) == .brake)
        #expect(InputAction(keyCode: 15) == .restart)
        #expect(InputAction(keyCode: 49) == .jump)
        #expect(InputAction(keyCode: 3) == .turbo)
        #expect(InputAction(keyCode: 53) == .pause)
        #expect(InputAction(keyCode: 35) == .pause)
        #expect(InputAction(keyCode: 6) == nil)
        #expect(InputAction(keyCode: 18) == .modeFreeDescent)
        #expect(InputAction(keyCode: 19)?.gameMode == .slalom)
        #expect(InputAction(keyCode: 20)?.gameMode == .treeSlalom)
    }
}

struct SeededRandomTests {
    @Test func sameSeedGivesSameSequence() {
        var a = SeededRandom(seed: 42)
        var b = SeededRandom(seed: 42)
        var c = SeededRandom(seed: 43)
        let seqA = (0..<5).map { _ in a.next() }
        let seqB = (0..<5).map { _ in b.next() }
        let seqC = (0..<5).map { _ in c.next() }
        #expect(seqA == seqB)
        #expect(seqA != seqC)
    }
}
