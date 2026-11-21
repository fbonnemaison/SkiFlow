import CoreGraphics
import Foundation
import Testing
@testable import SkiFlow

struct RivalSkiersTests {
    private let dt = 1.0 / 120.0
    private let view = CGSize(width: 1024, height: 768)

    private func run(_ rivals: inout RivalSkiers, seconds: Double, skier: SkierState, camera: CGPoint = .zero) -> [RivalEvent] {
        var events: [RivalEvent] = []
        for i in 0..<Int(seconds / dt) {
            events += rivals.update(dt: dt, time: Double(i) * dt, skier: skier, camera: camera, viewSize: view)
        }
        return events
    }

    @Test func everyRivalHasThingsToSay() {
        for kind in RivalKind.allCases {
            #expect(!kind.lines.isEmpty)
            #expect(!kind.crashLines.isEmpty)
        }
    }

    @Test func appearOffScreenAheadOfAFastCuico() {
        var rivals = RivalSkiers(seed: 1)
        let fast = SkierState(speed: 500)
        let events = run(&rivals, seconds: 3, skier: fast, camera: CGPoint(x: 0, y: -10_000))
        #expect(events.contains { if case .appeared = $0 { true } else { false } })
        let rival = rivals.skiers[0]
        // Aparece por debajo del borde inferior de la pantalla.
        #expect(Double(rival.position.y) < -10_000 - 384)
    }

    @Test func appearBehindASlowCuico() {
        var rivals = RivalSkiers(seed: 1)
        _ = run(&rivals, seconds: 2.1, skier: SkierState(speed: 0), camera: .zero)
        let rival = rivals.skiers[0]
        #expect(Double(rival.position.y) > 300)
    }

    @Test func neverMoreThanTheLimitAndTheyLeaveWhenFar() {
        var rivals = RivalSkiers(config: .init(maxActive: 2, spawnInterval: 0.5...0.6), seed: 3)
        var events: [RivalEvent] = []
        for i in 0..<Int(60 / dt) {
            events += rivals.update(dt: dt, time: Double(i) * dt, skier: SkierState(), camera: .zero, viewSize: view)
            #expect(rivals.skiers.count <= 2)
        }
        // Con la cámara quieta, los rivales bajan, se alejan y se retiran.
        #expect(events.contains { if case .left = $0 { true } else { false } })
    }

    @Test func talkWhenCloseButNotNonStop() {
        var rivals = RivalSkiers(config: .init(spawnInterval: 0...0, talkCooldown: 6), seed: 5)
        // Un Cuico parado justo donde pasan los rivales que aparecen por arriba.
        var talks = 0
        for i in 0..<Int(8 / dt) {
            let rivalX = rivals.skiers.first?.position.x ?? 0
            let rivalY = rivals.skiers.first?.position.y ?? 0
            let cuico = SkierState(position: CGPoint(x: rivalX, y: rivalY - 100))
            for event in rivals.update(dt: dt, time: Double(i) * dt, skier: cuico, camera: .zero, viewSize: view) {
                if case let .says(_, line) = event {
                    talks += 1
                    #expect(RivalKind.allCases.contains { $0.lines.contains(line) })
                }
            }
        }
        #expect(talks >= 1)
        #expect(talks <= 4) // con 6 s de pausa entre frases de cada rival
    }

    @Test func complainWhenHit() {
        var rivals = RivalSkiers(seed: 2)
        _ = run(&rivals, seconds: 2.1, skier: SkierState(), camera: .zero)
        let rival = rivals.skiers[0]
        let line = rivals.crashLine(for: rival.id, time: 3)
        #expect(line.map(rival.kind.crashLines.contains) == true)
        #expect(rivals.crashLine(for: 999, time: 3) == nil)
    }

    @Test func rivalsAreObstaclesButCanBeJumped() {
        #expect(CollisionResolver.effect(of: .argentine, airborne: false) == .crash)
        #expect(CollisionResolver.effect(of: .brazilian, airborne: true) == nil)
    }
}

