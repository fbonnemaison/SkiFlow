import AppKit
import SpriteKit
import SwiftUI

/// Ventana principal: muestra la escena de juego y le pasa teclado y ratón.
/// El mando lo consulta la propia escena en cada fotograma.
struct ContentView: View {
    @State private var scene = GameScene(size: GameConfig.sceneSize)
    @State private var inputMonitor = InputMonitor()

    var body: some View {
        SpriteView(
            scene: scene,
            preferredFramesPerSecond: 120,
            debugOptions: debugOptions
        )
        .frame(minWidth: 640, minHeight: 480)
        .onAppear {
            inputMonitor.start(
                onKey: { [scene] action, pressed in
                    scene.handle(action, pressed: pressed, source: .keyboard)
                },
                onMouseMove: { [scene] point, window in
                    scene.aimMouse(windowPoint: point, window: window)
                },
                onMouseButton: { [scene] pressed in
                    scene.handle(.jump, pressed: pressed, source: .mouse)
                }
            )
        }
        .onDisappear {
            inputMonitor.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            // Al cambiar de app se sueltan las teclas y se pausa la partida.
            scene.releaseAllInput()
            if !scene.isGamePaused {
                scene.setPaused(true)
            }
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
