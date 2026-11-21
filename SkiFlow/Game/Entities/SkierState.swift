import CoreGraphics

/// Estado físico del Cuico. Es un valor puro para poder testearlo sin SpriteKit.
struct SkierState: Equatable, Sendable {
    /// Posición en el mundo (puntos). La pendiente baja hacia `y` negativo.
    var position: CGPoint = .zero
    var direction: SkiDirection = .down
    /// Rapidez en puntos por segundo (siempre ≥ 0).
    var speed: Double = 0

    /// Velocidad actual como vector (puntos por segundo).
    ///
    /// Con los esquís atravesados el Cuico derrapa pendiente abajo mientras frena,
    /// en vez de salir disparado en horizontal.
    var velocity: CGVector {
        let v = direction.isSideways ? (dx: 0.0, dy: -1.0) : direction.unitVector
        return CGVector(dx: v.dx * speed, dy: v.dy * speed)
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
