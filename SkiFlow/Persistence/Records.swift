import Foundation
import SwiftData

/// Una marca guardada: una bajada que cuenta como récord en su modo.
@Model
final class RunRecord {
    /// `GameMode.rawValue`.
    var modeRaw: String
    /// Metros (Descenso libre), segundos con penalización (slalom) o puntos (freestyle).
    var value: Double
    var date: Date
    /// Semilla de la montaña, para poder repetirla (guardada como `Int64`).
    var seedBits: Int64
    /// Resumen legible de la bajada.
    var summary: String
    var crashes: Int

    init(mode: GameMode, value: Double, date: Date, seed: UInt64, summary: String, crashes: Int) {
        modeRaw = mode.rawValue
        self.value = value
        self.date = date
        seedBits = Int64(bitPattern: seed)
        self.summary = summary
        self.crashes = crashes
    }

    var mode: GameMode { GameMode(rawValue: modeRaw) ?? .freeDescent }
    var seed: UInt64 { UInt64(bitPattern: seedBits) }
}

/// Estadísticas acumuladas del jugador (una sola fila).
@Model
final class PlayerStats {
    var runs: Int = 0
    var totalMeters: Double = 0
    var totalSeconds: Double = 0
    var totalCrashes: Int = 0
    var kunkCaptures: Int = 0
    var chupacabrasEncounters: Int = 0
    var chupacabrasCaptures: Int = 0
    var avalancheBurials: Int = 0
    var slalomsFinished: Int = 0
    var freestyleTricks: Int = 0

    init() {}
}

/// Lo que se sabe de una bajada al terminar, para guardarla.
struct RunReport: Sendable {
    let mode: GameMode
    let outcome: RunOutcome
    let seed: UInt64
    let meters: Double
    let seconds: Double
    let crashes: Int
    let chupacabrasEncounters: Int
}

/// Resultado de guardar una bajada.
struct RecordPlacement: Equatable, Sendable {
    /// Puesto en el top 10 del modo (1 = récord), o `nil` si no entra o no cuenta.
    let rank: Int?
    var isNewBest: Bool { rank == 1 }
}

/// Récords y estadísticas guardados con SwiftData.
@MainActor
final class RecordStore {
    static let topCount = 10
    /// Marcas que se conservan por modo (las peores se borran).
    static let keptPerMode = 50

    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
    }

    /// Contenedor de la app (en disco) o en memoria (tests y vistas previas).
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: RunRecord.self, PlayerStats.self, configurations: configuration)
    }

    // MARK: Consultas

    /// Mejores marcas de un modo, de mejor a peor.
    func top(_ mode: GameMode, limit: Int = RecordStore.topCount) -> [RunRecord] {
        let raw = mode.rawValue
        var descriptor = FetchDescriptor<RunRecord>(
            predicate: #Predicate { $0.modeRaw == raw },
            sortBy: [
                SortDescriptor(\.value, order: mode.lowerRecordIsBetter ? .forward : .reverse),
                SortDescriptor(\.date, order: .forward),
            ]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func best(_ mode: GameMode) -> RunRecord? {
        top(mode, limit: 1).first
    }

    var stats: PlayerStats {
        if let existing = try? context.fetch(FetchDescriptor<PlayerStats>()).first {
            return existing
        }
        let stats = PlayerStats()
        context.insert(stats)
        return stats
    }

    // MARK: Guardado

    /// Guarda una bajada: actualiza las estadísticas y, si cuenta, la marca.
    @discardableResult
    func register(_ report: RunReport, date: Date = .now) -> RecordPlacement {
        updateStats(with: report)

        var placement = RecordPlacement(rank: nil)
        if let value = report.outcome.recordValue(in: report.mode) {
            let record = RunRecord(
                mode: report.mode, value: value, date: date, seed: report.seed,
                summary: report.outcome.summary, crashes: report.crashes
            )
            context.insert(record)
            let ranking = top(report.mode, limit: Self.topCount)
            placement = RecordPlacement(rank: ranking.firstIndex { $0 === record }.map { $0 + 1 })
            prune(report.mode)
        }
        try? context.save()
        return placement
    }

    /// Borra todas las marcas y estadísticas.
    func reset() {
        try? context.delete(model: RunRecord.self)
        try? context.delete(model: PlayerStats.self)
        try? context.save()
    }

    private func updateStats(with report: RunReport) {
        let stats = stats
        stats.runs += 1
        stats.totalMeters += report.meters
        stats.totalSeconds += report.seconds
        stats.totalCrashes += report.crashes
        stats.chupacabrasEncounters += report.chupacabrasEncounters
        switch report.outcome {
        case let .caught(info):
            switch info.caughtBy {
            case .kunk: stats.kunkCaptures += 1
            case .chupacabras: stats.chupacabrasCaptures += 1
            case .avalanche: stats.avalancheBurials += 1
            }
        case .slalom:
            stats.slalomsFinished += 1
        case let .freestyle(result):
            stats.freestyleTricks += result.tricks
        }
    }

    private func prune(_ mode: GameMode) {
        let all = top(mode, limit: Int.max)
        for record in all.dropFirst(Self.keptPerMode) {
            context.delete(record)
        }
    }
}
