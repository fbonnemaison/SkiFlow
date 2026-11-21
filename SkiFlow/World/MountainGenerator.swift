import CoreGraphics
import Foundation

/// Coordenada de un trozo de montaña. `y` crece pendiente abajo (0 = salida).
struct ChunkCoord: Hashable, Sendable {
    let x: Int
    let y: Int
}

/// Genera la montaña por trozos cuadrados de forma determinista a partir de una semilla.
struct MountainGenerator: Sendable {
    /// Lado de cada trozo, en puntos (≈ 48 m).
    static let chunkSize: Double = 768
    /// Zona despejada alrededor de la salida.
    static let startClearing = CGRect(x: -320, y: -480, width: 640, height: 1000)
    /// Distancia mínima entre objetos sólidos.
    static let minSpacing: Double = 84
    /// Separación vertical entre torres del telesilla.
    static let pylonSpacing: Double = 640

    let seed: UInt64

    init(seed: UInt64) {
        self.seed = seed
    }

    /// Columna en la que corre el telesilla (a un lado de la salida).
    var liftX: Double {
        let offset = 520 + Double(seed % 480)
        return seed & 1 == 0 ? offset : -offset
    }

    /// Rectángulo de mundo que cubre un trozo.
    static func rect(for coord: ChunkCoord) -> CGRect {
        CGRect(
            x: Double(coord.x) * chunkSize,
            y: -Double(coord.y + 1) * chunkSize,
            width: chunkSize,
            height: chunkSize
        )
    }

    /// Trozo que contiene un punto del mundo.
    static func coord(containing point: CGPoint) -> ChunkCoord {
        ChunkCoord(
            x: Int((Double(point.x) / chunkSize).rounded(.down)),
            y: Int((-Double(point.y) / chunkSize).rounded(.down))
        )
    }

    /// Trozos que intersecan un rectángulo (solo de la salida hacia abajo).
    static func coords(intersecting rect: CGRect) -> [ChunkCoord] {
        let minX = Int((Double(rect.minX) / chunkSize).rounded(.down))
        let maxX = Int((Double(rect.maxX) / chunkSize).rounded(.down))
        let minY = max(0, Int((-Double(rect.maxY) / chunkSize).rounded(.down)))
        let maxY = Int((-Double(rect.minY) / chunkSize).rounded(.down))
        guard maxY >= minY else { return [] }
        var result: [ChunkCoord] = []
        for y in minY...maxY {
            for x in minX...maxX {
                result.append(ChunkCoord(x: x, y: y))
            }
        }
        return result
    }

    /// Número de objetos de un trozo: crece con la distancia recorrida.
    static func baseCount(meters: Double) -> Int {
        8 + Int(min(14, meters / 250))
    }

    /// Objetos de un trozo. Mismo trozo y misma semilla ⇒ mismos objetos.
    func obstacles(in coord: ChunkCoord) -> [Obstacle] {
        guard coord.y >= 0 else { return [] }

        var rng = SeededRandom(seed: chunkSeed(coord))
        let rect = Self.rect(for: coord)
        let meters = -Double(rect.midY) / GameConfig.pointsPerMeter
        let band = AltitudeBand(meters: meters)
        var result: [Obstacle] = []

        addPylons(in: rect, to: &result)

        let count = Self.baseCount(meters: meters) + Int.random(in: -2...2, using: &rng)
        for _ in 0..<max(0, count) {
            let kind = band.randomKind(using: &rng)
            for _ in 0..<8 {
                let point = CGPoint(
                    x: Double.random(in: rect.minX + 20...rect.maxX - 20, using: &rng),
                    y: Double.random(in: rect.minY + 20...rect.maxY - 20, using: &rng)
                )
                if let obstacle = makeObstacle(kind, at: point, existing: result, using: &rng) {
                    result.append(obstacle)
                    break
                }
            }
        }

        if Double.random(in: 0..<1, using: &rng) < band.condorChance {
            let point = CGPoint(
                x: Double.random(in: rect.minX...rect.maxX, using: &rng),
                y: Double.random(in: rect.minY...rect.maxY, using: &rng)
            )
            if !Self.startClearing.contains(point) {
                let direction: Double = Bool.random(using: &rng) ? 1 : -1
                result.append(Obstacle(
                    kind: .condor,
                    origin: point,
                    motion: .fly(
                        dx: direction * Double.random(in: 70...130, using: &rng),
                        dy: Double.random(in: -25...25, using: &rng)
                    )
                ))
            }
        }

        return result
    }

