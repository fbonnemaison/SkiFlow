import CoreGraphics
import Foundation

/// Estado físico del Cuico. Es un valor puro para poder testearlo sin SpriteKit.
struct SkierState: Equatable, Sendable {
    /// Posición de los pies en el mundo (puntos). La pendiente baja hacia `y` negativo.
    var position: CGPoint = .zero
    var direction: SkiDirection = .down
    /// Rapidez en puntos por segundo (siempre ≥ 0).
    var speed: Double = 0

    /// Segundos de salto que quedan (0 = en el suelo).
    var airTime: Double = 0
    /// Duración total del salto actual.
    var airDuration: Double = 0
    /// Segundos que quedan en el suelo tras una caída.
    var fallTime: Double = 0
    /// Segundos que quedan de tambaleo tras tropezar.
    var stumbleTime: Double = 0
    /// Segundos de inmunidad a choques (tras levantarse o tropezar).
    var graceTime: Double = 0

    var isAirborne: Bool { airTime > 0 }
    var isFallen: Bool { fallTime > 0 }

    /// Altura visual del salto (puntos): sube y baja en forma de arco.
    var airHeight: Double {
        guard isAirborne, airDuration > 0 else { return 0 }
        let progress = 1 - airTime / airDuration
        return sin(.pi * progress) * airDuration * 40
    }

    /// Velocidad actual como vector (puntos por segundo).
    ///
    /// Con los esquís atravesados el Cuico derrapa pendiente abajo mientras frena,
    /// en vez de salir disparado en horizontal.
    var velocity: CGVector {
        let v = direction.isSideways ? (dx: 0.0, dy: -1.0) : direction.unitVector
        return CGVector(dx: v.dx * speed, dy: v.dy * speed)
    }

    /// Caja de choque de los pies y los esquís.
    var hitbox: CGRect {
        CGRect(x: position.x - 6, y: position.y - 12, width: 12, height: 12)
    }

    /// Metros descendidos desde la salida.
    var distanceMeters: Double {
        position.y < 0 ? -Double(position.y) / GameConfig.pointsPerMeter : 0
    }

    /// Rapidez en km/h para mostrar en pantalla.
    var speedKmh: Double {
        speed / GameConfig.pointsPerMeter * 3.6
    }
}
