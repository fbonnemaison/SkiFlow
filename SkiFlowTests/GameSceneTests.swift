import SpriteKit
import Testing
@testable import SkiFlow

@MainActor
struct GameSceneTests {
    private func makeScene() -> GameScene {
        GameScene(size: GameConfig.sceneSize, seed: 2026, kunkConfig: .init(), chupacabrasConfig: .init(chance: 0))
    }

    @Test func sceneUsesConfiguredSizeAndCamera() {
        let scene = makeScene()
        #expect(scene.size == GameConfig.sceneSize)
        #expect(scene.scaleMode == .aspectFill)
        #expect(scene.camera != nil)
        #expect(scene.childNode(withName: "//cuico") != nil)
        #expect(scene.seed == 2026)
    }

    @Test func cuicoGoesDownhillAndCameraFollows() throws {
        let scene = makeScene()
        for _ in 0..<240 {
            scene.simulate(dt: 1.0 / 120.0)
        }
        scene.update(0)

        #expect(scene.skier.position.y < 0)
        #expect(scene.skier.distanceMeters > 0)
        let camera = try #require(scene.camera)
        #expect(camera.position.y < scene.skier.position.y)
    }

    @Test func keyPressesSteerAndRestartResets() {
        let scene = makeScene()
        scene.handle(.left, pressed: true)
        #expect(scene.skier.direction == .left1)

        // Una segunda pulsación sin soltar no vuelve a girar.
        scene.handle(.left, pressed: true)
        #expect(scene.skier.direction == .left1)
        scene.handle(.left, pressed: false)

        for _ in 0..<120 {
            scene.simulate(dt: 1.0 / 120.0)
        }
        #expect(scene.skier.position.x < 0)

        scene.handle(.restart, pressed: true)
        #expect(scene.skier == SkierState())
        #expect(scene.crashes == 0)
    }

    @Test func releaseAllInputClearsHeldKeys() {
        let scene = makeScene()
        scene.handle(.right, pressed: true)
        scene.releaseAllInput()
        #expect(scene.heldActions.isEmpty)
    }

    @Test func crashKnocksDownThenRecoversSideways() {
        let scene = makeScene()
        for _ in 0..<60 {
            scene.simulate(dt: 1.0 / 120.0)
        }
        let obstacle = CGRect(x: -10, y: scene.skier.position.y - 5, width: 20, height: 10)
        scene.apply(.crash, obstacleHitbox: obstacle)

        #expect(scene.skier.isFallen)
        #expect(scene.skier.speed == 0)
        #expect(scene.skier.position.y < obstacle.minY)
        #expect(scene.crashes == 1)

        // En el suelo no se puede girar.
        scene.handle(.right, pressed: true)
        #expect(scene.skier.direction == .down)
        scene.handle(.right, pressed: false)

        for _ in 0..<Int(GameScene.fallDuration * 120) + 2 {
            scene.simulate(dt: 1.0 / 120.0)
        }
        #expect(!scene.skier.isFallen)
        #expect(scene.skier.direction.isSideways)
        #expect(scene.skier.graceTime > 0)
    }

    @Test func tripSlowsDownWithoutFalling() {
        let scene = makeScene()
        for _ in 0..<60 {
            scene.simulate(dt: 1.0 / 120.0)
        }
        let before = scene.skier.speed
        scene.apply(.trip, obstacleHitbox: .zero)
        #expect(!scene.skier.isFallen)
        #expect(scene.skier.speed < before * 0.5)
    }

    @Test func rampLaunchesTheCuico() {
        let scene = makeScene()
        for _ in 0..<120 {
            scene.simulate(dt: 1.0 / 120.0)
        }
        scene.apply(.jump, obstacleHitbox: .zero)
        #expect(scene.skier.isAirborne)
    }

    @Test func chunksLoadAroundTheCuicoAndUnloadBehind() {
        let scene = makeScene()
        let mountain = try! #require(scene.childNode(withName: "//mountain") as? MountainNode)
        let initial = mountain.loadedCoords
        #expect(initial.contains(ChunkCoord(x: 0, y: 0)))

        mountain.updateLoadedChunks(center: CGPoint(x: 0, y: -20_000), viewSize: GameConfig.sceneSize, time: 0)
        #expect(!mountain.loadedCoords.contains(ChunkCoord(x: 0, y: 0)))
        #expect(mountain.loadedCoords.contains(MountainGenerator.coord(containing: CGPoint(x: 0, y: -20_000))))
        #expect(mountain.loadedCoords.count <= 12)
    }
}

