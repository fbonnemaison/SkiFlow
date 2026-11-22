import CoreGraphics
import Foundation
import Testing
@testable import SkiFlow

struct LandscapeFrequencyTests {
    /// Proporción de un tipo en la tabla de pesos de una banda.
    private func share(_ kind: ObstacleKind, in band: AltitudeBand) -> Double {
        let total = band.weights.reduce(0) { $0 + $1.weight }
        return band.weights.filter { $0.kind == kind }.reduce(0) { $0 + $1.weight } / total
    }

    @Test func cactusIceAndRefugiosAreRarer() {
        // Cactus al 10 %, hielo al 20 % y refugios al 50 % de lo que había en la 1.0.
        #expect(share(.cactus, in: .middle) < 0.02)
        #expect(share(.cactus, in: .low) < 0.01)
        #expect(share(.iceZone, in: .high) < 0.025)
        #expect(share(.iceZone, in: .middle) < 0.01)
        for band in AltitudeBand.allCases {
            #expect(share(.refugio, in: band) < 0.02)
            #expect(share(.refugio, in: band) > 0)
        }
    }

    @Test func iceIsRarerOnTheMountainToo() {
        let generator = MountainGenerator(seed: 2024)
        var ice = 0
        var rocks = 0
        for y in 0...16 {
            for x in -4...4 {
                for obstacle in generator.obstacles(in: ChunkCoord(x: x, y: y)) {
                    if obstacle.kind == .iceZone { ice += 1 }
                    if obstacle.kind == .rock { rocks += 1 }
                }
            }
        }
        #expect(rocks > 0)
        #expect(ice * 5 < rocks)
    }
}

struct GringoTests {
    private let dt = 1.0 / 120.0
    private let view = CGSize(width: 1024, height: 768)

    /// Primer Gringo que aparece con alguna semilla.
    private func firstGringo(skier: SkierState, camera: CGPoint) -> (RivalSkiers, RivalSkier, Double)? {
        for seed in UInt64(1)...40 {
            var rivals = RivalSkiers(config: .init(maxActive: 1, spawnInterval: 0...0), seed: seed)
            for i in 0..<Int(3 / dt) {
                let time = Double(i) * dt
                _ = rivals.update(dt: dt, time: time, skier: skier, camera: camera, viewSize: view)
                if let gringo = rivals.skiers.first(where: { $0.kind == .gringo }) {
                    return (rivals, gringo, time)
                }
            }
        }
        return nil
    }

    @Test func speaksEnglishAndIsAnObstacle() {
        #expect(RivalKind.gringo.lines.contains("Sorry, I'm lost!"))
        #expect(!RivalKind.gringo.crashLines.isEmpty)
        #expect(RivalKind.gringo.walksAcross)
        #expect(!RivalKind.argentine.walksAcross)
        #expect(CollisionResolver.effect(of: .gringo, airborne: false) == .crash)
        #expect(CollisionResolver.effect(of: .gringo, airborne: true) == nil)
    }

    @Test func walksSlowlyAcrossInFrontOfTheCuico() throws {
        let camera = CGPoint(x: 0, y: -5000)
        let cuico = SkierState(position: CGPoint(x: 0, y: -4800), speed: 400)
        let (start, gringo, time) = try #require(firstGringo(skier: cuico, camera: camera))
        var rivals = start
        // Aparece justo por debajo del borde de la pantalla, cerca de la línea del Cuico.
        #expect(Double(gringo.position.y) < -5000 - 384)
        #expect(abs(Double(gringo.position.x)) <= 200)
        #expect(abs(gringo.walkSpeed) >= 35 && abs(gringo.walkSpeed) <= 60)
        #expect(gringo.facesLeft(at: time) == (gringo.walkSpeed < 0))

        for i in 1...Int(2 / dt) {
            _ = rivals.update(dt: dt, time: time + Double(i) * dt, skier: cuico, camera: camera, viewSize: view)
        }
        let later = try #require(rivals.skiers.first { $0.id == gringo.id })
        // Solo se mueve en horizontal, despacio y hacia la línea del Cuico.
        #expect(later.position.y == gringo.position.y)
        let moved = Double(later.position.x - gringo.position.x)
        #expect(abs(moved - gringo.walkSpeed * 2) < 1)
        #expect(abs(Double(later.position.x)) < abs(Double(gringo.position.x)) || abs(Double(later.position.x)) < 130)
    }

