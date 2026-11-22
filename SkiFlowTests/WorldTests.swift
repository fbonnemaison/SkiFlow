import CoreGraphics
import Foundation
import Testing
@testable import SkiFlow

struct MountainGeneratorTests {
    let generator = MountainGenerator(seed: 12345)

    @Test func sameSeedSameChunk() {
        let coord = ChunkCoord(x: 1, y: 7)
        #expect(generator.obstacles(in: coord) == MountainGenerator(seed: 12345).obstacles(in: coord))
    }

    @Test func differentSeedsGiveDifferentMountains() {
        let coord = ChunkCoord(x: 0, y: 5)
        #expect(generator.obstacles(in: coord) != MountainGenerator(seed: 999).obstacles(in: coord))
    }

    @Test func nothingAboveTheStart() {
        #expect(generator.obstacles(in: ChunkCoord(x: 0, y: -1)).isEmpty)
    }

    @Test func startIsClear() {
        for x in -1...0 {
            for obstacle in generator.obstacles(in: ChunkCoord(x: x, y: 0)) {
                if obstacle.kind.isZone {
                    #expect(!MountainGenerator.startClearing.intersects(obstacle.hitbox(at: 0)))
                } else {
                    #expect(!MountainGenerator.startClearing.contains(obstacle.origin))
                }
            }
        }
    }

    @Test func obstaclesStayInsideTheirChunk() {
        for y in 0..<10 {
            let coord = ChunkCoord(x: 2, y: y)
            let rect = MountainGenerator.rect(for: coord)
            for obstacle in generator.obstacles(in: coord) where obstacle.kind != .condor {
                #expect(rect.contains(obstacle.origin))
            }
        }
    }

    @Test func solidObstaclesKeepTheirDistance() {
        for y in 0..<20 {
            let solids = generator.obstacles(in: ChunkCoord(x: -1, y: y))
                .filter { !$0.kind.isZone && $0.kind != .condor && $0.kind != .liftPylon }
            for (i, a) in solids.enumerated() {
                for b in solids[(i + 1)...] {
                    #expect(hypot(a.origin.x - b.origin.x, a.origin.y - b.origin.y) >= MountainGenerator.minSpacing)
                }
            }
        }
    }

    @Test func densityGrowsWithDistance() {
        func average(rows: ClosedRange<Int>) -> Double {
            var total = 0
            var chunks = 0
            for y in rows {
                for x in -2...2 {
                    total += generator.obstacles(in: ChunkCoord(x: x, y: y)).count
                    chunks += 1
                }
            }
            return Double(total) / Double(chunks)
        }
        #expect(average(rows: 150...160) > average(rows: 2...12) + 4)
    }

    @Test func altitudeBandsChangeTheLandscape() {
        func kinds(rows: ClosedRange<Int>) -> Set<ObstacleKind> {
            var result = Set<ObstacleKind>()
            for y in rows {
                for x in -3...3 {
                    generator.obstacles(in: ChunkCoord(x: x, y: y)).forEach { result.insert($0.kind) }
                }
            }
            return result
        }
        let high = kinds(rows: 1...14) // < 800 m
        let low = kinds(rows: 50...70) // > 2000 m

        #expect(high.contains(.penitente))
        #expect(!high.contains(.araucaria))
        #expect(low.contains(.araucaria))
        #expect(!low.contains(.penitente))
    }

    @Test func liftRunsDiagonallyAcrossTheSlope() {
        // Las torres siguen la línea del telesilla y cruzan la pista de lado a lado.
        let pylons = (0...12).flatMap { y in
            (-3...3).flatMap { generator.obstacles(in: ChunkCoord(x: $0, y: y)) }
        }.filter { $0.kind == .liftPylon }
        #expect(pylons.count > 10)
        for pylon in pylons {
            #expect(abs(Double(pylon.origin.x) - generator.liftX(atY: Double(pylon.origin.y))) < 0.001)
        }
        let xs = pylons.map { Double($0.origin.x) }
        #expect(xs.contains { $0 > 300 } && xs.contains { $0 < -300 })
        // Un poco en diagonal: avanza menos de medio punto en horizontal por cada punto que baja.
        let a = generator.liftX(atY: -1000)
        let b = generator.liftX(atY: -2000)
        #expect(abs(a - b) > 200)
        #expect(abs(a - b) < 500)
        // Cruza el centro de la pista en cada tramo.
        #expect(abs(generator.liftX(atY: -MountainGenerator.liftLegLength / 2)) < 0.001)
    }

