import AppKit
import SpriteKit
import SwiftUI

/// Ventana principal: muestra la escena de juego y le pasa el teclado.
struct ContentView: View {
    @State private var scene = GameScene(size: GameConfig.sceneSize)
    @State private var keyboard = KeyboardMonitor()

    var body: some View {
        SpriteView(
            scene: scene,
            preferredFramesPerSecond: 120,
            debugOptions: debugOptions
        )
        .frame(minWidth: 640, minHeight: 480)
        .onAppear {
            keyboard.start { [scene] action, pressed in
                scene.handle(action, pressed: pressed)
            }
        }
        .onDisappear {
            keyboard.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            scene.releaseAllInput()
        }
    }

    private var debugOptions: SpriteView.DebugOptions {
        #if DEBUG
            [.showsFPS, .showsNodeCount]
        #else
            []
        #endif
    }
}

#Preview {
    ContentView()
}
