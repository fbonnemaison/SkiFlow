import CoreGraphics
import Foundation

/// Cómo se mueve un obstáculo con el tiempo. Todas las trayectorias son funciones
/// puras del tiempo, así que son deterministas y fáciles de testear.
enum Motion: Equatable, Sendable {
    case stationary
    /// Va y viene en horizontal alrededor del origen (llamas, perros…).
    case wander(range: Double, speed: Double, phase: Double)
    /// Baja la pendiente haciendo eses (otros esquiadores).
    case downhill(speed: Double, sway: Double, period: Double, phase: Double)
    /// Vuela en línea recta (cóndores).
    case fly(dx: Double, dy: Double)
}

/// Un objeto de la montaña tal como lo genera el mundo.
struct Obstacle: Equatable, Sendable {
    let kind: ObstacleKind
    /// Base del objeto (o centro, si es una zona) al cargarse.
    let origin: CGPoint
    /// Tamaño de la elipse, solo para zonas.
    var zoneSize: CGSize = .zero
    var motion: Motion = .stationary
    /// Empuje lateral en puntos/s (solo zonas de viento; positivo = derecha).
    var windStrength: Double = 0

    /// Posición tras `t` segundos desde que se cargó.
    func position(at t: Double) -> CGPoint {
        switch motion {
        case .stationary:
            return origin
        case let .wander(range, speed, phase):
            let x = origin.x + range * sin(phase + t * speed / range)
            return CGPoint(x: x, y: origin.y)
        case let .downhill(speed, sway, period, phase):
            let x = origin.x + sway * sin(phase + 2 * .pi * t / period)
            return CGPoint(x: x, y: origin.y - speed * t)
        case let .fly(dx, dy):
            return CGPoint(x: origin.x + dx * t, y: origin.y + dy * t)
        }
    }

    /// `true` si en el instante `t` se desplaza hacia la izquierda (para voltear el sprite).
    func facesLeft(at t: Double) -> Bool {
        switch motion {
        case .stationary:
            return false
        case let .wander(range, speed, phase):
            return cos(phase + t * speed / range) < 0
        case let .downhill(_, _, period, phase):
            return cos(phase + 2 * .pi * t / period) < 0
        case let .fly(dx, _):
            return dx < 0
        }
    }

    /// Caja de choque (o rectángulo que contiene la zona) en el instante `t`.
    func hitbox(at t: Double) -> CGRect {
        let p = position(at: t)
        if kind.isZone {
            return CGRect(
                x: p.x - zoneSize.width / 2,
                y: p.y - zoneSize.height / 2,
                width: zoneSize.width,
                height: zoneSize.height
            )
        }
        let size = kind.hitboxSize
        return CGRect(x: p.x - size.width / 2, y: p.y, width: size.width, height: size.height)
    }

    /// Para zonas: si el punto cae dentro de la elipse.
    func zoneContains(_ point: CGPoint, at t: Double) -> Bool {
        guard kind.isZone, zoneSize.width > 0, zoneSize.height > 0 else { return false }
        let c = position(at: t)
        let nx = (point.x - c.x) / (zoneSize.width / 2)
        let ny = (point.y - c.y) / (zoneSize.height / 2)
        return nx * nx + ny * ny <= 1
    }
}

/// Un obstáculo resuelto en un instante concreto, listo para colisiones.
struct ObstacleSnapshot: Sendable {
    let obstacle: Obstacle
    let time: Double

    var kind: ObstacleKind { obstacle.kind }
    var position: CGPoint { obstacle.position(at: time) }
    var hitbox: CGRect { obstacle.hitbox(at: time) }
}