struct FaunaTests {
    private func census(rows: ClosedRange<Int>) -> [ObstacleKind: Int] {
        let generator = MountainGenerator(seed: 2024)
        var counts: [ObstacleKind: Int] = [:]
        for y in rows {
            for x in -4...4 {
                for obstacle in generator.obstacles(in: ChunkCoord(x: x, y: y)) {
                    counts[obstacle.kind, default: 0] += 1
                }
            }
        }
        return counts
    }

    @Test func camelidsAreRareFoxesCommonPumasRarer() {
        let counts = census(rows: 0...80)
        let camelids = (counts[.llama] ?? 0) + (counts[.guanaco] ?? 0) + (counts[.vicuna] ?? 0)
        let foxes = counts[.fox] ?? 0
        let pumas = counts[.puma] ?? 0
        #expect(foxes > 0)
        #expect(pumas > 0)
        #expect(foxes > pumas * 2)
        #expect(camelids < foxes / 4)
    }

    @Test func foxesRunAndPumasProwl() {
        let generator = MountainGenerator(seed: 2024)
        let animals = (0...60).flatMap { y in (-3...3).flatMap { generator.obstacles(in: ChunkCoord(x: $0, y: y)) } }
        let fox = animals.first { $0.kind == .fox }
        let puma = animals.first { $0.kind == .puma }
        guard case let .wander(_, foxSpeed, _) = fox?.motion, case let .wander(_, pumaSpeed, _) = puma?.motion else {
            Issue.record("Faltan zorros o pumas")
            return
        }
        #expect(foxSpeed > pumaSpeed)
    }
}

@MainActor
struct ImprovementsSceneTests {
    private let dt = 1.0 / 120.0

    private func makeScene(_ mode: GameMode = .freeDescent) -> GameScene {
        GameScene(size: GameConfig.sceneSize, seed: 6, mode: mode, kunkConfig: .init(spawnMeters: 1e9), chupacabrasConfig: .init(chance: 0))
    }

    @Test func cuicoWalksSidewaysWhenStoppedAcross() {
        let scene = makeScene()
        scene.handle(.left, pressed: true)
        scene.handle(.left, pressed: false)
        scene.handle(.brake, pressed: true) // atravesado a la izquierda
        scene.handle(.brake, pressed: false)
        #expect(scene.skier.direction == .hardLeft)
        for _ in 0..<60 { scene.simulate(dt: dt) }
        #expect(scene.skier.speed < GameScene.sideStepMaxSpeed)

        let startX = scene.skier.position.x
        scene.handle(.left, pressed: true)
        #expect(scene.skier.position.x == startX - GameScene.sideStepSize)
        // Manteniendo la tecla sigue caminando.
        for _ in 0..<Int(1 / dt) { scene.simulate(dt: dt) }
        #expect(scene.skier.position.x < startX - 4 * GameScene.sideStepSize)
        #expect(scene.skier.direction == .hardLeft)
        scene.handle(.left, pressed: false)

        // Hacia el otro lado, la flecha gira en vez de caminar.
        scene.handle(.right, pressed: true)
        #expect(scene.skier.direction == .left3)
    }

    @Test func noWalkingAtSpeed() {
        let scene = makeScene()
        for _ in 0..<120 { scene.simulate(dt: dt) }
        scene.handle(.brake, pressed: true)
        scene.handle(.brake, pressed: false)
        let x = scene.skier.position.x
        scene.handle(.left, pressed: true)
        #expect(scene.skier.position.x == x) // va rápido: está frenando, no camina
    }

    @Test func rivalsShowUpInFreeDescentButNotInSlalom() {
        let descent = makeScene(.freeDescent)
        for _ in 0..<Int(10 / dt) { descent.simulate(dt: dt) }
        #expect(!descent.rivals.skiers.isEmpty || descent.childNode(withName: "//rival-*") != nil)

        let slalom = makeScene(.slalom)
        for _ in 0..<Int(10 / dt) { slalom.simulate(dt: dt) }
        #expect(slalom.rivals.skiers.isEmpty)
    }

    @Test func restartClearsRivals() {
        let scene = makeScene()
        for _ in 0..<Int(10 / dt) { scene.simulate(dt: dt) }
        scene.restart()
        #expect(scene.rivals.skiers.isEmpty)
        #expect(scene.childNode(withName: "//rival-*") == nil)
    }
}
