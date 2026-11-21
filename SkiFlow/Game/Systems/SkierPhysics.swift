import CoreGraphics
import Foundation

/// Tipo de nieve bajo los esquís.
enum Surface: Equatable, Sendable {
    case snow
    case ice
    case deepSnow

    /// Multiplicador del rozamiento: en hielo se desliza más, en nieve profunda menos.
    var dragMultiplier: Double {
        switch self {
        case .snow: 1
        case .ice: 0.55
        case .deepSnow: 2.6
        }
    }

    /// Multiplicador de la frenada atravesada: en hielo cuesta mucho frenar.
    var brakeMultiplier: Double {
        switch self {
        case .snow: 1
        case .ice: 0.3
        case .deepSnow: 1.3
        }
    }
}

/// Condiciones del terreno en un punto.
struct Terrain: Equatable, Sendable {
    var surface: Surface = .snow
    /// Empuje lateral del viento en puntos/s (positivo = derecha).
    var wind: Double = 0

    var isWhiteout: Bool { wind != 0 }
}

/// Física simplificada del descenso.
///
/// - La aceleración por la pendiente es `gravity · cos(ángulo)`: máxima recto abajo
///   y nula con los esquís atravesados.
/// - El rozamiento es proporcional a la rapidez, así que existe una velocidad
///   terminal `gravity / drag` cuando se va recto.
/// - Con los esquís atravesados se aplica además una frenada fuerte hasta parar.
/// - En el aire se conserva la velocidad y no influye el terreno.
struct SkierPhysics: Sendable {
    var gravity: Double = 600
    var drag: Double = 1.15
    var sidewaysBrake: Double = 900
    var maxSpeed: Double = 540
    /// Rapidez mínima para despegar de una rampa.
    var minJumpSpeed: Double = 60
    /// Alarga los saltos (en freestyle, para que quepan los trucos).
    var airTimeMultiplier: Double = 1
    /// El turbo multiplica la gravedad y sube el tope de velocidad.
    var turboGravityMultiplier: Double = 1.5
    var turboMaxSpeed: Double = 780

    /// Velocidad terminal yendo recto hacia abajo sobre nieve normal.
    var terminalSpeed: Double { min(gravity / drag, maxSpeed) }

    /// Velocidad terminal con turbo.
    var turboTerminalSpeed: Double { min(gravity * turboGravityMultiplier / drag, turboMaxSpeed) }

    func step(
        _ state: inout SkierState,
        dt: Double,
        environment: Terrain = Terrain(),
        turbo: Bool = false
    ) {
        guard dt > 0, !state.isFallen else { return }

        if state.isAirborne {
            move(&state, dt: dt)
            state.airTime = max(0, state.airTime - dt)
            return
        }

        let direction = state.direction
        let surface = environment.surface
        let pull = gravity * (turbo ? turboGravityMultiplier : 1)
        var acceleration = pull * cos(direction.angle) - drag * surface.dragMultiplier * state.speed
        if direction.isSideways {
            acceleration -= sidewaysBrake * surface.brakeMultiplier
        }
        // Al soltar el turbo, el exceso de velocidad se pierde por rozamiento.
        let cap = turbo ? turboMaxSpeed : max(maxSpeed, state.speed)
        state.speed = min(max(state.speed + acceleration * dt, 0), cap)

        move(&state, dt: dt)

        // El viento solo arrastra si el Cuico se está deslizando.
        if state.speed > 0 {
            state.position.x += environment.wind * min(1, state.speed / 100) * dt
        }
    }

    /// Despega de una rampa. Más rápido ⇒ salto más largo.
    /// Devuelve `false` si va demasiado lento para saltar.
    @discardableResult
    func launch(_ state: inout SkierState) -> Bool {
        guard !state.isAirborne, state.speed >= minJumpSpeed else { return false }
        let duration = min(1.3, 0.4 + 0.9 * state.speed / terminalSpeed) * airTimeMultiplier
        state.airDuration = duration
        state.airTime = duration
        return true
    }

    /// Pequeño brinco a voluntad (Espacio, clic o botón A), sin rampa.
    /// Sirve para saltar piedras, animales y otros obstáculos bajos.
    @discardableResult
    func hop(_ state: inout SkierState) -> Bool {
        guard !state.isAirborne, !state.isFallen else { return false }
        let duration = (0.35 + 0.25 * min(1, state.speed / terminalSpeed)) * airTimeMultiplier
        state.airDuration = duration
        state.airTime = duration
        return true
    }

    private func move(_ state: inout SkierState, dt: Double) {
        let velocity = state.velocity
        state.position.x += velocity.dx * dt
        state.position.y += velocity.dy * dt
    }
}
