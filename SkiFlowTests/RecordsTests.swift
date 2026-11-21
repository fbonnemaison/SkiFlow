import Foundation
import Testing
@testable import SkiFlow

@MainActor
struct RecordStoreTests {
    private func makeStore() throws -> RecordStore {
        RecordStore(container: try RecordStore.makeContainer(inMemory: true))
    }

    private func descent(_ meters: Double, by kind: ChaserKind = .kunk, encounters: Int = 0) -> RunReport {
        RunReport(
            mode: .freeDescent,
            outcome: .caught(GameOverInfo(caughtBy: kind, meters: meters, seconds: meters / 30, crashes: 1)),
            seed: UInt64(meters), meters: meters, seconds: meters / 30, crashes: 1,
            chupacabrasEncounters: encounters
        )
    }

    private func slalom(_ seconds: Double, mode: GameMode = .slalom) -> RunReport {
        RunReport(
            mode: mode,
            outcome: .slalom(SlalomResult(seconds: seconds, gatesPassed: 20, gatesTotal: 20, penaltySeconds: 0)),
            seed: 1, meters: 600, seconds: seconds, crashes: 0, chupacabrasEncounters: 0
        )
    }

    @Test func descentKeepsTheLongestRunsFirst() throws {
        let store = try makeStore()
        #expect(store.register(descent(1500)).rank == 1)
        #expect(store.register(descent(3000)).isNewBest)
        #expect(store.register(descent(2000)).rank == 2)

        let top = store.top(.freeDescent)
        #expect(top.map(\.value) == [3000, 2000, 1500])
        #expect(store.best(.freeDescent)?.seed == 3000)
    }

    @Test func slalomKeepsTheFastestTimesFirst() throws {
        let store = try makeStore()
        store.register(slalom(45))
        store.register(slalom(38.5))
        #expect(store.register(slalom(41)).rank == 2)
        #expect(store.top(.slalom).map(\.value) == [38.5, 41, 45])
        // Cada modo tiene su propio ranking.
        #expect(store.top(.treeSlalom).isEmpty)
    }

    @Test func runsThatDoNotCountAreNotRanked() throws {
        let store = try makeStore()
        let buried = RunReport(
            mode: .slalom,
            outcome: .caught(GameOverInfo(caughtBy: .avalanche, meters: 200, seconds: 12, crashes: 4)),
            seed: 9, meters: 200, seconds: 12, crashes: 4, chupacabrasEncounters: 0
        )
        #expect(store.register(buried).rank == nil)
        #expect(store.top(.slalom).isEmpty)
        #expect(store.stats.avalancheBurials == 1)
        #expect(store.stats.runs == 1)
    }

    @Test func outsideTheTopTenHasNoRank() throws {
        let store = try makeStore()
        for meters in stride(from: 1000.0, through: 10_000, by: 1000) {
            store.register(descent(meters))
        }
        #expect(store.top(.freeDescent).count == RecordStore.topCount)
        #expect(store.register(descent(10)).rank == nil)
    }

    @Test func oldWorstRecordsArePruned() throws {
        let store = try makeStore()
        for meters in 1...(RecordStore.keptPerMode + 5) {
            store.register(descent(Double(meters) * 10))
        }
        let all = store.top(.freeDescent, limit: 1000)
        #expect(all.count == RecordStore.keptPerMode)
        #expect(all.last?.value == 60) // se borraron las 5 peores (10…50)
    }

    @Test func statisticsAccumulate() throws {
        let store = try makeStore()
        store.register(descent(1000, by: .kunk, encounters: 1))
        store.register(descent(500, by: .chupacabras, encounters: 1))
        store.register(slalom(40))
        store.register(RunReport(
            mode: .freestyle,
            outcome: .freestyle(FreestyleResult(points: 900, bestJump: 400, tricks: 7, seconds: 33)),
            seed: 2, meters: 1000, seconds: 33, crashes: 2, chupacabrasEncounters: 0
        ))

        let stats = store.stats
        #expect(stats.runs == 4)
        #expect(stats.totalMeters == 3100)
        #expect(stats.kunkCaptures == 1)
        #expect(stats.chupacabrasCaptures == 1)
        #expect(stats.chupacabrasEncounters == 2)
        #expect(stats.slalomsFinished == 1)
        #expect(stats.freestyleTricks == 7)
        #expect(stats.totalCrashes == 4)
    }

    @Test func resetClearsEverything() throws {
        let store = try makeStore()
        store.register(descent(1000))
        store.reset()
        #expect(store.top(.freeDescent).isEmpty)
        #expect(store.stats.runs == 0)
    }

    @Test func seedsSurviveTheRoundTrip() throws {
        let store = try makeStore()
        let big = UInt64.max - 7
        store.register(RunReport(
            mode: .freestyle,
            outcome: .freestyle(FreestyleResult(points: 100, bestJump: 100, tricks: 1, seconds: 30)),
            seed: big, meters: 1000, seconds: 30, crashes: 0, chupacabrasEncounters: 0
        ))
        #expect(store.best(.freestyle)?.seed == big)
        #expect(store.best(.freestyle)?.mode == .freestyle)
    }
}

@MainActor
struct GameModelRecordsTests {
    private let dt = 1.0 / 120.0

    private func makeModel() throws -> GameModel {
        let name = "SkiFlowTests.records"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        let scene = GameScene(size: GameConfig.sceneSize, seed: 8, kunkConfig: .init(spawnMeters: 0), chupacabrasConfig: .init(chance: 0))
        let store = RecordStore(container: try RecordStore.makeContainer(inMemory: true))
        return GameModel(settings: SettingsStore(defaults: defaults), scene: scene, records: store)
    }

    private func playUntilCaught(_ model: GameModel) {
        model.scene.handle(.brake, pressed: true)
        for _ in 0..<Int(8 / dt) where model.outcome == nil {
            model.scene.simulate(dt: dt)
        }
        model.scene.handle(.brake, pressed: false)
    }

    @Test func finishedRunsAreSavedAndRanked() throws {
        let model = try makeModel()
        model.start(.freeDescent)
        playUntilCaught(model)
        #expect(model.outcome != nil)
        #expect(model.isNewBest)
        #expect(model.lastRank == 1)
        #expect(model.best(for: .freeDescent) != nil)
        #expect(model.topRecords(for: .freeDescent).count == 1)
        #expect(model.stats?.kunkCaptures == 1)
    }

    @Test func replayUsesTheRecordSeed() throws {
        let model = try makeModel()
        model.start(.freeDescent)
        playUntilCaught(model)
        let record = try #require(model.topRecords(for: .freeDescent).first)
        model.backToMenu()
        model.isShowingRecords = true
        model.replay(record)
        #expect(!model.isShowingRecords)
        #expect(model.screen == .playing)
        #expect(model.currentSeed == record.seed)
    }

    @Test func resetFromTheModel() throws {
        let model = try makeModel()
        model.start(.freeDescent)
        playUntilCaught(model)
        model.resetRecords()
        #expect(model.best(for: .freeDescent) == nil)
        #expect(model.stats?.runs == 0)
    }
}
