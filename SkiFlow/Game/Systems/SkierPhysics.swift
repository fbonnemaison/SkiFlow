import CoreGraphics

/// Física simplificada del descenso.
///
/// - La aceleración por la pendiente es `gravity · cos(ángulo)`: máxima recto abajo
///   y nula con los esquís atravesados.
/// - El rozamiento es proporcional a la rapidez, así que existe una velocidad
///   terminal `gravity / drag` cuando se va recto.
/// - Con los esquís atravesados se aplica además una frenada fuerte hasta parar.
struct SkierPhysics: Sendable {
    var gravity: Double = 600
    var drag: Double = 1.15
    var sidewaysBrake: Double = 900
    var maxSpeed: Double = 540

    /// Velocidad terminal yendo recto hacia abajo.
    var terminalSpeed: Double { min(gravity / drag, maxSpeed) }

    func step(_ state: inout SkierState, dt: Double) {
        guard dt > 0 else { return }

        let direction = state.direction
        var acceleration = gravity * cos(direction.angle) - drag * state.speed
        if direction.isSideways {
            acceleration -= sidewaysBrake
        }

        state.speed = min(max(state.speed + acceleration * dt, 0), maxSpeed)

        let velocity = state.velocity
        state.position.x += velocity.dx * dt
        state.position.y += velocity.dy * dt
    }
}
