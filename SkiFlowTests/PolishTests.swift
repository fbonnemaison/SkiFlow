import CoreGraphics
import Foundation
import Testing
@testable import SkiFlow

struct CuicoVoiceTests {
    @Test func respectsTheCooldownExceptForUrgentMoments() {
        var voice = CuicoVoice(seed: 1)
        #expect(voice.line(for: .crash, at: 0) != nil)
        #expect(voice.line(for: .trip, at: 1) == nil)
        #expect(voice.line(for: .kunk, at: 1.5) != nil) // urgente
        #expect(voice.line(for: .trip, at: 5) != nil)
    }

    @Test func doesNotRepeatTheSameLineTwiceInARow() {
        var voice = CuicoVoice(seed: 9)
        var previous: String?
        for i in 0..<20 {
            let line = voice.line(for: .crash, at: Double(i) * 10)
            #expect(line != nil)
            #expect(line != previous)
            previous = line
        }
    }

    @Test func everyMomentHasLines() {
        for moment in CuicoMoment.allCases {
            #expect(!moment.lines.isEmpty)
        }
    }
}

struct SecretCodeTests {
    @Test func typingCuicoUnlocksIt() {
        var code = SecretCode.cuico
        let typed: [UInt16] = [8, 32, 34, 8] // C U I C
        var unlocked = typed.map { code.register($0) }
        #expect(!unlocked.contains(true))
        unlocked = [code.register(31)] // O
        #expect(unlocked == [true])
    }

    @Test func wrongKeysResetTheCode() {
        var code = SecretCode.cuico
        _ = code.register(8)
        _ = code.register(32)
        _ = code.register(0) // A: se rompe
        let rest: [UInt16] = [34, 8, 31]
        let afterBreak = rest.map { code.register($0) }
        #expect(!afterBreak.contains(true))
        // Empezar de nuevo funciona (y una C a mitad reinicia en el primer paso).
        let again: [UInt16] = [8, 8, 32, 34, 8]
        let restarted = again.map { code.register($0) }
        #expect(!restarted.contains(true))
        let finished = code.register(31)
        #expect(finished)
    }
}

@MainActor
struct PolishSceneTests {
    private let dt = 1.0 / 120.0

    private func makeScene(mode: GameMode = .freeDescent) -> GameScene {
        GameScene(size: GameConfig.sceneSize, seed: 4, mode: mode, kunkConfig: .init(spawnMeters: 1e9), chupacabrasConfig: .init(chance: 0))
    }

    @Test func crashesFreezeBrieflyUnlessMotionIsReduced() {
        let scene = makeScene()
        scene.apply(.crash, obstacleHitbox: .zero)
        #expect(scene.hitStop > 0)

        let calm = makeScene()
        calm.reduceMotion = true
        calm.apply(.crash, obstacleHitbox: .zero)
        #expect(calm.hitStop == 0)
    }

    @Test func theCuicoTalks() {
        let scene = makeScene()
        // Al empezar la bajada dice algo.
        #expect(scene.lastCuicoLine.map(CuicoMoment.runStart.lines.contains) == true)
        for _ in 0..<Int(4 / dt) { scene.simulate(dt: dt) }
        scene.apply(.crash, obstacleHitbox: .zero)
        #expect(scene.lastCuicoLine.map(CuicoMoment.crash.lines.contains) == true)
    }

    @Test func standingStillTriggersTheSelfiePose() {
        let scene = makeScene()
        let audio = FakeAudio()
        scene.audio = audio
        scene.handle(.brake, pressed: true)
        for _ in 0..<Int(5 / dt) { scene.simulate(dt: dt) }
        #expect(audio.effects.contains(.selfie))
        // Si habló hace menos de 3 s (al empezar), posa sin decir nada.
        let line = scene.lastCuicoLine ?? ""
        #expect(CuicoMoment.idle.lines.contains(line) || CuicoMoment.runStart.lines.contains(line))
    }

