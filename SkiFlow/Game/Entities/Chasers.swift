import CoreGraphics
import Foundation

/// Criaturas que persiguen al Cuico.
enum ChaserKind: String, Sendable {
    case kunk
    case chupacabras
    case avalanche

    var displayName: String {
        switch self {
        case .kunk: "el Kunk"
        case .chupacabras: "el Chupacabras"
        case .avalanche: "la avalancha"
        }
    }
}

/// Fase en la que está un perseguidor.
enum ChaserPhase: Equatable, Sendable {
    /// Aún no ha aparecido.
    case waiting
    /// Acecha fuera de la pantalla y da un aviso (solo el Chupacabras).
    case warning
    /// Persigue (o embiste) al Cuico.
    case chasing
    /// Se aleja tras fallar el ataque.
    case retreating
    /// Ha atrapado al Cuico.
    case caught
    /// Se fue y no volverá en esta bajada.
    case gone

    /// Si debe verse en pantalla.
    var isVisible: Bool {
        switch self {
        case .chasing, .retreating, .caught: true
        default: false
        }
    }
}

/// Algo que les pasa a los perseguidores y la escena debe contar al jugador.
enum ChaserEvent: Equatable, Sendable {
    case warning
    case appeared
    case caught
    case escaped
}

/// Comportamiento común de los perseguidores.
protocol Chaser: Sendable {
    var kind: ChaserKind { get }
    var phase: ChaserPhase { get }
    var position: CGPoint { get }
    /// Para voltear el sprite.
    var facesLeft: Bool { get }

    /// Avanza un paso de simulación y devuelve el evento que haya ocurrido.
    mutating func update(dt: Double, skier: SkierState) -> ChaserEvent?
}

// MARK: - Kunk

/// El Kunk: aparece siempre a partir de cierta distancia y persigue al Cuico.
/// Corre más que el Cuico normal pero menos que con turbo, así que se puede
/// escapar… a costa de ir peligrosamente rápido. Atraviesa los obstáculos. Si el
/// Cuico le saca mucha ventaja durante unos segundos, se cansa y vuelve más abajo.
struct KunkChaser: Chaser {
    struct Config: Sendable {
        /// Metros de descenso a partir de los que aparece.
        var spawnMeters: Double = 2000
        /// Aparece por encima del Cuico, fuera de la pantalla.
        var spawnHeight: Double = 520
        var spawnSideOffset: Double = 220
        var startSpeed: Double = 430
        /// Cuánto acelera por segundo de persecución.
        var acceleration: Double = 12
        /// Entre la velocidad normal del Cuico (~520) y la del turbo (~780),
        /// con margen suficiente para escapar con turbo (ajustado en la Fase 11).
        var maxSpeed: Double = 620
        var catchRadius: Double = 20
        /// Si se queda más atrás que esto, recorta distancia para no perder la tensión.
        /// Es amplio (≈125 m) para que sacar ventaja con turbo sirva de algo.
        var maxLag: Double = 2000
        /// Ventaja (≈100 m) que hay que mantener para que el Kunk se canse…
        var escapeDistance: Double = 1600
        /// …durante estos segundos.
        var escapeTime: Double = 4
        /// Metros más abajo a los que vuelve tras cansarse.
        var respawnGap: Double = 1500
    }

    let kind = ChaserKind.kunk
    let config: Config
    /// -1 = aparece por la izquierda, 1 = por la derecha.
    let side: Double

    private(set) var phase: ChaserPhase = .waiting
    private(set) var position: CGPoint = .zero
    private(set) var speed: Double = 0
    private(set) var facesLeft = false
    /// Metros a los que aparece (la primera vez y tras cansarse).
    private(set) var nextSpawnMeters: Double
    /// Veces que el Cuico lo dejó atrás en esta bajada.
    private(set) var escapes = 0
    private var farTime: Double = 0

    init(config: Config = Config(), side: Double) {
        self.config = config
        self.side = side < 0 ? -1 : 1
        nextSpawnMeters = config.spawnMeters
    }

    /// Segundos que el Cuico lleva con mucha ventaja (para el HUD).
    var escapeProgress: Double { min(1, farTime / config.escapeTime) }

