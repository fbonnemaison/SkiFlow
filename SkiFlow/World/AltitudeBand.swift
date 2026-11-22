/// Bandas de altitud de la montaña. Se empieza arriba (hielo y roca) y se baja
/// hacia la vegetación.
enum AltitudeBand: CaseIterable, Sendable {
    /// Alta montaña: rocas, penitentes, apachetas, hielo y vicuñas.
    case high
    /// Puna y laderas: cactus, queñuas, llamas y guanacos.
    case middle
    /// Bosque andino: araucarias, queñuas, refugios y más gente.
    case low

    /// Metros de descenso en los que empieza cada banda.
    static let middleStart: Double = 800
    static let lowStart: Double = 2000

    init(meters: Double) {
        if meters < Self.middleStart {
            self = .high
        } else if meters < Self.lowStart {
            self = .middle
        } else {
            self = .low
        }
    }

    /// Pesos relativos de cada tipo de objeto en la banda.
    var weights: [(kind: ObstacleKind, weight: Double)] {
        switch self {
        case .high:
            [
                (.rock, 3), (.smallRock, 3), (.penitente, 3), (.apacheta, 1.5),
                (.vicuna, 0.1), (.iceZone, 0.24), (.windZone, 0.6), (.ramp, 1),
                (.refugio, 0.15), (.fox, 0.8), (.puma, 0.15),
            ]
        case .middle:
            [
                (.rock, 2), (.smallRock, 2), (.apacheta, 1.5), (.cactus, 0.2),
                (.guanaco, 0.1), (.llama, 0.1), (.quenua, 1.5), (.deepSnowZone, 1),
                (.iceZone, 0.1), (.windZone, 0.4), (.ramp, 1), (.refugio, 0.2),
                (.fox, 1.2), (.puma, 0.3), (.dog, 0.4), (.snowman, 0.4),
            ]
        case .low:
            [
                (.araucaria, 3), (.quenua, 2.5), (.rock, 1), (.smallRock, 1.5),
                (.llama, 0.15), (.dog, 1), (.fox, 1), (.puma, 0.3), (.deepSnowZone, 1),
                (.ramp, 1.2), (.refugio, 0.25), (.cactus, 0.05), (.snowman, 0.6),
            ]
        }
    }

    /// Probabilidad de que un trozo tenga un cóndor sobrevolándolo.
    var condorChance: Double {
        switch self {
        case .high: 0.2
        case .middle: 0.2
        case .low: 0.08
        }
    }

    /// Elige un tipo según los pesos de la banda.
    func randomKind(using rng: inout some RandomNumberGenerator) -> ObstacleKind {
        Self.pick(from: weights, using: &rng)
    }

    /// Elige un tipo de una tabla de pesos.
    static func pick(
        from entries: [(kind: ObstacleKind, weight: Double)],
        using rng: inout some RandomNumberGenerator
    ) -> ObstacleKind {
        let total = entries.reduce(0) { $0 + $1.weight }
        var roll = Double.random(in: 0..<total, using: &rng)
        for entry in entries {
            if roll < entry.weight { return entry.kind }
            roll -= entry.weight
        }
        return entries[entries.count - 1].kind
    }
}