    @Test func wearsBlue() {
        let colours = Set(RivalArt.gringo.pixels().flatMap { $0 }.compactMap { $0 })
        #expect(colours.contains(0x2F6FD6))
        #expect(!colours.contains(0x74ACDF))
    }
}

struct WeatherTests {
    private let dt = 1.0 / 60.0

    private func record(_ weather: inout Weather, seconds: Double) -> [WeatherEvent] {
        (0..<Int(seconds / dt)).flatMap { _ in weather.update(dt: dt) }
    }

    @Test func sameSeedSameWeather() {
        var a = Weather(seed: 42)
        var b = Weather(seed: 42)
        #expect(record(&a, seconds: 200) == record(&b, seconds: 200))
        #expect(a.cloudCover == b.cloudCover)
        #expect(a.gust == b.gust)
    }

    @Test func cloudsComeAndGoSoftly() {
        var weather = Weather(seed: 7)
        var maxCover = 0.0
        var maxJump = 0.0
        var previous = 0.0
        var events: [WeatherEvent] = []
        for _ in 0..<Int(300 / dt) {
            events += weather.update(dt: dt)
            maxCover = max(maxCover, weather.cloudCover)
            maxJump = max(maxJump, abs(weather.cloudCover - previous))
            previous = weather.cloudCover
        }
        #expect(events.contains(.cloudsRolledIn))
        #expect(events.contains(.cloudsCleared))
        #expect(maxCover > 0.4 && maxCover <= 1)
        #expect(maxJump <= 0.25 * dt + 1e-9) // fundido suave
    }

    @Test func gustsBlowNowAndThen() {
        var weather = Weather(seed: 9)
        var strongest = 0.0
        var gustyTime = 0.0
        var events: [WeatherEvent] = []
        let seconds = 300.0
        for _ in 0..<Int(seconds / dt) {
            events += weather.update(dt: dt)
            strongest = max(strongest, abs(weather.gust))
            if weather.isGusting { gustyTime += dt }
        }
        let starts = events.filter { if case .gustStarted = $0 { true } else { false } }.count
        #expect(starts >= 4)
        #expect(strongest > 40 && strongest <= 85)
        // Solo en ciertas ocasiones: la mayor parte del tiempo hay calma.
        #expect(gustyTime < seconds * 0.35)
    }

    @Test func noGustsWhenDisabled() {
        var weather = Weather(config: .init(hasGusts: false), seed: 9)
        let events = record(&weather, seconds: 300)
        #expect(!events.contains { if case .gustStarted = $0 { true } else { false } })
        #expect(weather.gust == 0)
    }

    @Test func gustsPushTheCuicoButBringNoWhiteout() {
        let physics = SkierPhysics()
        var state = SkierState(speed: 300)
        let terrain = Terrain(gust: 80)
        #expect(!terrain.isWhiteout)
        for _ in 0..<60 { physics.step(&state, dt: dt, environment: terrain) }
        #expect(state.position.x > 70)
    }

    @Test func slalomModesHaveNoGusts() {
        #expect(GameMode.freeDescent.hasGusts)
        #expect(GameMode.freestyle.hasGusts)
        #expect(!GameMode.slalom.hasGusts)
        #expect(!GameMode.treeSlalom.hasGusts)
    }
}

struct HelpLinksTests {
    @Test func helpOpensTheGitHubWiki() {
        #expect(HelpLinks.wiki.absoluteString == "https://github.com/fbonnemaison/SkiFlow/wiki")
        #expect(HelpLinks.controls.absoluteString == "https://github.com/fbonnemaison/SkiFlow/wiki/Controles")
        // Los acentos se codifican para que el enlace funcione en cualquier navegador.
        #expect(HelpLinks.mountain.absoluteString == "https://github.com/fbonnemaison/SkiFlow/wiki/La-monta%C3%B1a")
        #expect(HelpLinks.issues.absoluteString.hasSuffix("/SkiFlow/issues"))
    }
}
