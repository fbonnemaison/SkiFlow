import CoreGraphics
import Foundation

/// Una puerta de slalom: dos banderas entre las que hay que pasar.
struct SlalomGate: Equatable, Sendable {
    let index: Int
    let centerX: Double
    let y: Double
    let width: Double

    var leftX: Double { centerX - width / 2 }
    var rightX: Double { centerX + width / 2 }
    /// Las puertas alternan rojo y azul, como en las pistas de verdad.
    var isRed: Bool { index.isMultiple(of: 2) }

    func contains(x: Double) -> Bool {
        x >= leftX && x <= rightX
    }
}

/// Trazado de slalom generado con la semilla de la bajada (reproducible).
struct SlalomCourse: Equatable, Sendable {
    struct Config: Sendable {
        var gateCount = 20
        var gateWidth: Double = 150
        /// Distancia vertical entre puertas.
        var spacing: Double = 420
        /// Desplazamiento lateral máximo entre una puerta y la siguiente.
        var maxShift: Double = 220
        /// Hasta dónde se puede alejar el trazado del centro.
        var maxOffset: Double = 480
        /// Primera puerta por debajo de la salida.
        var firstGateY: Double = -520
        /// Meta por debajo de la última puerta.
        var finishGap: Double = 420

        static let slalom = Config()
        static let treeSlalom = Config(gateWidth: 130, maxShift: 200, maxOffset: 420)
    }

    let gates: [SlalomGate]
    let finishY: Double

    init(seed: UInt64, config: Config = .slalom) {
        var rng = SeededRandom(seed: seed ^ 0x5A1A_0000_6A7E_5EED)
        var x = 0.0
        var gates: [SlalomGate] = []
        for index in 0..<config.gateCount {
            // Zigzag: cada puerta cambia de lado respecto a la anterior.
            let direction: Double = index.isMultiple(of: 2) ? 1 : -1
            let shift = Double.random(in: config.maxShift * 0.4...config.maxShift, using: &rng)
            x = min(max(x + direction * shift, -config.maxOffset), config.maxOffset)
            gates.append(SlalomGate(
                index: index,
                centerX: x,
                y: config.firstGateY - Double(index) * config.spacing,
                width: config.gateWidth
            ))
        }
        self.gates = gates
        finishY = (gates.last?.y ?? config.firstGateY) - config.finishGap
    }

    /// Zonas que el generador debe dejar libres alrededor de cada puerta y la meta.
    var clearings: [CGRect] {
        let gateClearings = gates.map { gate in
            CGRect(x: gate.leftX - 40, y: gate.y - 80, width: gate.width + 80, height: 160)
        }
        let finish = CGRect(x: -900, y: finishY - 120, width: 1800, height: 240)
        return gateClearings + [finish]
    }
}

/// Qué pasa al cruzar la línea de una puerta o la meta.
enum SlalomEvent: Equatable, Sendable {
    case passed(gate: Int)
    case missed(gate: Int)
    case finished
}

/// Seguimiento de una bajada de slalom: qué puertas se pasaron y cuándo se llega a la meta.
struct SlalomProgress: Equatable, Sendable {
    /// Segundos de penalización por puerta fallada.
    static let missPenalty: Double = 5

    let course: SlalomCourse
    private(set) var nextGate = 0
    private(set) var passed: [Int] = []
    private(set) var missed: [Int] = []
    private(set) var isFinished = false

    init(course: SlalomCourse) {
        self.course = course
    }

    var penaltySeconds: Double { Double(missed.count) * Self.missPenalty }

    /// Comprueba las líneas cruzadas al moverse de `from` a `to`.
    mutating func advance(from: CGPoint, to: CGPoint) -> [SlalomEvent] {
        guard !isFinished, to.y < from.y else { return [] }
        var events: [SlalomEvent] = []

        while nextGate < course.gates.count {
            let gate = course.gates[nextGate]
            guard Double(to.y) <= gate.y else { break }
            let x = Self.crossingX(from: from, to: to, atY: gate.y)
            if gate.contains(x: x) {
                passed.append(gate.index)
                events.append(.passed(gate: gate.index))
            } else {
                missed.append(gate.index)
                events.append(.missed(gate: gate.index))
            }
            nextGate += 1
        }

        if nextGate == course.gates.count, Double(to.y) <= course.finishY {
            isFinished = true
            events.append(.finished)
        }
        return events
    }

    /// `x` en el que el segmento cruza la altura `y`.
    static func crossingX(from: CGPoint, to: CGPoint, atY y: Double) -> Double {
        let dy = Double(to.y - from.y)
        guard abs(dy) > 1e-9 else { return Double(to.x) }
        let t = min(max((y - Double(from.y)) / dy, 0), 1)
        return Double(from.x) + t * Double(to.x - from.x)
    }
}

/// Resultado de una bajada de slalom terminada.
struct SlalomResult: Equatable, Sendable {
    let seconds: Double
    let gatesPassed: Int
    let gatesTotal: Int
    let penaltySeconds: Double

    var totalSeconds: Double { seconds + penaltySeconds }
    var missedGates: Int { gatesTotal - gatesPassed }

    var title: String { "¡Meta!" }

    var summary: String {
        if missedGates == 0 {
            return "Tiempo \(Self.formatTime(totalSeconds)) · ¡todas las puertas!"
        }
        return String(
            format: "%@ + %d %@ (+%.0f s) = %@",
            Self.formatTime(seconds),
            missedGates,
            missedGates == 1 ? "puerta fallada" : "puertas falladas",
            penaltySeconds,
            Self.formatTime(totalSeconds)
        )
    }

    /// `mm:ss.d`
    static func formatTime(_ seconds: Double) -> String {
        let clamped = max(0, seconds)
        let minutes = Int(clamped) / 60
        let rest = clamped - Double(minutes * 60)
        return String(format: "%02d:%04.1f", minutes, (rest * 10).rounded(.down) / 10)
    }
}
