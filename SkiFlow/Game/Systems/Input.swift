import CoreGraphics
import Foundation

/// Acciones de juego, independientes del dispositivo de entrada.
enum InputAction: String, Hashable, Sendable, CaseIterable, Codable {
    case left
    case right
    case down
    case brake
    case jump
    case turbo
    case pause
    case restart
    /// Atajos para cambiar de modo (teclas 1–4; también ⌘1–⌘4 en el menú Juego).
    case modeFreeDescent
    case modeSlalom
    case modeTreeSlalom
    case modeFreestyle

    /// Traduce un código de tecla físico de macOS con la asignación por defecto
    /// (independiente de la distribución del teclado, así WASD funciona por posición).
    /// Las asignaciones personalizadas están en `KeyBindings`.
    init?(keyCode: UInt16) {
        switch keyCode {
        case 123, 0: self = .left // ← / A
        case 124, 2: self = .right // → / D
        case 125, 1: self = .down // ↓ / S
        case 126, 13: self = .brake // ↑ / W
        case 49: self = .jump // Espacio
        case 3: self = .turbo // F
        case 53, 35: self = .pause // Esc / P
        case 15: self = .restart // R
        case 18: self = .modeFreeDescent // 1
        case 19: self = .modeSlalom // 2
        case 20: self = .modeTreeSlalom // 3
        case 21: self = .modeFreestyle // 4
        default: return nil
        }
    }

    /// Modo al que lleva un atajo de modo, si lo es.
    var gameMode: GameMode? {
        switch self {
        case .modeFreeDescent: .freeDescent
        case .modeSlalom: .slalom
        case .modeTreeSlalom: .treeSlalom
        case .modeFreestyle: .freestyle
        default: nil
        }
    }

    /// Acciones que se pueden reasignar en Ajustes.
    static let rebindable: [InputAction] = [.left, .right, .down, .brake, .jump, .turbo, .pause, .restart]

    /// Nombre en los Ajustes.
    var displayName: String {
        switch self {
        case .left: "Girar a la izquierda"
        case .right: "Girar a la derecha"
        case .down: "Recto hacia abajo"
        case .brake: "Frenar"
        case .jump: "Brincar / selfie"
        case .turbo: "Turbo"
        case .pause: "Pausa"
        case .restart: "Reiniciar"
        case .modeFreeDescent: "Descenso libre"
        case .modeSlalom: "Slalom"
        case .modeTreeSlalom: "Slalom entre árboles"
        case .modeFreestyle: "Freestyle"
        }
    }

    /// Acciones que giran al Cuico de forma digital.
    var isSteering: Bool {
        switch self {
        case .left, .right, .down, .brake: true
        default: false
        }
    }
}

/// De dónde viene una acción.
enum InputSource: Hashable, Sendable {
    case keyboard
    case mouse
    case gamepad
}

/// Estado unificado de la entrada: une teclado, ratón y mando.
///
/// Cada dispositivo mantiene sus propias teclas pulsadas, de modo que soltar una
/// tecla no anula el mismo botón mantenido en el mando.
struct InputState: Sendable {
    private var heldBySource: [InputSource: Set<InputAction>] = [:]

    /// Posición del cursor relativa a la cámara (o `nil` si el ratón no apunta).
    var mouseAim: CGPoint?
    /// Inclinación del stick del mando (`x`, `y` entre -1 y 1; `y` positivo = arriba).
    var stickAim: CGVector = .zero

    /// Acciones mantenidas por cualquier dispositivo.
    var held: Set<InputAction> {
        heldBySource.values.reduce(into: Set()) { $0.formUnion($1) }
    }

    /// Registra una pulsación o suelta. Devuelve `true` solo cuando la acción pasa
    /// de no estar pulsada en ningún dispositivo a estarlo (flanco de subida).
    @discardableResult
    mutating func set(_ action: InputAction, pressed: Bool, source: InputSource) -> Bool {
        let wasHeld = held.contains(action)
        if pressed {
            heldBySource[source, default: []].insert(action)
        } else {
            heldBySource[source]?.remove(action)
        }
        return pressed && !wasHeld
    }

    mutating func releaseAll() {
        heldBySource.removeAll()
        stickAim = .zero
    }

    /// Dirección hacia la que apuntan el stick o el ratón, si alguno lo hace.
    ///
    /// - Parameters:
    ///   - skier: posición del Cuico en el mundo.
    ///   - camera: posición de la cámara en el mundo.
    func aimDirection(skier: CGPoint, camera: CGPoint) -> SkiDirection? {
        let stickLength = hypot(stickAim.dx, stickAim.dy)
        if stickLength >= Self.stickDeadZone {
            return SkiDirection.aiming(at: stickAim)
        }
        if let mouseAim {
            let target = CGPoint(x: camera.x + mouseAim.x, y: camera.y + mouseAim.y)
            let vector = CGVector(dx: target.x - skier.x, dy: target.y - skier.y)
            guard hypot(vector.dx, vector.dy) >= Self.mouseDeadZone else { return nil }
            return SkiDirection.aiming(at: vector)
        }
        return nil
    }

    /// Por debajo de esta inclinación se ignora el stick.
    static let stickDeadZone: Double = 0.35
    /// Si el cursor está encima del Cuico no se cambia la dirección.
    static let mouseDeadZone: Double = 24
}

/// Convierte las acciones pulsadas en cambios de dirección del Cuico.
///
/// Al pulsar izquierda/derecha se gira un paso al instante; si se mantiene la tecla,
/// se sigue girando tras `repeatDelay` cada `repeatInterval` segundos. Con ratón o
/// stick se gira paso a paso hacia la dirección apuntada.
struct SkierController: Sendable {
    var repeatDelay: Double = 0.22
    var repeatInterval: Double = 0.11
    var aimStepInterval: Double = 0.05

    private var leftTimer: Double = 0
    private var rightTimer: Double = 0
    private var aimTimer: Double = 0

    /// Inicializador explícito: con propiedades privadas, Swift 6.2 (Xcode 26)
    /// no genera el inicializador por miembros con argumentos.
    init(repeatDelay: Double = 0.22, repeatInterval: Double = 0.11, aimStepInterval: Double = 0.05) {
        self.repeatDelay = repeatDelay
        self.repeatInterval = repeatInterval
        self.aimStepInterval = aimStepInterval
    }

    /// Respuesta inmediata a una pulsación de giro.
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
        case .jump, .turbo, .pause, .restart, .modeFreeDescent, .modeSlalom, .modeTreeSlalom, .modeFreestyle:
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

    /// Gira paso a paso hacia `target` (ratón o stick).
    mutating func steer(toward target: SkiDirection, dt: Double, direction: inout SkiDirection) {
        guard direction != target else {
            aimTimer = 0
            return
        }
        aimTimer -= dt
        while aimTimer <= 0, direction != target {
            direction = target.rawValue < direction.rawValue ? direction.turnedLeft() : direction.turnedRight()
            aimTimer += aimStepInterval
        }
    }
}