    @Test func goldenParka() {
        let scene = makeScene()
        #expect(!scene.isCuicoGolden)
        scene.isCuicoGolden = true
        #expect(scene.isCuicoGolden)
        #expect(CuicoNode.goldenBodyArt.pixels().flatMap { $0 }.contains(0xF2C230))
    }

    @Test func gamepadOnTheResultScreen() {
        let scene = GameScene(size: GameConfig.sceneSize, seed: 4, kunkConfig: .init(spawnMeters: 0), chupacabrasConfig: .init(chance: 0))
        var menuRequests = 0
        scene.onMenuRequested = { menuRequests += 1 }
        scene.handle(.brake, pressed: true)
        for _ in 0..<Int(8 / dt) where !scene.isRunOver { scene.simulate(dt: dt) }
        scene.handle(.brake, pressed: false)
        #expect(scene.isRunOver)

        // B en el mando vuelve al menú; A repite.
        scene.applyGamepad(GamepadState(held: [.brake]))
        #expect(menuRequests == 1)
        scene.applyGamepad(GamepadState())
        scene.applyGamepad(GamepadState(held: [.jump]))
        #expect(!scene.isRunOver)
    }

    @Test func kunkTiringShowsInTheHUD() {
        let scene = GameScene(size: GameConfig.sceneSize, seed: 4, kunkConfig: .init(spawnMeters: 0, escapeDistance: 0, escapeTime: 100), chupacabrasConfig: .init(chance: 0))
        scene.simulate(dt: dt)
        scene.simulate(dt: dt)
        #expect(scene.makeHUD().alert?.contains("cansando") == true)
    }
}

@MainActor
struct MenuGamepadTests {
    private func makeModel() throws -> GameModel {
        let name = "SkiFlowTests.menupad"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return GameModel(settings: SettingsStore(defaults: defaults), scene: GameScene(size: GameConfig.sceneSize, seed: 2))
    }

    @Test func dpadChoosesAndAStarts() throws {
        let model = try makeModel()
        model.selectedMode = .freeDescent
        model.handleMenuGamepad(GamepadState(held: [.right]))
        #expect(model.selectedMode == .slalom)
        model.handleMenuGamepad(GamepadState())
        model.handleMenuGamepad(GamepadState(held: [.left]))
        model.handleMenuGamepad(GamepadState())
        model.handleMenuGamepad(GamepadState(held: [.left]))
        #expect(model.selectedMode == .freestyle) // da la vuelta
        model.handleMenuGamepad(GamepadState())
        model.handleMenuGamepad(GamepadState(held: [.jump]))
        #expect(model.screen == .playing)
        #expect(model.scene.mode == .freestyle)
    }

    @Test func stickStepsOncePerTilt() throws {
        let model = try makeModel()
        model.selectedMode = .freeDescent
        model.handleMenuGamepad(GamepadState(stick: CGVector(dx: 0.9, dy: 0)))
        model.handleMenuGamepad(GamepadState(stick: CGVector(dx: 0.9, dy: 0)))
        #expect(model.selectedMode == .slalom)
        model.handleMenuGamepad(GamepadState())
        model.handleMenuGamepad(GamepadState(stick: CGVector(dx: 0.9, dy: 0)))
        #expect(model.selectedMode == .treeSlalom)
    }

    @Test func goldenCodeFromTheKeyboard() throws {
        let model = try makeModel()
        for key: UInt16 in [8, 32, 34, 8, 31] {
            _ = model.handleKey(key, pressed: true, window: nil)
        }
        #expect(model.isGoldenCuico)
        #expect(model.scene.isCuicoGolden)
    }

    @Test func accessibilitySettingsPersist() throws {
        let name = "SkiFlowTests.a11y"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        let settings = SettingsStore(defaults: defaults)
        settings.reduceMotion = true
        settings.highContrastHUD = true
        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.reduceMotion)
        #expect(reloaded.highContrastHUD)

        let model = GameModel(settings: reloaded, scene: GameScene(size: GameConfig.sceneSize, seed: 2))
        #expect(model.scene.reduceMotion)
    }
}
