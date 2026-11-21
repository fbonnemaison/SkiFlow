import CoreGraphics
import Testing
@testable import SkiFlow

struct TrickTests {
    @Test func actionsMapToTricks() {
        #expect(Trick(action: .left) == .spinLeft)
        #expect(Trick(action: .right) == .spinRight)
        #expect(Trick(action: .down) == .frontFlip)
        #expect(Trick(action: .brake) == .backFlip)
        #expect(Trick(action: .jump) == .selfie)
        #expect(Trick(action: .turbo) == nil)
    }

    @Test func comboMultiplierGrowsWithTricks() {
        #expect(FreestyleScore.comboMultiplier(trickCount: 1) == 1)
        #expect(FreestyleScore.comboMultiplier(trickCount: 2) == 1.5)
        #expect(FreestyleScore.comboMultiplier(trickCount: 3) == 2)
    }
}

struct FreestyleScoreTests {
    /// Hace un truco completo y deja `extra` segundos de margen antes de aterrizar.
    private func perform(_ trick: Trick, on score: inout FreestyleScore, extra: Double = 0.3) {
        score.start(trick)
        _ = score.update(dt: trick.duration)
        _ = score.update(dt: extra)
    }

    @Test func onlyOneTrickAtATime() {
        var score = FreestyleScore()
        let first = score.start(.spinLeft)
        let second = score.start(.frontFlip)
        #expect(first)
        #expect(!second)
        #expect(score.update(dt: 0.2) == nil)
        #expect(score.currentProgress > 0.3)
        #expect(score.update(dt: 0.4) == .spinLeft)
        #expect(score.current == nil)
    }

    @Test func cleanLandingScoresAndBuildsTheStreak() {
        var score = FreestyleScore()
        perform(.spinRight, on: &score, extra: 0)
        perform(.backFlip, on: &score)
        // (100 + 150) × 1,5 por dos trucos.
        #expect(score.pendingPoints == 375)
        #expect(score.land(sideways: false) == .clean(points: 375))
        #expect(score.total == 375)
        #expect(score.chain == 1.5)

        perform(.selfie, on: &score)
        #expect(score.land(sideways: false) == .clean(points: 75))
        #expect(score.total == 450)
        #expect(score.tricksLanded == 3)
        #expect(score.bestJump == 375)
    }

    @Test func streakIsCapped() {
        var score = FreestyleScore()
        for _ in 0..<20 {
            perform(.selfie, on: &score)
            _ = score.land(sideways: false)
        }
        #expect(score.chain == FreestyleScore.maxChain)
    }

    @Test func lateOrSidewaysLandingIsForced() {
        var score = FreestyleScore()
        perform(.spinLeft, on: &score, extra: 0.05)
        #expect(score.land(sideways: false) == .forced(points: 50))

        perform(.spinLeft, on: &score)
        #expect(score.land(sideways: true) == .forced(points: 50))
        #expect(score.chain == 1)
    }

    @Test func landingMidTrickIsACrash() {
        var score = FreestyleScore()
        perform(.frontFlip, on: &score)
        score.start(.spinLeft)
        _ = score.update(dt: 0.1)
        #expect(score.land(sideways: false) == .crash(lostPoints: 150))
        #expect(score.total == 0)
        #expect(score.chain == 1)
        #expect(score.current == nil)
    }

    @Test func jumpsWithoutTricksDoNothing() {
        var score = FreestyleScore()
        #expect(score.land(sideways: false) == nil)
        #expect(score.total == 0)
    }

    @Test func resultText() {
        let result = FreestyleResult(points: 1234, bestJump: 450, tricks: 12, seconds: 75.3)
        #expect(result.title == "¡Fin de la sesión!")
        #expect(result.summary == "1234 puntos · mejor salto: 450 · trucos: 12 · 01:15.3")
    }
}

struct FreestyleModeTests {
    @Test func modeSettings() {
        #expect(GameMode.freestyle.hasFinish)
        #expect(GameMode.freestyle.hasAvalanche)
        #expect(!GameMode.freestyle.hasCreatures)
        #expect(!GameMode.freestyle.isSlalom)
        #expect(GameMode.freestyle.finishMeters == 1000)
        #expect(GameMode.freestyle.courseConfig == nil)
        #expect(InputAction(keyCode: 21)?.gameMode == .freestyle)
    }

    @Test func longerJumpsInFreestyle() {
        var normal = SkierPhysics()
        var freestyle = SkierPhysics()
        normal.airTimeMultiplier = 1
        freestyle.airTimeMultiplier = GameMode.freestyle.airTimeMultiplier
        var a = SkierState(speed: 400)
        var b = SkierState(speed: 400)
        normal.launch(&a)
        freestyle.launch(&b)
        #expect(abs(b.airDuration - a.airDuration * 1.5) < 1e-9)
    }

    @Test func freestyleMountainIsFullOfRamps() {
        let generator = MountainGenerator(seed: 8, profile: .freestyle)
        let kinds = (0..<10).flatMap { generator.obstacles(in: ChunkCoord(x: 0, y: $0)) }.map(\.kind)
        let ramps = kinds.filter { $0 == .ramp }.count
        #expect(ramps >= 10)
        #expect(Double(ramps) / Double(kinds.count) > 0.3)
    }
}

@MainActor
struct FreestyleSceneTests {
    private let dt = 1.0 / 120.0

    private func makeScene() -> GameScene {
        GameScene(size: GameConfig.sceneSize, seed: 21, mode: .freestyle)
    }

    @Test func spinInTheAirAndLandCleanly() throws {
        let scene = makeScene()
        for _ in 0..<120 { scene.simulate(dt: dt) }
        scene.handle(.jump, pressed: true)
        scene.handle(.jump, pressed: false)
        #expect(scene.skier.isAirborne)

        scene.handle(.right, pressed: true)
        scene.handle(.right, pressed: false)
        // En el aire, → hace un giro en vez de girar los esquís.
        #expect(scene.skier.direction == .down)
        #expect(scene.freestyle?.current == .spinRight)

        while scene.skier.isAirborne { scene.simulate(dt: dt) }
        scene.simulate(dt: dt)
        let score = try #require(scene.freestyle)
        #expect(score.total == 100)
        #expect(score.chain == 1.5)
        #expect(!scene.skier.isFallen)
    }

    @Test func landingMidFlipKnocksYouDown() {
        let scene = makeScene()
        scene.handle(.jump, pressed: true)
        scene.handle(.jump, pressed: false)
        scene.handle(.down, pressed: true)
        #expect(scene.freestyle?.current == .frontFlip)
        while scene.skier.isAirborne { scene.simulate(dt: dt) }
        scene.simulate(dt: dt)
        #expect(scene.skier.isFallen)
        #expect(scene.freestyle?.total == 0)
    }

    @Test func groundControlsStillSteer() {
        let scene = makeScene()
        scene.handle(.right, pressed: true)
        #expect(scene.skier.direction == .right1)
        #expect(scene.freestyle?.current == nil)
    }

    @Test func restartKeepsTheSameMountain() {
        let scene = makeScene()
        let seed = scene.seed
        scene.handle(.restart, pressed: true)
        #expect(scene.seed == seed)
        #expect(scene.freestyle == FreestyleScore())
    }
}
