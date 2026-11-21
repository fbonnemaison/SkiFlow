import CoreGraphics
import Testing
@testable import SkiFlow

struct CollisionResolverTests {
    private func snapshot(_ kind: ObstacleKind, at point: CGPoint, zone: CGSize = .zero, wind: Double = 0) -> ObstacleSnapshot {
        ObstacleSnapshot(obstacle: Obstacle(kind: kind, origin: point, zoneSize: zone, windStrength: wind), time: 0)
    }

    @Test func groundRules() {
        #expect(CollisionResolver.effect(of: .araucaria, airborne: false) == .crash)
        #expect(CollisionResolver.effect(of: .llama, airborne: false) == .crash)
        #expect(CollisionResolver.effect(of: .smallRock, airborne: false) == .trip)
        #expect(CollisionResolver.effect(of: .ramp, airborne: false) == .jump)
        #expect(CollisionResolver.effect(of: .condor, airborne: false) == nil)
        #expect(CollisionResolver.effect(of: .iceZone, airborne: false) == nil)
    }

    @Test func airRules() {
        #expect(CollisionResolver.effect(of: .rock, airborne: true) == nil)
        #expect(CollisionResolver.effect(of: .llama, airborne: true) == nil)
        #expect(CollisionResolver.effect(of: .ramp, airborne: true) == nil)
        #expect(CollisionResolver.effect(of: .araucaria, airborne: true) == .crash)
        #expect(CollisionResolver.effect(of: .refugio, airborne: true) == .crash)
        #expect(CollisionResolver.effect(of: .condor, airborne: true) == .crash)
    }

    @Test func hitsOnlyWhenTouching() {
        let rock = snapshot(.rock, at: CGPoint(x: 0, y: -100))
        let touching = SkierState(position: CGPoint(x: 0, y: -95))
        let far = SkierState(position: CGPoint(x: 0, y: -60))

        #expect(CollisionResolver.firstHit(skier: touching, among: [rock])?.effect == .crash)
        #expect(CollisionResolver.firstHit(skier: far, among: [rock]) == nil)
    }

    @Test func jumpingOverARock() {
        let rock = snapshot(.rock, at: CGPoint(x: 0, y: -100))
        var skier = SkierState(position: CGPoint(x: 0, y: -95))
        skier.airTime = 0.5
        skier.airDuration = 1
        #expect(CollisionResolver.firstHit(skier: skier, among: [rock]) == nil)
    }

    @Test func environmentFromZones() {
        let ice = snapshot(.iceZone, at: .zero, zone: CGSize(width: 200, height: 100))
        let deep = snapshot(.deepSnowZone, at: CGPoint(x: 50, y: 0), zone: CGSize(width: 100, height: 100))
        let wind = snapshot(.windZone, at: .zero, zone: CGSize(width: 400, height: 300), wind: -80)

        #expect(CollisionResolver.environment(at: CGPoint(x: -50, y: 0), among: [ice]).surface == .ice)
        #expect(CollisionResolver.environment(at: CGPoint(x: 50, y: 0), among: [ice, deep]).surface == .deepSnow)
        #expect(CollisionResolver.environment(at: CGPoint(x: 500, y: 0), among: [ice, deep]) == Environment())

        let windy = CollisionResolver.environment(at: .zero, among: [wind])
        #expect(windy.wind == -80)
        #expect(windy.isWhiteout)
    }
}

struct SurfacePhysicsTests {
    let physics = SkierPhysics()
    let dt = 1.0 / 120.0

    private func run(_ state: inout SkierState, seconds: Double, environment: Environment = Environment()) {
        for _ in 0..<Int(seconds / dt) {
            physics.step(&state, dt: dt, environment: environment)
        }
    }

    @Test func deepSnowIsSlowerAndIceIsFaster() {
        var snow = SkierState()
        var deep = SkierState()
        var ice = SkierState()
        run(&snow, seconds: 6)
        run(&deep, seconds: 6, environment: Environment(surface: .deepSnow))
        run(&ice, seconds: 6, environment: Environment(surface: .ice))

        #expect(deep.speed < snow.speed * 0.6)
        #expect(ice.speed > snow.speed)
    }

    @Test func iceMakesBrakingHarder() {
        var snow = SkierState(direction: .hardLeft, speed: 400)
        var ice = SkierState(direction: .hardLeft, speed: 400)
        run(&snow, seconds: 0.3)
        run(&ice, seconds: 0.3, environment: Environment(surface: .ice))
        #expect(ice.speed > snow.speed + 100)
    }

    @Test func windPushesSideways() {
        var state = SkierState()
        run(&state, seconds: 2, environment: Environment(wind: 100))
        #expect(state.position.x > 50)
    }

    @Test func rampLaunchDependsOnSpeed() {
        var slow = SkierState(speed: 30)
        #expect(!physics.launch(&slow))
        #expect(!slow.isAirborne)

        var fast = SkierState(speed: physics.terminalSpeed)
        var medium = SkierState(speed: 150)
        #expect(physics.launch(&fast))
        #expect(physics.launch(&medium))
        #expect(fast.airDuration > medium.airDuration)
    }

    @Test func flightKeepsSpeedAndLands() {
        var state = SkierState(direction: .hardLeft, speed: 300)
        physics.launch(&state)
        let duration = state.airDuration
        run(&state, seconds: duration / 2)
        // Atravesado en el aire no frena.
        #expect(state.speed == 300)
        #expect(state.airHeight > 0)
        run(&state, seconds: duration)
        #expect(!state.isAirborne)
        #expect(state.speed < 300)
    }
}
