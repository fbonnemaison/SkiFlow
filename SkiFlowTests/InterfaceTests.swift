import Foundation
import Testing
@testable import SkiFlow

struct KeyBindingsTests {
    @Test func defaultsMatchTheClassicKeys() {
        let bindings = KeyBindings.defaults
        for code in UInt16(0)...UInt16(130) {
            // Por defecto, la asignación coincide con la tabla original de teclas.
            #expect(bindings.action(for: code) == InputAction(keyCode: code))
        }
    }

    @Test func reassigningMovesTheKey() {
        var bindings = KeyBindings.defaults
        // J (38) para brincar, en el segundo hueco.
        bindings.assign(38, to: .jump, slot: 1)
        #expect(bindings.action(for: 38) == .jump)
        #expect(bindings.keyCodes(for: .jump) == [49, 38])

        // Usar la A (0) para el turbo la quita de "girar a la izquierda".
        bindings.assign(0, to: .turbo, slot: 0)
        #expect(bindings.action(for: 0) == .turbo)
        #expect(bindings.keyCodes(for: .left) == [123])
        #expect(bindings.keyCodes(for: .turbo) == [0])
    }

    @Test func clearingAndInvalidSlots() {
        var bindings = KeyBindings.defaults
        bindings.clear(.pause, slot: 1)
        #expect(bindings.keyCodes(for: .pause) == [53])
        bindings.assign(40, to: .pause, slot: 5)
        #expect(bindings.keyCodes(for: .pause) == [53])
        bindings.assign(40, to: .modeSlalom, slot: 0)
        #expect(bindings.action(for: 40) == nil)
    }

    @Test func modeKeysAlwaysWorkUnlessTaken() {
        var bindings = KeyBindings.defaults
        #expect(bindings.action(for: 19) == .modeSlalom)
        bindings.assign(19, to: .jump, slot: 1)
        #expect(bindings.action(for: 19) == .jump)
    }

    @Test func roundTripsThroughJSON() throws {
        var bindings = KeyBindings.defaults
        bindings.assign(38, to: .jump, slot: 1)
        let data = try JSONEncoder().encode(bindings)
        #expect(String(data: data, encoding: .utf8)?.contains("\"jump\"") == true)
        #expect(try JSONDecoder().decode(KeyBindings.self, from: data) == bindings)
    }

    @Test func keyNames() {
        #expect(KeyName.name(for: 123) == "←")
        #expect(KeyName.name(for: 49) == "Espacio")
        #expect(KeyName.name(for: 13) == "W")
        #expect(KeyName.name(for: 999) == "Tecla 999")
    }
}

@MainActor
struct SettingsStoreTests {
    private func freshDefaults() throws -> UserDefaults {
        let name = "SkiFlowTests.settings"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func defaultValues() throws {
        let settings = SettingsStore(defaults: try freshDefaults())
        #expect(settings.pixelZoom == 1)
        #expect(!settings.startFullScreen)
        #expect(settings.keyBindings == .defaults)
        #expect(settings.musicVolume > 0)
    }

    @Test func changesArePersisted() throws {
        let defaults = try freshDefaults()
        let settings = SettingsStore(defaults: defaults)
        settings.pixelZoom = 1.5
        settings.effectsVolume = 0.2
        settings.startFullScreen = true
        settings.keyBindings.assign(38, to: .jump, slot: 1)

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.pixelZoom == 1.5)
        #expect(reloaded.effectsVolume == 0.2)
        #expect(reloaded.startFullScreen)
        #expect(reloaded.keyBindings.action(for: 38) == .jump)

        reloaded.resetKeyBindings()
        #expect(SettingsStore(defaults: defaults).keyBindings == .defaults)
    }

    @Test func invalidZoomFallsBackToNormal() throws {
        let defaults = try freshDefaults()
        defaults.set(7.0, forKey: "pixelZoom")
        #expect(SettingsStore(defaults: defaults).pixelZoom == 1)
    }
}

struct RecordTests {
    @Test func recordsPerMode() {
        let caught = RunOutcome.caught(GameOverInfo(caughtBy: .kunk, meters: 2500, seconds: 90, crashes: 1))
        #expect(caught.recordValue(in: .freeDescent) == 2500)
        // Atrapado por la avalancha antes de la meta: no cuenta.
        let buried = RunOutcome.caught(GameOverInfo(caughtBy: .avalanche, meters: 300, seconds: 20, crashes: 4))
        #expect(buried.recordValue(in: .slalom) == nil)

        let slalom = RunOutcome.slalom(SlalomResult(seconds: 40, gatesPassed: 19, gatesTotal: 20, penaltySeconds: 5))
        #expect(slalom.recordValue(in: .slalom) == 45)
        let freestyle = RunOutcome.freestyle(FreestyleResult(points: 900, bestJump: 400, tricks: 5, seconds: 33))
        #expect(freestyle.recordValue(in: .freestyle) == 900)
    }

