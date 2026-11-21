import CoreGraphics
import Foundation
import SpriteKit
import Testing
@testable import SkiFlow

struct SlalomCourseTests {
    @Test func sameSeedSameCourse() {
        #expect(SlalomCourse(seed: 5) == SlalomCourse(seed: 5))
        #expect(SlalomCourse(seed: 5) != SlalomCourse(seed: 6))
    }

    @Test func gatesGoDownhillAndZigzag() {
        let course = SlalomCourse(seed: 42)
        #expect(course.gates.count == 20)
        for (a, b) in zip(course.gates, course.gates.dropFirst()) {
            #expect(b.y < a.y)
            #expect(a.isRed != b.isRed)
        }
        #expect(course.finishY < course.gates.last!.y)
        let maxOffset = SlalomCourse.Config.slalom.maxOffset
        #expect(course.gates.allSatisfy { abs($0.centerX) <= maxOffset })
    }

    @Test func clearingsKeepGatesFreeOfObstacles() {
        let course = SlalomCourse(seed: 9, config: .treeSlalom)
        let generator = MountainGenerator(seed: 9, profile: .treeSlalom, exclusions: course.clearings)
        for gate in course.gates {
            let coord = MountainGenerator.coord(containing: CGPoint(x: gate.centerX, y: gate.y))
            let gap = CGRect(x: gate.leftX, y: gate.y - 40, width: gate.width, height: 80)
            for obstacle in generator.obstacles(in: coord) where !obstacle.kind.isZone && obstacle.kind != .condor {
                #expect(!gap.contains(obstacle.origin))
            }
        }
    }

    @Test func profilesChangeTheDensity() {
        func count(_ profile: MountainGenerator.Profile) -> Int {
            let generator = MountainGenerator(seed: 3, profile: profile)
            return (0..<10).reduce(0) { $0 + generator.obstacles(in: ChunkCoord(x: 0, y: $1)).count }
        }
        #expect(count(.slalom) < count(.freeDescent))
        #expect(count(.treeSlalom) > count(.slalom))
    }

    @Test func treeSlalomIsAForest() {
        let generator = MountainGenerator(seed: 4, profile: .treeSlalom)
        let kinds = (0..<6).flatMap { generator.obstacles(in: ChunkCoord(x: 0, y: $0)) }.map(\.kind)
        let trees = kinds.filter { $0 == .araucaria || $0 == .quenua }.count
        #expect(Double(trees) / Double(kinds.count) > 0.6)
        #expect(!kinds.contains(.liftPylon))
    }
}

struct SlalomProgressTests {
    private let course = SlalomCourse(seed: 1)

    @Test func passingThroughAGate() {
        var progress = SlalomProgress(course: course)
        let gate = course.gates[0]
        let events = progress.advance(
            from: CGPoint(x: gate.centerX, y: gate.y + 10),
            to: CGPoint(x: gate.centerX, y: gate.y - 10)
        )
        #expect(events == [.passed(gate: 0)])
        #expect(progress.nextGate == 1)
    }

    @Test func missingAGateAddsPenalty() {
        var progress = SlalomProgress(course: course)
        let gate = course.gates[0]
        let events = progress.advance(
            from: CGPoint(x: gate.rightX + 50, y: gate.y + 10),
            to: CGPoint(x: gate.rightX + 50, y: gate.y - 10)
        )
        #expect(events == [.missed(gate: 0)])
        #expect(progress.penaltySeconds == SlalomProgress.missPenalty)
    }

    @Test func crossingIsInterpolated() {
        // Entra por fuera y cruza la línea justo dentro de la puerta.
        let x = SlalomProgress.crossingX(from: CGPoint(x: 0, y: 10), to: CGPoint(x: 100, y: -10), atY: 0)
        #expect(abs(x - 50) < 1e-9)
    }

    @Test func goingUphillDoesNotCount() {
        var progress = SlalomProgress(course: course)
        let gate = course.gates[0]
        let events = progress.advance(
            from: CGPoint(x: gate.centerX, y: gate.y - 10),
            to: CGPoint(x: gate.centerX, y: gate.y + 10)
        )
        #expect(events.isEmpty)
    }

    @Test func finishAfterTheLastGate() {
        var progress = SlalomProgress(course: course)
        // Un salto enorme cruza todas las puertas (por fuera) y la meta.
        let events = progress.advance(
            from: CGPoint(x: 5000, y: 0),
            to: CGPoint(x: 5000, y: course.finishY - 1)
        )
        #expect(events.count == course.gates.count + 1)
        #expect(events.last == .finished)
        #expect(progress.isFinished)
        #expect(progress.advance(from: .zero, to: CGPoint(x: 0, y: -1_000_000)).isEmpty)
    }

    @Test func resultText() {
        #expect(SlalomResult.formatTime(83.47) == "01:23.4")
        #expect(SlalomResult.formatTime(75.3) == "01:15.3")
        #expect(SlalomResult.formatTime(59.99) == "00:59.9")
        let clean = SlalomResult(seconds: 41.2, gatesPassed: 20, gatesTotal: 20, penaltySeconds: 0)
        #expect(clean.summary == "Tiempo 00:41.2 · ¡todas las puertas!")
        let messy = SlalomResult(seconds: 41.2, gatesPassed: 18, gatesTotal: 20, penaltySeconds: 10)
        #expect(messy.totalSeconds == 51.2)
        #expect(messy.summary == "00:41.2 + 2 puertas falladas (+10 s) = 00:51.2")
    }
}

