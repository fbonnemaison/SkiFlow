import SpriteKit
import SwiftUI

/// Ventana principal: muestra la escena de juego de SpriteKit.
struct ContentView: View {
    @State private var scene = GameScene(size: GameConfig.sceneSize)

    var body: some View {
        SpriteView(scene: scene, preferredFramesPerSecond: 120)
            .ignoresSafeArea()
            .frame(minWidth: 640, minHeight: 480)
    }
}

#Preview {
    ContentView()
}