    /// Distancia (puntos) hasta el Cuico.
    func distance(to skier: SkierState) -> Double {
        hypot(skier.position.x - position.x, skier.position.y - position.y)
    }

    mutating func update(dt: Double, skier: SkierState) -> ChaserEvent? {
        switch phase {
        case .waiting:
            guard skier.distanceMeters >= nextSpawnMeters else { return nil }
            farTime = 0
            position = CGPoint(
                x: skier.position.x + side * config.spawnSideOffset,
                y: skier.position.y + config.spawnHeight
            )
            speed = config.startSpeed
            phase = .chasing
            return .appeared

        case .chasing:
            var dx = skier.position.x - position.x
            var dy = skier.position.y - position.y
            var distance = hypot(dx, dy)
            if distance <= config.catchRadius {
                phase = .caught
                position = skier.position
                return .caught
            }

            if distance > config.maxLag {
                // Recorta distancia por detrás del Cuico.
                let keep = config.maxLag * 0.8
                position = CGPoint(x: skier.position.x - dx / distance * keep, y: skier.position.y - dy / distance * keep)
                dx = skier.position.x - position.x
                dy = skier.position.y - position.y
                distance = keep
            }

            // Si el Cuico le saca mucha ventaja un rato, se cansa.
            farTime = distance >= config.escapeDistance ? farTime + dt : 0
            if farTime >= config.escapeTime {
                escapes += 1
                farTime = 0
                phase = .waiting
                nextSpawnMeters = skier.distanceMeters + config.respawnGap
                speed = 0
                return .escaped
            }

            speed = min(config.maxSpeed, speed + config.acceleration * dt)
            let stepLength = min(speed * dt, distance)
            position.x += dx / distance * stepLength
            position.y += dy / distance * stepLength
            if abs(dx) > 1 { facesLeft = dx < 0 }

            if hypot(skier.position.x - position.x, skier.position.y - position.y) <= config.catchRadius {
                phase = .caught
                position = skier.position
                return .caught
            }
            return nil

        case .warning, .retreating, .caught, .gone:
            return nil
        }
    }
}

// MARK: - Chupacabras

/// El Chupacabras: muy poco frecuente. Acecha a un lado, avisa, y embiste en
/// línea recta hacia donde va a estar el Cuico. Si falla (o el Cuico lo salta),
/// se esfuma.
struct ChupacabrasChaser: Chaser {
    struct Config: Sendable {
        /// Probabilidad de que aparezca en una bajada.
        var chance: Double = 0.08
        /// Tramo de la bajada en el que puede aparecer (partidas largas).
        var minMeters: Double = 800
        var maxMeters: Double = 3000
        /// Tiempo de aviso antes del ataque, para poder reaccionar.
        var warningDuration: Double = 1.3
        var sprintSpeed: Double = 950
        var sprintDuration: Double = 1.4
        var retreatDuration: Double = 1.2
        var catchRadius: Double = 22
        /// Distancia lateral desde la que embiste (fuera de la pantalla).
        var sideDistance: Double = 620
        /// Embiste un poco por delante (más abajo) del Cuico.
        var aheadDistance: Double = 140
    }

    let kind = ChaserKind.chupacabras
    let config: Config
    /// Metros a los que aparecerá en esta bajada, o `nil` si no le toca.
    let triggerMeters: Double?
    let side: Double

    private(set) var phase: ChaserPhase = .waiting
    private(set) var position: CGPoint = .zero
    private(set) var facesLeft = false
    private var timer: Double = 0
    private var heading = CGVector(dx: 0, dy: 0)

    /// Decide con la semilla de la bajada si el Chupacabras aparecerá y dónde.
    init(config: Config = Config(), seed: UInt64) {
        self.config = config
        var rng = SeededRandom(seed: seed ^ 0xC4A5_ABCA_B0A5_0001)
        let roll = Double.random(in: 0..<1, using: &rng)
        let meters = Double.random(in: config.minMeters...config.maxMeters, using: &rng)
        side = Bool.random(using: &rng) ? 1 : -1
        triggerMeters = roll < config.chance ? meters : nil
    }

    var willAppear: Bool { triggerMeters != nil }