struct AvalancheTests {
    private let dt = 1.0 / 120.0

    @Test func waitsThenBuriesAStandingCuico() {
        var avalanche = AvalancheChaser(config: .init(delay: 1))
        let skier = SkierState()
        var events: [ChaserEvent] = []
        for _ in 0..<Int(10 / dt) {
            if let event = avalanche.update(dt: dt, skier: skier) { events.append(event) }
        }
        #expect(events == [.appeared, .caught])
    }

    @Test func aGoodSkierStaysAhead() {
        var avalanche = AvalancheChaser()
        var skier = SkierState()
        for _ in 0..<Int(60 / dt) {
            skier.position.y -= 400 * dt
            #expect(avalanche.update(dt: dt, skier: skier) != .caught)
        }
        #expect(avalanche.gap(to: skier) > 0)
    }

    @Test func stopsAtTheFinish() {
        var avalanche = AvalancheChaser(config: .init(delay: 0))
        _ = avalanche.update(dt: dt, skier: SkierState())
        avalanche.stop()
        #expect(avalanche.phase == .gone)
        #expect(avalanche.update(dt: 100, skier: SkierState()) == nil)
    }
}

@MainActor
struct SlalomSceneTests {
    private let dt = 1.0 / 120.0

    /// Un "piloto" que apunta con el ratón a la siguiente puerta.
    private func ride(_ scene: GameScene, maxSeconds: Double = 120) {
        var steps = 0
        while !scene.isRunOver, scene.caughtBy == nil, steps < Int(maxSeconds / dt) {
            if let progress = scene.slalom {
                let course = progress.course
                let target: CGPoint
                if progress.nextGate < course.gates.count {
                    let gate = course.gates[progress.nextGate]
                    target = CGPoint(x: gate.centerX, y: gate.y - 60)
                } else {
                    target = CGPoint(x: scene.skier.position.x, y: course.finishY - 200)
                }
                // El apuntado se guarda relativo a la cámara.
                let camera = scene.camera!.position
                scene.aimMouse(atScenePoint: CGPoint(
                    x: target.x - scene.skier.position.x + camera.x + (scene.skier.position.x - camera.x),
                    y: target.y
                ))
            }
            scene.simulate(dt: dt)
            scene.update(Double(steps) * dt)
            steps += 1
        }
    }

    @Test func slalomCanBeFinishedAheadOfTheAvalanche() throws {
        let scene = GameScene(size: GameConfig.sceneSize, seed: 11, mode: .slalom)
        ride(scene)
        #expect(scene.caughtBy == nil)
        let result = try #require(scene.slalomResult)
        #expect(result.gatesPassed >= 17)
        #expect(scene.avalanche.phase == .gone)
    }

    @Test func noCreaturesInSlalom() {
        let scene = GameScene(
            size: GameConfig.sceneSize, seed: 11, mode: .slalom,
            kunkConfig: .init(spawnMeters: 0), chupacabrasConfig: .init(chance: 1, minMeters: 1, maxMeters: 1)
        )
        for _ in 0..<Int(3 / dt) {
            scene.simulate(dt: dt)
        }
        #expect(scene.kunk.phase == .waiting)
        #expect(scene.chupacabras.phase == .waiting)
    }

    @Test func standingStillGetsBuried() {
        let scene = GameScene(size: GameConfig.sceneSize, seed: 11, mode: .treeSlalom)
        scene.handle(.brake, pressed: true)
        for _ in 0..<Int(15 / dt) {
            scene.simulate(dt: dt)
        }
        #expect(scene.caughtBy == .avalanche)
        for _ in 0..<Int(2 / dt) {
            scene.simulate(dt: dt)
        }
        #expect(scene.gameOver?.caughtBy == .avalanche)
    }

    @Test func modeKeysSwitchModesAndRestartRepeatsTheCourse() {
        let scene = GameScene(size: GameConfig.sceneSize, mode: .freeDescent)
        scene.handle(.modeSlalom, pressed: true)
        scene.handle(.modeSlalom, pressed: false)
        #expect(scene.mode == .slalom)
        let course = scene.slalom?.course

        for _ in 0..<60 { scene.simulate(dt: dt) }
        scene.handle(.restart, pressed: true)
        scene.handle(.restart, pressed: false)
        #expect(scene.slalom?.course == course)
        #expect(scene.slalom?.nextGate == 0)

        scene.handle(.modeTreeSlalom, pressed: true)
        #expect(scene.mode == .treeSlalom)
        #expect(scene.slalom?.course != course)
    }
}

@MainActor
struct SlalomLiftTests {
    @Test func noLiftInSlalomModes() {
        let generator = MountainGenerator(seed: 2, profile: .slalom)
        let mountain = MountainNode(seed: 2)
        mountain.reset(generator: generator)
        mountain.updateLoadedChunks(center: CGPoint(x: generator.liftX, y: -3000), viewSize: GameConfig.sceneSize, time: 0)
        let chairs = mountain.children.flatMap(\.children).filter { ($0 as? SKSpriteNode)?.anchorPoint == CGPoint(x: 0.5, y: 0.85) }
        #expect(chairs.isEmpty)
    }
}
