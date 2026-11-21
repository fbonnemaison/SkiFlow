import CoreGraphics

/// Qué le pasa al Cuico al tocar un obstáculo.
enum CollisionEffect: Equatable, Sendable {
    /// Se cae y se queda un rato en el suelo.
    case crash
    /// Tropieza y pierde velocidad, pero sigue en pie.
    case trip
    /// Sale volando de una rampa.
    case jump
}

/// Reglas de choque, separadas de SpriteKit para poder testearlas.
enum CollisionResolver {
    /// Efecto de tocar un tipo de obstáculo, según si el Cuico va por el aire.
    static func effect(of kind: ObstacleKind, airborne: Bool) -> CollisionEffect? {
        if kind.isZone { return nil }
        switch kind {
        case .condor:
            // Los cóndores solo molestan en pleno salto.
            return airborne ? .crash : nil
        case .ramp:
            return airborne ? nil : .jump
        default:
            if airborne {
                return kind.isTall ? .crash : nil
            }
            return kind == .smallRock ? .trip : .crash
        }
    }

    /// Primer obstáculo que toca el Cuico y su efecto.
    static func firstHit(
        skier: SkierState,
        among snapshots: [ObstacleSnapshot]
    ) -> (snapshot: ObstacleSnapshot, effect: CollisionEffect)? {
        let box = skier.hitbox
        for snapshot in snapshots {
            guard let effect = effect(of: snapshot.kind, airborne: skier.isAirborne) else { continue }
            if snapshot.hitbox.intersects(box) {
                return (snapshot, effect)
            }
        }
        return nil
    }

    /// Terreno bajo los pies. La nieve profunda manda sobre el hielo.
    static func environment(at point: CGPoint, among snapshots: [ObstacleSnapshot]) -> Terrain {
        var environment = Terrain()
        for snapshot in snapshots where snapshot.obstacle.zoneContains(point, at: snapshot.time) {
            switch snapshot.kind {
            case .deepSnowZone:
                environment.surface = .deepSnow
            case .iceZone where environment.surface == .snow:
                environment.surface = .ice
            case .windZone:
                environment.wind = snapshot.obstacle.windStrength
            default:
                break
            }
        }
        return environment
    }
}