    // MARK: Privado

    private func chunkSeed(_ coord: ChunkCoord) -> UInt64 {
        var h = seed ^ 0x51ED_270B_2742_7E4F
        h = (h ^ UInt64(bitPattern: Int64(coord.x))) &* 0x9E37_79B9_7F4A_7C15
        h = (h ^ UInt64(bitPattern: Int64(coord.y))) &* 0xC2B2_AE3D_27D4_EB4F
        return h ^ (h >> 29)
    }

    private func addPylons(in rect: CGRect, to result: inout [Obstacle]) {
        let x = liftX
        guard Double(rect.minX) <= x, x < Double(rect.maxX) else { return }
        var y = (Double(rect.maxY) / Self.pylonSpacing).rounded(.down) * Self.pylonSpacing
        while y > Double(rect.minY) {
            let point = CGPoint(x: x, y: y)
            if !Self.startClearing.contains(point) {
                result.append(Obstacle(kind: .liftPylon, origin: point))
            }
            y -= Self.pylonSpacing
        }
    }

    private func makeObstacle(
        _ kind: ObstacleKind,
        at point: CGPoint,
        existing: [Obstacle],
        using rng: inout SeededRandom
    ) -> Obstacle? {
        if kind.isZone {
            let size: CGSize
            var wind = 0.0
            switch kind {
            case .iceZone:
                size = CGSize(
                    width: Double.random(in: 160...300, using: &rng),
                    height: Double.random(in: 80...160, using: &rng)
                )
            case .deepSnowZone:
                size = CGSize(
                    width: Double.random(in: 180...320, using: &rng),
                    height: Double.random(in: 90...180, using: &rng)
                )
            default:
                size = CGSize(
                    width: Double.random(in: 360...560, using: &rng),
                    height: Double.random(in: 260...420, using: &rng)
                )
                wind = (Bool.random(using: &rng) ? 1 : -1) * Double.random(in: 60...120, using: &rng)
            }
            let zoneRect = CGRect(
                x: point.x - size.width / 2, y: point.y - size.height / 2,
                width: size.width, height: size.height
            )
            guard !Self.startClearing.intersects(zoneRect) else { return nil }
            return Obstacle(kind: kind, origin: point, zoneSize: size, windStrength: wind)
        }

        guard !Self.startClearing.contains(point) else { return nil }
        let crowded = existing.contains { other in
            !other.kind.isZone
                && hypot(other.origin.x - point.x, other.origin.y - point.y) < Self.minSpacing
        }
        guard !crowded else { return nil }

        let motion: Motion
        switch kind {
        case .llama, .guanaco, .vicuna:
            motion = .wander(
                range: Double.random(in: 50...140, using: &rng),
                speed: Double.random(in: 20...45, using: &rng),
                phase: Double.random(in: 0..<(2 * .pi), using: &rng)
            )
        case .dog:
            motion = .wander(
                range: Double.random(in: 120...240, using: &rng),
                speed: Double.random(in: 90...150, using: &rng),
                phase: Double.random(in: 0..<(2 * .pi), using: &rng)
            )
        case .skier:
            motion = .downhill(
                speed: Double.random(in: 140...230, using: &rng),
                sway: Double.random(in: 30...80, using: &rng),
                period: Double.random(in: 2...4, using: &rng),
                phase: Double.random(in: 0..<(2 * .pi), using: &rng)
            )
        default:
            motion = .stationary
        }
        return Obstacle(kind: kind, origin: point, motion: motion)
    }
}
