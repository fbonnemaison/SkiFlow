import SpriteKit
import Testing
@testable import SkiFlow

@MainActor
struct GameSceneTests {
    private func makeScene() -> GameScene {
        GameScene(size: GameConfig.sceneSize, seed: 2026)
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