    @Test func betterDependsOnTheMode() {
        #expect(GameMode.slalom.isBetter(40, than: 45))
        #expect(!GameMode.slalom.isBetter(50, than: 45))
        #expect(GameMode.freeDescent.isBetter(3000, than: 2500))
        #expect(GameMode.freestyle.isBetter(1, than: nil))
        #expect(GameMode.treeSlalom.formatRecord(45.25) == "00:45.2")
        #expect(GameMode.freeDescent.formatRecord(2500) == "2500 m")
        #expect(GameMode.freestyle.formatRecord(900) == "900 pts")
    }
}

@MainActor
struct GameModelTests {
    private let dt = 1.0 / 120.0

    private func makeModel(mode: GameMode = .freeDescent, kunk: KunkChaser.Config = .init()) throws -> GameModel {
        let name = "SkiFlowTests.model"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        let scene = GameScene(
            size: GameConfig.sceneSize, seed: 5, mode: mode,
            kunkConfig: kunk, chupacabrasConfig: .init(chance: 0)
        )
        return GameModel(settings: SettingsStore(defaults: defaults), scene: scene)
    }

    @Test func startsOnTheTitleScreen() throws {
        let model = try makeModel()
        #expect(model.screen == .title)
        #expect(model.outcome == nil)
        // En el título, las teclas de juego no llegan a la escena.
        #expect(!model.handleKey(123, pressed: true, window: nil))
    }

    @Test func returnStartsTheSelectedMode() throws {
        let model = try makeModel()
        model.selectedMode = .treeSlalom
        #expect(model.handleKey(36, pressed: true, window: nil))
        #expect(model.screen == .playing)
        #expect(model.scene.mode == .treeSlalom)
        #expect(model.hud.mode == .treeSlalom)
    }

    @Test func keysUseTheConfiguredBindings() throws {
        let model = try makeModel()
        model.start(.freeDescent)
        model.settings.keyBindings.assign(38, to: .right, slot: 0)
        #expect(model.handleKey(38, pressed: true, window: nil))
        #expect(model.scene.skier.direction == .right1)
        // Las repeticiones se tragan pero no vuelven a girar.
        #expect(model.handleKey(38, pressed: true, isRepeat: true, window: nil))
        #expect(model.scene.skier.direction == .right1)
        // Mientras los Ajustes esperan una tecla, el juego la deja pasar.
        model.settings.isCapturingKey = true
        #expect(!model.handleKey(38, pressed: false, window: nil))
    }

    @Test func pauseAndResume() throws {
        let model = try makeModel()
        model.start(.slalom)
        model.togglePause()
        #expect(model.isPaused)
        model.resume()
        #expect(!model.isPaused)
        model.pauseIfPlaying()
        #expect(model.isPaused)
        model.backToMenu()
        #expect(model.screen == .title)
    }

    @Test func seedFromTheMenuIsUsed() throws {
        let model = try makeModel()
        model.seedText = " 4242 "
        model.start(.slalom)
        #expect(model.currentSeed == 4242)
        model.seedText = "no es un número"
        #expect(model.parsedSeed == nil)
    }

    @Test func runEndShowsTheResultAndTracksTheSessionBest() throws {
        let model = try makeModel(kunk: .init(spawnMeters: 0))
        model.start(.freeDescent)
        model.scene.handle(.brake, pressed: true)
        for _ in 0..<Int(8 / dt) {
            model.scene.simulate(dt: dt)
        }
        let outcome = try #require(model.outcome)
        guard case .caught = outcome else {
            Issue.record("Se esperaba una captura")
            return
        }
        #expect(model.isNewBest)
        #expect(model.best(for: .freeDescent) != nil)

        // Reiniciar limpia el resultado.
        model.restartRun()
        #expect(model.outcome == nil)
        #expect(!model.isNewBest)
    }

    @Test func modeKeysDuringPlayUpdateTheSelection() throws {
        let model = try makeModel()
        model.start(.freeDescent)
        #expect(model.handleKey(21, pressed: true, window: nil))
        #expect(model.selectedMode == .freestyle)
        #expect(model.hud.mode == .freestyle)
    }
}

@MainActor
struct HUDTests {
    @Test func itemsDependOnTheMode() {
        let free = GameScene(size: GameConfig.sceneSize, seed: 1, mode: .freeDescent).makeHUD()
        #expect(free.items.map(\.label) == ["Distancia", "Velocidad", "Tiempo", "Caídas"])

        let slalom = GameScene(size: GameConfig.sceneSize, seed: 1, mode: .slalom).makeHUD()
        #expect(slalom.items.first == HUDItem(label: "Puerta", value: "1/20"))

        let freestyle = GameScene(size: GameConfig.sceneSize, seed: 1, mode: .freestyle).makeHUD()
        #expect(freestyle.items.first == HUDItem(label: "Puntos", value: "0"))
        #expect(freestyle.alert == nil)
    }

    @Test func avalancheAlertAppears() {
        let scene = GameScene(size: GameConfig.sceneSize, seed: 1, mode: .slalom, avalancheConfig: .init(delay: 0))
        scene.simulate(dt: 1.0 / 120.0)
        #expect(scene.makeHUD().alert?.hasPrefix("Avalancha") == true)
    }
}
