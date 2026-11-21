import CoreGraphics
import Foundation

/// Esquiadores rivales que bajan por el cerro y se cruzan con el Cuico.
enum RivalKind: String, CaseIterable, Sendable {
    case argentine
    case brazilian

    var obstacleKind: ObstacleKind {
        switch self {
        case .argentine: .argentine
        case .brazilian: .brazilian
        }
    }

    /// Lo que dicen al pasar cerca del Cuico.
    var lines: [String] {
        switch self {
        case .argentine:
            ["¡Che, correte que voy!", "En Bariloche la nieve es mejor, ¿viste?",
             "¿Alguien tiene un mate?", "¡Qué lindo día para un asado!",
             "Esto Messi lo baja con los ojos cerrados.", "¡Dale, dale, dale!"]
        case .brazilian:
            ["Opa! Tudo bem?", "Nossa, que frio!", "Cadê a praia?",
             "Bora, bora!", "Isso é neve? Que legal!", "Ai, saudade do calor…"]
        }
    }

    /// Lo que dicen si el Cuico se los lleva por delante.
    var crashLines: [String] {
        switch self {
        case .argentine: ["¡Uy, perdón, che!", "¡Mirá por dónde vas, loco!"]
        case .brazilian: ["Opa, desculpa!", "Calma, amigo!"]
        }
    }
}

/// Un rival en pista.
struct RivalSkier: Equatable, Sendable {
    let id: Int
    let kind: RivalKind
    /// Centro de las eses al aparecer.
    let baseX: Double
    let speed: Double
    let sway: Double
    let swayPeriod: Double
    let phase: Double
    let spawnTime: Double
    var position: CGPoint
    /// Última vez que habló (para no repetirse sin parar).
    var lastSpoke: Double = -.infinity

    /// Hacia dónde va (para voltear el sprite).
    func facesLeft(at time: Double) -> Bool {
        cos(phase + 2 * .pi * (time - spawnTime) / swayPeriod) < 0
    }

    /// Caja de choque (como cualquier obstáculo).
    var obstacle: Obstacle { Obstacle(kind: kind.obstacleKind, origin: position) }
}

/// Algo que pasa con los rivales.
enum RivalEvent: Equatable, Sendable {
    case appeared(id: Int)
    case left(id: Int)
    case says(id: Int, line: String)
}

/// Gestiona los rivales: aparecen fuera de la pantalla, bajan haciendo eses,
/// comentan al pasar cerca del Cuico y se van cuando quedan lejos. No dependen
/// de los trozos de montaña, así que no aparecen ni desaparecen a la vista.
struct RivalSkiers: Sendable {
    struct Config: Sendable {
        var maxActive = 2
        /// Segundos entre apariciones (al azar en este rango).
        var spawnInterval: ClosedRange<Double> = 4...9
        var speed: ClosedRange<Double> = 160...260
        /// Distancia vertical a la cámara a la que se retiran.
        var despawnDistance: Double = 1100
        /// Distancia a la que hablan al Cuico.
        var talkDistance: Double = 260
        /// Segundos mínimos entre dos frases del mismo rival.
        var talkCooldown: Double = 6
    }

    let config: Config
    private(set) var skiers: [RivalSkier] = []
    private var rng: SeededRandom
    private var nextSpawn: Double
    private var nextID = 0

    init(config: Config = Config(), seed: UInt64) {
        self.config = config
        rng = SeededRandom(seed: seed ^ 0xA5A5_0B0E_17A1_B4A5)
        nextSpawn = 2
    }

    /// Avanza un paso.
    ///
    /// - Parameters:
    ///   - camera: centro de la cámara (los rivales entran y salen fuera de la vista).
    ///   - viewSize: tamaño visible de la escena.
    mutating func update(dt: Double, time: Double, skier: SkierState, camera: CGPoint, viewSize: CGSize) -> [RivalEvent] {
        var events: [RivalEvent] = []

        // Mover.
        for index in skiers.indices {
            var rival = skiers[index]
            let t = time - rival.spawnTime
            rival.position.y -= rival.speed * dt
            rival.position.x = rival.baseX + rival.sway * sin(rival.phase + 2 * .pi * t / rival.swayPeriod)
            skiers[index] = rival
        }

        // Retirar los que quedan lejos.
        let gone = skiers.filter { abs(Double($0.position.y - camera.y)) > config.despawnDistance }
        skiers.removeAll { abs(Double($0.position.y - camera.y)) > config.despawnDistance }
        events += gone.map { .left(id: $0.id) }

        // Aparecer fuera de la pantalla.
        if time >= nextSpawn {
            nextSpawn = time + Double.random(in: config.spawnInterval, using: &rng)
            if skiers.count < config.maxActive {
                let rival = spawn(time: time, skier: skier, camera: camera, viewSize: viewSize)
                skiers.append(rival)
                events.append(.appeared(id: rival.id))
            }
        }

        // Hablar al pasar cerca del Cuico.
        for index in skiers.indices {
            let rival = skiers[index]
            let distance = hypot(Double(rival.position.x - skier.position.x), Double(rival.position.y - skier.position.y))
            guard distance < config.talkDistance, time - rival.lastSpoke >= config.talkCooldown else { continue }
            let lines = rival.kind.lines
            let line = lines[Int.random(in: 0..<lines.count, using: &rng)]
            skiers[index].lastSpoke = time
            events.append(.says(id: rival.id, line: line))
        }
        return events
    }

    /// Frase de un rival al que el Cuico acaba de atropellar.
    mutating func crashLine(for id: Int, time: Double) -> String? {
        guard let index = skiers.firstIndex(where: { $0.id == id }) else { return nil }
        skiers[index].lastSpoke = time
        let lines = skiers[index].kind.crashLines
        return lines[Int.random(in: 0..<lines.count, using: &rng)]
    }

    private mutating func spawn(time: Double, skier: SkierState, camera: CGPoint, viewSize: CGSize) -> RivalSkier {
        let kind = RivalKind.allCases[Int.random(in: 0..<RivalKind.allCases.count, using: &rng)]
        let speed = Double.random(in: config.speed, using: &rng)
        // Si el Cuico va rápido, el rival aparece por delante (abajo) y lo adelanta;
        // si va lento, aparece por detrás (arriba) y lo pasa.
        let ahead = skier.speed > speed
        let margin = 80.0
        let y = Double(camera.y) + (ahead ? -1 : 1) * (Double(viewSize.height) / 2 + margin)
        let x = Double(camera.x) + Double.random(in: -0.4...0.4, using: &rng) * Double(viewSize.width)
        let rival = RivalSkier(
            id: nextID,
            kind: kind,
            baseX: x,
            speed: speed,
            sway: Double.random(in: 30...90, using: &rng),
            swayPeriod: Double.random(in: 2...4, using: &rng),
            phase: Double.random(in: 0..<(2 * .pi), using: &rng),
            spawnTime: time,
            position: CGPoint(x: x, y: y)
        )
        nextID += 1
        return rival
    }
}
