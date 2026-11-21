import AppKit
import SpriteKit
import SwiftUI

/// Ventana principal: menú de título o partida con su HUD, pausa y resultado.
struct ContentView: View {
    @Environment(GameModel.self) private var model
    @Environment(SettingsStore.self) private var settings
    @State private var inputMonitor = InputMonitor()
    @State private var window: NSWindow?

    var body: some View {
        ZStack {
            switch model.screen {
            case .title:
                TitleView()
                    .transition(.opacity)
            case .playing:
                SpriteView(
                    scene: model.scene,
                    preferredFramesPerSecond: 120,
                    debugOptions: debugOptions
                )
                HUDView(hud: model.hud)
                if let outcome = model.outcome {
                    ResultView(outcome: outcome)
                } else if model.isPaused {
                    PauseView()
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(WindowReader(window: $window))
        .onAppear { startInput() }
        .onDisappear { inputMonitor.stop() }
        .onChange(of: window) { _, window in
            if settings.startFullScreen, let window, !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        }
        .onChange(of: settings.pixelZoom) { _, zoom in
            model.scene.pixelZoom = CGFloat(zoom)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            // Al cambiar de app se sueltan las teclas y se pausa la partida.
            model.pauseIfPlaying()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
            // También al pasar a otra ventana de la app (por ejemplo, los Ajustes).
            if let window, note.object as? NSWindow === window {
                model.pauseIfPlaying()
            }
        }
    }

    private func startInput() {
        inputMonitor.start(
            onKey: { [model] keyCode, pressed, isRepeat, window in
                model.handleKey(keyCode, pressed: pressed, isRepeat: isRepeat, window: window)
            },
            onMouseMove: { [model] point, window in
                model.handleMouseMove(windowPoint: point, window: window)
            },
            onMouseButton: { [model] pressed in
                model.handleMouseButton(pressed: pressed)
            }
        )
    }

    private var debugOptions: SpriteView.DebugOptions {
        #if DEBUG
            [.showsFPS, .showsNodeCount]
        #else
            []
        #endif
    }
}

/// Da acceso a la `NSWindow` que contiene una vista SwiftUI.
private struct WindowReader: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = ReaderView()
        view.onWindow = { window = $0 }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ReaderView: NSView {
        var onWindow: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let window = window
            DispatchQueue.main.async { [onWindow] in onWindow?(window) }
        }
    }
}