    @Test func liftCableIsContinuousAcrossChunks() {
        var pieces = 0
        for y in 0...10 {
            for x in -3...3 {
                for segment in generator.liftSegments(in: MountainGenerator.rect(for: ChunkCoord(x: x, y: y))) {
                    pieces += 1
                    for end in [segment.top, segment.bottom] {
                        #expect(abs(Double(end.x) - generator.liftX(atY: Double(end.y))) < 0.01)
                    }
                }
            }
        }
        #expect(pieces > 11)
    }

    @Test func chunkCoordinatesRoundTrip() {
        let point = CGPoint(x: -10, y: -800)
        let coord = MountainGenerator.coord(containing: point)
        #expect(coord == ChunkCoord(x: -1, y: 1))
        #expect(MountainGenerator.rect(for: coord).contains(point))

        let coords = MountainGenerator.coords(intersecting: CGRect(x: -100, y: -900, width: 200, height: 1000))
        #expect(Set(coords) == [ChunkCoord(x: -1, y: 0), ChunkCoord(x: 0, y: 0), ChunkCoord(x: -1, y: 1), ChunkCoord(x: 0, y: 1)])
    }

    @Test func bandsByDistance() {
        #expect(AltitudeBand(meters: 0) == .high)
        #expect(AltitudeBand(meters: 1000) == .middle)
        #expect(AltitudeBand(meters: 5000) == .low)
    }
}

struct ObstacleMotionTests {
    @Test func wanderingAnimalsStayInRange() {
        let llama = Obstacle(kind: .llama, origin: CGPoint(x: 100, y: -500), motion: .wander(range: 80, speed: 30, phase: 1))
        for step in 0..<200 {
            let p = llama.position(at: Double(step) * 0.25)
            #expect(abs(p.x - 100) <= 80 + 1e-9)
            #expect(p.y == -500)
        }
    }

    @Test func otherSkiersGoDownhill() {
        let skier = Obstacle(kind: .dog, origin: .zero, motion: .downhill(speed: 200, sway: 50, period: 3, phase: 0))
        #expect(skier.position(at: 2).y == -400)
        #expect(abs(skier.position(at: 0.75).x - 50) < 1e-9)
    }

    @Test func spritesFaceTheWayTheyMove() {
        let condor = Obstacle(kind: .condor, origin: .zero, motion: .fly(dx: -100, dy: 0))
        #expect(condor.facesLeft(at: 1))
        #expect(!Obstacle(kind: .rock, origin: .zero).facesLeft(at: 1))
    }

    @Test func hitboxSitsOnTheBase() {
        let tree = Obstacle(kind: .araucaria, origin: CGPoint(x: 50, y: -200))
        let box = tree.hitbox(at: 0)
        #expect(box.minY == -200)
        #expect(box.midX == 50)
        #expect(box.height == ObstacleKind.araucaria.hitboxSize.height)
    }

    @Test func zonesAreEllipses() {
        let ice = Obstacle(kind: .iceZone, origin: .zero, zoneSize: CGSize(width: 200, height: 100))
        #expect(ice.zoneContains(CGPoint(x: 0, y: 0), at: 0))
        #expect(ice.zoneContains(CGPoint(x: 99, y: 0), at: 0))
        #expect(!ice.zoneContains(CGPoint(x: 90, y: 45), at: 0)) // esquina del rectángulo
    }
}
