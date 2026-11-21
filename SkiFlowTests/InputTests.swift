import CoreGraphics
import Testing
@testable import SkiFlow

struct AimingTests {
    @Test func aimingDownhillAndDiagonals() {
        #expect(SkiDirection.aiming(at: CGVector(dx: 0, dy: -100)) == .down)
        #expect(SkiDirection.aiming(at: CGVector(dx: 100, dy: -100)) == .right2)
        #expect(SkiDirection.aiming(at: CGVector(dx: -100, dy: -100)) == .left2)
        #expect(SkiDirection.aiming(at: CGVector(dx: -100, dy: -5)) == .hardLeft)
    }

    @Test func aimingUphillBrakesTowardsThatSide() {
        #expect(SkiDirection.aiming(at: CGVector(dx: 30, dy: 100)) == .hardRight)
        #expect(SkiDirection.aiming(at: CGVector(dx: -30, dy: 100)) == .hardLeft)
    }

    @Test func stickWinsOverMouseAndRespectsDeadZone() {
        var input = InputState()
        let skier = CGPoint(x: 0, y: -1000)
        let camera = CGPoint(x: 0, y: -1150)

        #expect(input.aimDirection(skier: skier, camera: camera) == nil)

        // Cursor abajo a la derecha del Cuico, en coordenadas de cámara.
        input.mouseAim = CGPoint(x: 200, y: -50)
        #expect(input.aimDirection(skier: skier, camera: camera) == .right2)

        // Cursor encima del Cuico: no cambia nada.
        input.mouseAim = CGPoint(x: 5, y: 150)
        #expect(input.aimDirection(skier: skier, camera: camera) == nil)

        input.stickAim = CGVector(dx: 0.1, dy: 0.1)
        input.mouseAim = CGPoint(x: -300, y: -150)
        #expect(input.aimDirection(skier: skier, camera: camera) == .left2)

        input.stickAim = CGVector(dx: 0, dy: -0.9)
        #expect(input.aimDirection(skier: skier, camera: camera) == .down)
    }
}

struct InputStateTests {
    @Test func pressEdgeOnlyOncePerAction() {
        var input = InputState()
        let first = input.set(.jump, pressed: true, source: .keyboard)
        let repeated = input.set(.jump, pressed: true, source: .keyboard)
        let otherDevice = input.set(.jump, pressed: true, source: .gamepad)
        #expect(first)
        #expect(!repeated)
        #expect(!otherDevice)
        #expect(input.held == [.jump])
    }

    @Test func releasingOneDeviceKeepsTheOther() {
        var input = InputState()
        input.set(.turbo, pressed: true, source: .keyboard)
        input.set(.turbo, pressed: true, source: .gamepad)
        input.set(.turbo, pressed: false, source: .keyboard)
        #expect(input.held.contains(.turbo))
        input.set(.turbo, pressed: false, source: .gamepad)
        #expect(input.held.isEmpty)
    }

    @Test func releaseAllClearsEverything() {
        var input = InputState()
        input.set(.left, pressed: true, source: .keyboard)
        input.stickAim = CGVector(dx: 1, dy: 0)
        input.releaseAll()
        #expect(input.held.isEmpty)
        #expect(input.stickAim == .zero)
    }
}

struct SteeringTests {
    @Test func steersOneStepAtATimeTowardsTheAim() {
        var controller = SkierController(aimStepInterval: 0.05)
        var direction = SkiDirection.hardLeft

        controller.steer(toward: .right2, dt: 0.01, direction: &direction)
        #expect(direction == .left3)

        controller.steer(toward: .right2, dt: 0.05, direction: &direction)
        #expect(direction == .left2)

        for _ in 0..<20 {
            controller.steer(toward: .right2, dt: 0.05, direction: &direction)
        }
        #expect(direction == .right2)
    }
}

struct GamepadTests {
    @Test func transitionsBetweenSnapshots() {
        let idle = GamepadState()
        let jumping = GamepadState(held: [.jump, .turbo])
        let turboOnly = GamepadState(held: [.turbo])

        let first = GamepadState.transitions(from: idle, to: jumping)
        #expect(first.count == 2)
        #expect(first.allSatisfy { $0.pressed })

        let second = GamepadState.transitions(from: jumping, to: turboOnly)
        #expect(second.count == 1)
        #expect(second[0].action == .jump)
        #expect(!second[0].pressed)

        #expect(GamepadState.transitions(from: turboOnly, to: turboOnly).isEmpty)
    }
}

struct HopAndTurboPhysicsTests {
    let physics = SkierPhysics()
    let dt = 1.0 / 120.0

    @Test func hopWorksStandingStillButNotTwice() {
        var state = SkierState()
        let first = physics.hop(&state)
        #expect(first)
        #expect(state.isAirborne)
        let second = physics.hop(&state)
        #expect(!second)
    }

    @Test func hopIsShorterThanARampJump() {
        var hop = SkierState(speed: physics.terminalSpeed)
        var ramp = SkierState(speed: physics.terminalSpeed)
        physics.hop(&hop)
        physics.launch(&ramp)
        #expect(hop.airDuration < ramp.airDuration)
    }

    @Test func cannotHopWhileFallen() {
        var state = SkierState()
        state.fallTime = 1
        let hopped = physics.hop(&state)
        #expect(!hopped)
    }

    @Test func turboGoesFasterAndSlowsBackDown() {
        var normal = SkierState()
        var turbo = SkierState()
        for _ in 0..<Int(8 / dt) {
            physics.step(&normal, dt: dt)
            physics.step(&turbo, dt: dt, turbo: true)
        }
        #expect(turbo.speed > normal.speed + 150)
        #expect(turbo.speed <= physics.turboMaxSpeed)

        for _ in 0..<Int(8 / dt) {
            physics.step(&turbo, dt: dt)
        }
        #expect(abs(turbo.speed - physics.terminalSpeed) < 2)
    }
}
