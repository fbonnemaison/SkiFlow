import Foundation

/// Modos de juego.
enum GameMode: String, CaseIterable, Sendable {
    /// Bajar lo más lejos posible hasta que te atrapa el Kunk (o el Chupacabras).
    case freeDescent
    /// Contrarreloj entre puertas en una pista abierta.
    case slalom
    /// Contrarreloj entre puertas en un bosque denso.
    case treeSlalom
    /// Saltos y trucos para sumar puntos antes de la meta.
    case freestyle

    var displayName: String {
        switch self {
        case .freeDescent: "Descenso libre"
        case .slalom: "Slalom"
        case .treeSlalom: "Slalom entre árboles"
        case .freestyle: "Freestyle"
        }
    }

    var isSlalom: Bool { self == .slalom || self == .treeSlalom }

    /// Modos con meta: R repite la misma montaña para mejorar la marca.
    var hasFinish: Bool { self != .freeDescent }

    /// Metros hasta la meta en los modos que no la marcan con puertas.
    var finishMeters: Double? { self == .freestyle ? 1000 : nil }

    /// Los saltos duran más en freestyle para que quepan los trucos.
    var airTimeMultiplier: Double { self == .freestyle ? 1.5 : 1 }

    /// El Kunk y el Chupacabras solo aparecen en Descenso libre, para que las
    /// contrarrelojes sean justas.
    var hasCreatures: Bool { self == .freeDescent }

    /// El Argentino y el Brasileño bajan por el cerro en los modos sin cronómetro
    /// estricto (en slalom no estorban para que las marcas sean justas).
    var hasRivals: Bool { self == .freeDescent || self == .freestyle }

    /// La avalancha mete presión en los modos con meta.
    var hasAvalanche: Bool { hasFinish }

    var generatorProfile: MountainGenerator.Profile {
        switch self {
        case .freeDescent: .freeDescent
        case .slalom: .slalom
        case .treeSlalom: .treeSlalom
        case .freestyle: .freestyle
        }
    }

    var courseConfig: SlalomCourse.Config? {
        switch self {
        case .freeDescent, .freestyle: nil
        case .slalom: .slalom
        case .treeSlalom: .treeSlalom
        }
    }

    /// Modo indicado al lanzar la app (`-mode slalom`), para probar.
    static func fromLaunchArguments(defaults: UserDefaults = .standard) -> GameMode {
        defaults.string(forKey: "mode").flatMap(GameMode.init(rawValue:)) ?? .freeDescent
    }
}

/// Resultado de una bajada que termina con el Cuico atrapado.
struct GameOverInfo: Equatable, Sendable {
    let caughtBy: ChaserKind
    let meters: Double
    let seconds: Double
    let crashes: Int

    var title: String {
        switch caughtBy {
        case .kunk: "¡El Kunk te atrapó!"
        case .chupacabras: "¡El Chupacabras te atrapó!"
        case .avalanche: "¡Te sepultó la avalancha!"
        }
    }

    var summary: String {
        String(
            format: "Bajaste %.0f m en %@ · caídas: %d",
            meters, GameOverInfo.formatTime(seconds), crashes
        )
    }

    /// `mm:ss`
    static func formatTime(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// Ajustes de las criaturas. Se pueden cambiar al lanzar la app para probar,
/// por ejemplo: `-kunkSpawnMeters 150 -chupacabrasChance 1 -chupacabrasMeters 60`.
enum ChaserTuning {
    static func kunk(defaults: UserDefaults = .standard) -> KunkChaser.Config {
        var config = KunkChaser.Config()
        if defaults.object(forKey: "kunkSpawnMeters") != nil {
            config.spawnMeters = defaults.double(forKey: "kunkSpawnMeters")
        }
        return config
    }

    static func chupacabras(defaults: UserDefaults = .standard) -> ChupacabrasChaser.Config {
        var config = ChupacabrasChaser.Config()
        if defaults.object(forKey: "chupacabrasChance") != nil {
            config.chance = defaults.double(forKey: "chupacabrasChance")
        }
        if defaults.object(forKey: "chupacabrasMeters") != nil {
            let meters = defaults.double(forKey: "chupacabrasMeters")
            config.minMeters = meters
            config.maxMeters = meters
        }
        return config
    }
}
