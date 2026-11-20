import SpriteKit
import Testing
@testable import SkiFlow

@MainActor
struct GameSceneTests {
    @Test func sceneUsesConfiguredSize() {
        let scene = GameScene(size: GameConfig.sceneSize)
        #expect(scene.size == GameConfig.sceneSize)
        #expect(scene.scaleMode == .aspectFill)
    }

    @Test func sceneShowsTitleOnceWhenPresented() {
        let scene = GameScene(size: GameConfig.sceneSize)
        let view = SKView(frame: CGRect(origin: .zero, size: GameConfig.sceneSize))
        view.presentScene(scene)
        scene.didMove(to: view)

        let titles = scene.children.filter { $0.name == "title" }
        #expect(titles.count == 1)
    }
}
