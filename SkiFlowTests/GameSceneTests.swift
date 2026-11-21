import SpriteKit
import Testing
@testable import SkiFlow

@MainActor
struct GameSceneTests {
    @Test func sceneUsesConfiguredSizeAndCamera() {
        let scene = GameScene(size: GameConfig.sceneSize)
        #expect(scene.size == GameConfig.sceneSize)
        #expect(scene.scaleMode == .aspectFill)
        #expect(scene.camera != nil)
        #expect(scene.childNode(withName: "//cuico") != nil)
    }

    @Test func cuicoGoesDownhillAndCameraFollows() {
        let scene = GameScene(size: GameConfig.sceneSize)
        for _ in 0..<240 {
            scene.simulate(dt: 1.0 / 120.0)
        }
        scene.update(0)

        #expect(scene.skier.position.y < 0)
        #expect(scene.skier.distanceMeters > 0)
        let camera = try! #require(scene.camera)
        #expect(camera.position.y < scene.skier.position.y)
    }

    @Test func keyPressesSteerAndRestartResets() {
        let scene = GameScene(size: GameConfig.sceneSize)
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
    }

    @Test func releaseAllInputClearsHeldKeys() {
        let scene = GameScene(size: GameConfig.sceneSize)
        scene.handle(.right, pressed: true)
        scene.releaseAllInput()
        #expect(scene.heldActions.isEmpty)
    }
}
