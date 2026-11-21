/// Acciones de juego, independientes del dispositivo de entrada.
enum InputAction: Hashable, Sendable {
    case left
    case right
    case down
    case brake
    case restart

    /// Traduce un código de tecla físico de macOS (independiente de la distribución
    /// del teclado, así WASD funciona por posición).
    init?(keyCode: UInt16) {
        switch keyCode {
        case 123, 0: self = .left // ← / A
        case 124, 2: self = .right // → / D
        case 125, 1: self = .down // ↓ / S
        case 126, 13: self = .brake // ↑ / W
        case 15: self = .restart // R
        default: return nil
        }
    }
}

/// Convierte las acciones pulsadas en cambios de dirección del Cuico.
///
/// Al pulsar izquierda/derecha se gira un paso al instante; si se mantiene la tecla,
/// se sigue girando tras `repeatDelay` cada `repeatInterval` segundos.
struct SkierController: Sendable {
    var repeatDelay: Double = 0.22
    var repeatInterval: Double = 0.11

    private var leftTimer: Double = 0
    private var rightTimer: Double = 0

    /// Respuesta inmediata a una pulsación.
    mutating func press(_ action: InputAction, direction: inout SkiDirection) {
        switch action {
        case .left:
            direction = direction.turnedLeft()
            leftTimer = repeatDelay
        case .right:
            direction = direction.turnedRight()
            rightTimer = repeatDelay
        case .down:
            direction = .down
        case .brake:
            direction = direction.braking()
        case .restart:
            break
        }
    }

    /// Repetición de giro mientras se mantiene la tecla.
    mutating func update(held: Set<InputAction>, dt: Double, direction: inout SkiDirection) {
        let left = held.contains(.left)
        let right = held.contains(.right)
        guard left != right else { return }

        if left {
            leftTimer -= dt
            while leftTimer <= 0 {
                direction = direction.turnedLeft()
                leftTimer += repeatInterval
            }
        } else {
            rightTimer -= dt
            while rightTimer <= 0 {
                direction = direction.turnedRight()
                rightTimer += repeatInterval
            }
        }
    }
}
