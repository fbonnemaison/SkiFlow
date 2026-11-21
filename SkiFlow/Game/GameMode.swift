import Foundation

/// Modos de juego. Freestyle llega en la Fase 6.
enum GameMode: String, CaseIterable, Sendable {
    /// Bajar lo más lejos posible hasta que te atrapa el Kunk (o el Chupacabras).
    case freeDescent
    /// Contrarreloj entre puertas en una pista abierta.
    case slalom
    /// Contrarreloj entre puertas en un bosque denso.
    case treeSlalom

    var displayName: String {
        switch self {
        case .freeDescent: "Descenso libre"
        case .slalom: "Slalom"
        case .treeSlalom: "Slalom entre árboles"
        }
    }

    var isSlalom: Bool { self != .freeDescent }

    /// El Kunk y el Chupacabras solo aparecen en Descenso libre, para que las
    /// contrarrelojes sean justas.
    var hasCreatures: Bool { self == .freeDescent }

    /// La avalancha mete presión en los modos con meta.
    var hasAvalanche: Bool { isSlalom }

    var generatorProfile: MountainGenerator.Profile {
        switch self {
        case .freeDescent: .freeDescent
        case .slalom: .slalom
        case .treeSlalom: .treeSlalom
        }
    }

    var courseConfig: SlalomCourse.Config? {
        switch self {
        case .freeDescent: nil
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
