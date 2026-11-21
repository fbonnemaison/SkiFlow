import Testing
@testable import SkiFlow

struct SkierPhysicsTests {
    let physics = SkierPhysics()
    let dt = 1.0 / 120.0

    private func run(_ state: inout SkierState, seconds: Double) {
        for _ in 0..<Int(seconds / dt) {
            physics.step(&state, dt: dt)
        }
    }

    @Test func goingStraightDownAcceleratesTowardsTerminalSpeed() {
        var state = SkierState(direction: .down)
        run(&state, seconds: 0.5)
        let early = state.speed
        run(&state, seconds: 10)

        #expect(early > 0)
        #expect(state.speed > early)
        #expect(abs(state.speed - physics.terminalSpeed) < 1)
        #expect(state.speed <= physics.maxSpeed)
        #expect(state.position.y < 0)
        #expect(abs(state.position.x) < 1e-6)
    }

    @Test func steeperDirectionsAreFaster() {
        var straight = SkierState(direction: .down)
        var diagonal = SkierState(direction: .right2)
        var shallow = SkierState(direction: .right3)
        run(&straight, seconds: 3)
        run(&diagonal, seconds: 3)
        run(&shallow, seconds: 3)

        #expect(straight.speed > diagonal.speed)
        #expect(diagonal.speed > shallow.speed)
    }

    @Test func sidewaysSkisBrakeToAFullStop() {
        var state = SkierState(direction: .hardLeft, speed: physics.terminalSpeed)
        run(&state, seconds: 1.5)
        #expect(state.speed == 0)

        let stopped = state.position
        run(&state, seconds: 1)
        #expect(state.position == stopped)
    }

    @Test func brakingSkidsDownhillWithoutSlidingSideways() {
        var state = SkierState(direction: .hardRight, speed: physics.terminalSpeed)
        run(&state, seconds: 1.5)
        #expect(state.position.x == 0)
        #expect(state.position.y < 0)
    }

    @Test func diagonalMovesSideways() {
        var left = SkierState(direction: .left2)
        var right = SkierState(direction: .right2)
        run(&left, seconds: 1)
        run(&right, seconds: 1)

        #expect(left.position.x < 0)
        #expect(right.position.x > 0)
        #expect(abs(left.position.x + right.position.x) < 1e-6)
    }

    @Test func distanceAndSpeedConversions() {
        let state = SkierState(
            position: .init(x: 0, y: -GameConfig.pointsPerMeter * 100),
            speed: GameConfig.pointsPerMeter * 10
        )
        #expect(abs(state.distanceMeters - 100) < 1e-9)
        #expect(abs(state.speedKmh - 36) < 1e-9)
        #expect(SkierState(position: .init(x: 0, y: 50)).distanceMeters == 0)
    }
}
