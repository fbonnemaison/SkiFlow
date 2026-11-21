import CoreGraphics
import Foundation
import Testing
@testable import SkiFlow

private let dt = 1.0 / 120.0

private func skierAt(meters: Double, x: Double = 0, direction: SkiDirection = .down, speed: Double = 0) -> SkierState {
    SkierState(position: CGPoint(x: x, y: -meters * GameConfig.pointsPerMeter), direction: direction, speed: speed)
}

struct KunkTests {
    @Test func waitsUntilTheSpawnDistance() {
        var kunk = KunkChaser(config: .init(spawnMeters: 2000), side: 1)
        #expect(kunk.update(dt: dt, skier: skierAt(meters: 1999)) == nil)
        #expect(kunk.phase == .waiting)

        let skier = skierAt(meters: 2000)
        #expect(kunk.update(dt: dt, skier: skier) == .appeared)
        #expect(kunk.phase == .chasing)
        // Aparece por encima (fuera de pantalla) y del lado elegido.
        #expect(kunk.position.y > skier.position.y)
        #expect(kunk.position.x > skier.position.x)
    }

    @Test func catchesAStandingCuico() {
        var kunk = KunkChaser(side: -1)
        let skier = skierAt(meters: 2100)
        var caught = false
        for _ in 0..<Int(5 / dt) {
            if kunk.update(dt: dt, skier: skier) == .caught {
                caught = true
                break
            }
        }
        #expect(caught)
        #expect(kunk.phase == .caught)
    }

    @Test func turboOutrunsTheKunkButNormalSpeedDoesNot() {
        func run(speed: Double) -> Bool {
            var kunk = KunkChaser(config: .init(spawnMeters: 0), side: 1)
            var skier = skierAt(meters: 10, speed: speed)
            for _ in 0..<Int(20 / dt) {
                skier.position.y -= speed * dt
                if kunk.update(dt: dt, skier: skier) == .caught { return true }
            }
            return false
        }
        let physics = SkierPhysics()
        #expect(run(speed: physics.terminalSpeed))
        #expect(!run(speed: physics.turboTerminalSpeed))
    }

    @Test func neverFallsTooFarBehind() {
        var kunk = KunkChaser(config: .init(spawnMeters: 0, maxLag: 1000), side: 1)
        var skier = skierAt(meters: 10)
        _ = kunk.update(dt: dt, skier: skier)
        skier.position.y -= 50_000
        _ = kunk.update(dt: dt, skier: skier)
        #expect(kunk.distance(to: skier) <= 1000)
    }
}

struct ChupacabrasTests {
    @Test func isRareAndDeterministic() {
        var appearances = 0
        let runs = 2000
        for seed in 0..<runs {
            let a = ChupacabrasChaser(seed: UInt64(seed))
            let b = ChupacabrasChaser(seed: UInt64(seed))
            #expect(a.triggerMeters == b.triggerMeters)
            if a.willAppear { appearances += 1 }
        }
        let rate = Double(appearances) / Double(runs)
        #expect(rate > 0.05)
        #expect(rate < 0.11)
    }

    @Test func appearsOnlyInLongRuns() {
        for seed in 0..<500 {
            if let meters = ChupacabrasChaser(seed: UInt64(seed)).triggerMeters {
                #expect(meters >= 800)
                #expect(meters <= 3000)
            }
        }
    }

    private func forced() -> ChupacabrasChaser {
        ChupacabrasChaser(config: .init(chance: 1, minMeters: 100, maxMeters: 100), seed: 7)
    }

    @Test func warnsBeforeAttacking() {
        var chupa = forced()
        #expect(chupa.update(dt: dt, skier: skierAt(meters: 99)) == nil)
        #expect(chupa.update(dt: dt, skier: skierAt(meters: 100)) == .warning)
        #expect(chupa.phase == .warning)
        #expect(!chupa.phase.isVisible)

        var event: ChaserEvent?
        for _ in 0..<Int(2 / dt) {
            event = chupa.update(dt: dt, skier: skierAt(meters: 100))
            if event == .appeared { break }
        }
        #expect(event == .appeared)
        #expect(chupa.phase == .chasing)
    }

    @Test func catchesAStandingCuico() {
        var chupa = forced()
        let skier = skierAt(meters: 100)
        var caught = false
        for _ in 0..<Int(5 / dt) {
            if chupa.update(dt: dt, skier: skier) == .caught {
                caught = true
                break
            }
        }
        #expect(caught)
    }

    @Test func jumpingDodgesItAndThenItLeaves() {
        var chupa = forced()
        var skier = skierAt(meters: 100)
        skier.airTime = 100
        skier.airDuration = 100
        var events: [ChaserEvent] = []
        for _ in 0..<Int(6 / dt) {
            if let event = chupa.update(dt: dt, skier: skier) { events.append(event) }
        }
        #expect(!events.contains(.caught))
        #expect(events.contains(.escaped))
        #expect(chupa.phase == .gone)
    }

    @Test func doesNotAppearWhenNotScheduled() {
        var chupa = ChupacabrasChaser(config: .init(chance: 0), seed: 1)
        #expect(!chupa.willAppear)
        #expect(chupa.update(dt: dt, skier: skierAt(meters: 5000)) == nil)
        #expect(chupa.phase == .waiting)
    }
}

struct GameOverInfoTests {
    @Test func formatsTimeAndText() {
        #expect(GameOverInfo.formatTime(83.7) == "01:23")
        let info = GameOverInfo(caughtBy: .kunk, meters: 2345.4, seconds: 112, crashes: 3)
        #expect(info.title == "¡El Kunk te atrapó!")
        #expect(info.summary == "Bajaste 2345 m en 01:52 · caídas: 3")
    }

    @Test func tuningReadsLaunchArguments() throws {
        let defaults = try #require(UserDefaults(suiteName: "SkiFlowTests.tuning"))
        defaults.removePersistentDomain(forName: "SkiFlowTests.tuning")
        #expect(ChaserTuning.kunk(defaults: defaults).spawnMeters == 2000)

        defaults.set("150", forKey: "kunkSpawnMeters")
        defaults.set("1", forKey: "chupacabrasChance")
        defaults.set("60", forKey: "chupacabrasMeters")
        #expect(ChaserTuning.kunk(defaults: defaults).spawnMeters == 150)
        let chupa = ChaserTuning.chupacabras(defaults: defaults)
        #expect(chupa.chance == 1)
        #expect(chupa.minMeters == 60)
        #expect(chupa.maxMeters == 60)
        defaults.removePersistentDomain(forName: "SkiFlowTests.tuning")
    }
}