@MainActor
struct GameSceneInputTests {
    private func makeScene() -> GameScene {
        GameScene(size: GameConfig.sceneSize, seed: 2026, kunkConfig: .init(), chupacabrasConfig: .init(chance: 0))
    }

    @Test func spaceHops() {
        let scene = makeScene()
        scene.handle(.jump, pressed: true)
        #expect(scene.skier.isAirborne)
    }

    @Test func pauseFreezesTheGameAndBlocksSteering() {
        let scene = makeScene()
        scene.handle(.pause, pressed: true)
        #expect(scene.isGamePaused)
        scene.handle(.pause, pressed: false)

        scene.handle(.left, pressed: true)
        #expect(scene.skier.direction == .down)
        scene.handle(.left, pressed: false)

        scene.update(10)
        scene.update(11)
        #expect(scene.skier.position == .zero)

        scene.handle(.pause, pressed: true)
        #expect(!scene.isGamePaused)
    }

    @Test func turboWhileHeld() {
        let scene = makeScene()
        scene.handle(.turbo, pressed: true)
        #expect(scene.isTurboActive)
        scene.handle(.turbo, pressed: false)
        #expect(!scene.isTurboActive)
    }

    @Test func gamepadButtonsAndStick() {
        let scene = makeScene()
        scene.applyGamepad(GamepadState(held: [.jump], stick: CGVector(dx: 0.9, dy: -0.9)))
        #expect(scene.skier.isAirborne)

        for _ in 0..<60 {
            scene.simulate(dt: 1.0 / 120.0)
        }
        #expect(scene.skier.direction == .right2)

        // Al desconectar el mando se sueltan sus botones.
        scene.applyGamepad(nil)
        #expect(scene.heldActions.isEmpty)
    }

    @Test func mouseAimSteersAndKeyboardTakesOver() {
        let scene = makeScene()
        // Cursor abajo a la izquierda del Cuico.
        scene.aimMouse(atScenePoint: CGPoint(x: -300, y: -300))
        for _ in 0..<60 {
            scene.simulate(dt: 1.0 / 120.0)
        }
        #expect(scene.skier.direction.rawValue < 0)

        scene.handle(.down, pressed: true)
        #expect(scene.skier.direction == .down)
        #expect(scene.input.mouseAim == nil)
    }

    @Test func mouseClickJumps() {
        let scene = makeScene()
        scene.handle(.jump, pressed: true, source: .mouse)
        #expect(scene.skier.isAirborne)
    }
}

@MainActor
struct GameSceneChaseTests {
    private let dt = 1.0 / 120.0

    @Test func kunkCatchesTheCuicoAndTheRunEnds() {
        let scene = GameScene(
            size: GameConfig.sceneSize, seed: 2026,
            kunkConfig: .init(spawnMeters: 0), chupacabrasConfig: .init(chance: 0)
        )
        // Frenado en la salida: el Kunk llega enseguida.
        scene.handle(.brake, pressed: true)
        for _ in 0..<Int(4 / dt) {
            scene.simulate(dt: dt)
        }
        #expect(scene.caughtBy == .kunk)
        #expect(scene.kunk.phase == .caught)

        // Atrapado: no se puede pausar ni girar.
        scene.handle(.pause, pressed: true)
        #expect(!scene.isGamePaused)

        for _ in 0..<Int((GameScene.catchDuration + 0.1) / dt) {
            scene.simulate(dt: dt)
        }
        let info = try! #require(scene.gameOver)
        #expect(info.caughtBy == .kunk)

        // Reiniciar deja todo como al principio.
        scene.handle(.restart, pressed: true)
        #expect(scene.gameOver == nil)
        #expect(scene.caughtBy == nil)
        #expect(scene.kunk.phase == .waiting)
        #expect(scene.skier == SkierState())
    }

    @Test func chupacabrasEncounterIsCounted() {
        let scene = GameScene(
            size: GameConfig.sceneSize, seed: 2026,
            kunkConfig: .init(spawnMeters: 1_000_000),
            chupacabrasConfig: .init(chance: 1, minMeters: 5, maxMeters: 5)
        )
        for _ in 0..<Int(1 / dt) {
            scene.simulate(dt: dt)
        }
        #expect(scene.chupacabrasEncounters == 1)
        #expect(scene.chupacabras.phase != .waiting)
    }
}
