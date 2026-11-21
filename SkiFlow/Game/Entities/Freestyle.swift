import Foundation

/// Trucos que el Cuico puede hacer en el aire (modo Freestyle).
enum Trick: Equatable, Sendable {
    case spinLeft
    case spinRight
    case frontFlip
    case backFlip
    /// Pose para la foto en pleno vuelo: el truco más cuico de todos.
    case selfie

    var displayName: String {
        switch self {
        case .spinLeft, .spinRight: "Giro 360"
        case .frontFlip: "Mortal adelante"
        case .backFlip: "Mortal atrás"
        case .selfie: "Selfie"
        }
    }

    var points: Int {
        switch self {
        case .spinLeft, .spinRight: 100
        case .frontFlip, .backFlip: 150
        case .selfie: 50
        }
    }

    /// Segundos que tarda en completarse.
    var duration: Double {
        switch self {
        case .spinLeft, .spinRight: 0.5
        case .frontFlip, .backFlip: 0.6
        case .selfie: 0.35
        }
    }

    /// Truco que se hace con cada acción mientras se está en el aire.
    init?(action: InputAction) {
        switch action {
        case .left: self = .spinLeft
        case .right: self = .spinRight
        case .down: self = .frontFlip
        case .brake: self = .backFlip
        case .jump: self = .selfie
        default: return nil
        }
    }
}

/// Cómo terminó un salto con trucos.
enum Landing: Equatable, Sendable {
    /// Aterrizaje limpio: puntos completos y sube la racha.
    case clean(points: Int)
    /// Aterrizaje justo o atravesado: medio premio y se corta la racha.
    case forced(points: Int)
    /// Aterrizar a mitad de un truco (o chocar en el aire): se pierden los puntos del salto.
    case crash(lostPoints: Int)
}

/// Puntuación de una sesión de freestyle.
struct FreestyleScore: Equatable, Sendable {
    /// Si el último truco termina a menos de esto del suelo, el aterrizaje es forzado.
    static let forcedWindow: Double = 0.12
    static let chainStep: Double = 0.5
    static let maxChain: Double = 4

    private(set) var total = 0
    /// Multiplicador de racha: sube con cada aterrizaje limpio con trucos.
    private(set) var chain: Double = 1
    private(set) var bestJump = 0
    private(set) var tricksLanded = 0

    /// Truco en curso y segundos que lleva.
    private(set) var current: Trick?
    private(set) var currentElapsed: Double = 0
    /// Trucos completados en el salto actual.
    private(set) var jumpTricks: [Trick] = []
    /// Segundos desde que terminó el último truco.
    private(set) var sinceLastTrick: Double = .infinity

    /// Progreso del truco en curso (0…1), para animarlo.
    var currentProgress: Double {
        guard let current else { return 0 }
        return min(1, currentElapsed / current.duration)
    }

    /// Puntos que vale ahora el salto en curso (sin la racha).
    var pendingPoints: Int {
        let base = jumpTricks.reduce(0) { $0 + $1.points }
        return Int((Double(base) * Self.comboMultiplier(trickCount: jumpTricks.count)).rounded())
    }

    /// Varios trucos en un mismo salto valen más: ×1, ×1,5, ×2…
    static func comboMultiplier(trickCount: Int) -> Double {
        1 + 0.5 * Double(max(0, trickCount - 1))
    }

    /// Empieza un truco si no hay otro en marcha.
    @discardableResult
    mutating func start(_ trick: Trick) -> Bool {
        guard current == nil else { return false }
        current = trick
        currentElapsed = 0
        return true
    }

    /// Avanza el truco en curso. Devuelve el truco si se acaba de completar.
    mutating func update(dt: Double) -> Trick? {
        sinceLastTrick += dt
        guard let trick = current else { return nil }
        currentElapsed += dt
        guard currentElapsed >= trick.duration else { return nil }
        current = nil
        currentElapsed = 0
        jumpTricks.append(trick)
        sinceLastTrick = 0
        return trick
    }

    /// Cierra el salto al tocar el suelo. Devuelve `nil` si no hubo trucos.
    mutating func land(sideways: Bool) -> Landing? {
        defer {
            current = nil
            currentElapsed = 0
            jumpTricks = []
            sinceLastTrick = .infinity
        }
        if current != nil {
            return crash()
        }
        guard !jumpTricks.isEmpty else { return nil }

        let points = pendingPoints
        if sideways || sinceLastTrick < Self.forcedWindow {
            let awarded = points / 2
            total += awarded
            tricksLanded += jumpTricks.count
            bestJump = max(bestJump, awarded)
            chain = 1
            return .forced(points: awarded)
        }

        let awarded = Int((Double(points) * chain).rounded())
        total += awarded
        tricksLanded += jumpTricks.count
        bestJump = max(bestJump, awarded)
        chain = min(Self.maxChain, chain + Self.chainStep)
        return .clean(points: awarded)
    }

    /// Choque en el aire o aterrizaje a mitad de truco.
    mutating func crash() -> Landing {
        let lost = pendingPoints
        current = nil
        currentElapsed = 0
        jumpTricks = []
        sinceLastTrick = .infinity
        chain = 1
        return .crash(lostPoints: lost)
    }
}

/// Resultado de una sesión de freestyle.
struct FreestyleResult: Equatable, Sendable {
    let points: Int
    let bestJump: Int
    let tricks: Int
    let seconds: Double

    var title: String { "¡Fin de la sesión!" }

    var summary: String {
        "\(points) puntos · mejor salto: \(bestJump) · trucos: \(tricks) · \(SlalomResult.formatTime(seconds))"
    }
}
