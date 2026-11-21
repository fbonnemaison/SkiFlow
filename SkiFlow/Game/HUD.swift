import Foundation

/// Un dato del HUD (etiqueta y valor).
struct HUDItem: Equatable, Sendable, Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

/// Lo que la interfaz SwiftUI muestra encima de la partida. La escena lo genera
/// en cada fotograma y la vista solo se redibuja si cambia.
struct HUDSnapshot: Equatable, Sendable {
    var mode: GameMode = .freeDescent
    var items: [HUDItem] = []
    /// Aviso en rojo (Kunk, Chupacabras, avalancha).
    var alert: String?
    var isTurbo = false
}

/// Cómo terminó una bajada.
enum RunOutcome: Equatable, Sendable {
    case caught(GameOverInfo)
    case slalom(SlalomResult)
    case freestyle(FreestyleResult)

    var title: String {
        switch self {
        case let .caught(info): info.title
        case let .slalom(result): result.title
        case let .freestyle(result): result.title
        }
    }

    var summary: String {
        switch self {
        case let .caught(info): info.summary
        case let .slalom(result): result.summary
        case let .freestyle(result): result.summary
        }
    }

    /// Valor de la marca, si la bajada cuenta como marca en su modo.
    /// Descenso libre: metros. Slalom: segundos con penalización. Freestyle: puntos.
    func recordValue(in mode: GameMode) -> Double? {
        switch (self, mode) {
        case let (.caught(info), .freeDescent): info.meters
        case let (.slalom(result), _): result.totalSeconds
        case let (.freestyle(result), _): Double(result.points)
        default: nil // atrapado por la avalancha antes de la meta
        }
    }
}

extension GameMode {
    /// En slalom gana el menor tiempo; en el resto, el mayor valor.
    var lowerRecordIsBetter: Bool { isSlalom }

    func isBetter(_ value: Double, than best: Double?) -> Bool {
        guard let best else { return true }
        return lowerRecordIsBetter ? value < best : value > best
    }

    /// Texto de una marca para mostrarla.
    func formatRecord(_ value: Double) -> String {
        switch self {
        case .freeDescent: String(format: "%.0f m", value)
        case .slalom, .treeSlalom: SlalomResult.formatTime(value)
        case .freestyle: "\(Int(value)) pts"
        }
    }

    /// Descripción para el menú principal.
    var summary: String {
        switch self {
        case .freeDescent: "Baja lo más lejos que puedas. A los 2.000 m sale el Kunk… y quién sabe qué más."
        case .slalom: "20 puertas contra el reloj en pista abierta. Cada puerta fallada suma 5 s."
        case .treeSlalom: "Las mismas puertas, pero entre araucarias y queñuas."
        case .freestyle: "1.000 m de rampas. Giros, mortales y selfies para sumar puntos."
        }
    }

    var symbolName: String {
        switch self {
        case .freeDescent: "mountain.2"
        case .slalom: "flag.2.crossed"
        case .treeSlalom: "tree"
        case .freestyle: "figure.skiing.downhill"
        }
    }
}