    mutating func update(dt: Double, skier: SkierState) -> ChaserEvent? {
        switch phase {
        case .waiting:
            guard let trigger = triggerMeters, skier.distanceMeters >= trigger else { return nil }
            phase = .warning
            timer = config.warningDuration
            lurk(beside: skier)
            return .warning

        case .warning:
            lurk(beside: skier)
            timer -= dt
            guard timer <= 0 else { return nil }
            // Apunta a donde estará el Cuico cuando llegue.
            let distance = hypot(skier.position.x - position.x, skier.position.y - position.y)
            let eta = distance / config.sprintSpeed
            let velocity = skier.velocity
            let target = CGPoint(x: skier.position.x + velocity.dx * eta, y: skier.position.y + velocity.dy * eta)
            let dx = target.x - position.x
            let dy = target.y - position.y
            let length = max(hypot(dx, dy), 1)
            heading = CGVector(dx: dx / length, dy: dy / length)
            facesLeft = heading.dx < 0
            phase = .chasing
            timer = config.sprintDuration
            return .appeared

        case .chasing:
            move(dt: dt)
            // Saltar por encima lo esquiva.
            if !skier.isAirborne,
               hypot(skier.position.x - position.x, skier.position.y - position.y) <= config.catchRadius {
                phase = .caught
                position = skier.position
                return .caught
            }
            timer -= dt
            if timer <= 0 {
                phase = .retreating
                timer = config.retreatDuration
                return .escaped
            }
            return nil

        case .retreating:
            move(dt: dt)
            timer -= dt
            if timer <= 0 { phase = .gone }
            return nil

        case .caught, .gone:
            return nil
        }
    }

    private mutating func lurk(beside skier: SkierState) {
        position = CGPoint(
            x: skier.position.x + side * config.sideDistance,
            y: skier.position.y - config.aheadDistance
        )
        facesLeft = side > 0
    }

    private mutating func move(dt: Double) {
        position.x += heading.dx * config.sprintSpeed * dt
        position.y += heading.dy * config.sprintSpeed * dt
    }
}

// MARK: - Avalancha

/// La avalancha: un frente de nieve que baja desde la salida. Si el Cuico va
/// demasiado lento (o se cae demasiado), lo sepulta. Se usa en slalom y freestyle.
struct AvalancheChaser: Chaser {
    struct Config: Sendable {
        /// Segundos de margen antes de que se suelte.
        var delay: Double = 2.5
        /// Altura sobre la salida a la que empieza el frente.
        var startHeight: Double = 500
        var startSpeed: Double = 200
        var acceleration: Double = 4
        /// Por debajo de lo que baja el Cuico trazando las puertas sin caerse.
        var maxSpeed: Double = 320
        /// A esta distancia el frente atrapa al Cuico.
        var reach: Double = 10
    }

    let kind = ChaserKind.avalanche
    let config: Config

    private(set) var phase: ChaserPhase = .waiting
    /// Altura del frente; `x` sigue al Cuico porque la avalancha ocupa todo el ancho.
    private(set) var position: CGPoint
    private(set) var speed: Double = 0
    let facesLeft = false
    private var timer: Double = 0

    init(config: Config = Config()) {
        self.config = config
        position = CGPoint(x: 0, y: config.startHeight)
    }

    /// Distancia vertical (puntos) entre el frente y el Cuico.
    func gap(to skier: SkierState) -> Double {
        Double(position.y - skier.position.y)
    }

    mutating func update(dt: Double, skier: SkierState) -> ChaserEvent? {
        position.x = skier.position.x
        switch phase {
        case .waiting:
            timer += dt
            guard timer >= config.delay else { return nil }
            phase = .chasing
            speed = config.startSpeed
            return .appeared

        case .chasing:
            speed = min(config.maxSpeed, speed + config.acceleration * dt)
            position.y -= speed * dt
            if gap(to: skier) <= config.reach {
                phase = .caught
                return .caught
            }
            return nil

        case .warning, .retreating, .caught, .gone:
            return nil
        }
    }

    /// Para la avalancha (por ejemplo, al cruzar la meta).
    mutating func stop() {
        phase = .gone
    }
}
