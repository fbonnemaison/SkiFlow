import AppKit

/// Captura teclado y ratón de la ventana activa y se los pasa a la escena.
///
/// Usa monitores locales de `NSEvent` porque `SpriteView` no recibe el foco del
/// teclado de forma fiable. Los atajos con ⌘ se dejan pasar al sistema, y los
/// eventos de ratón siguen su curso normal (para poder mover la ventana, etc.).
@MainActor
final class InputMonitor {
    private var keyMonitor: Any?
    private var mouseMonitor: Any?

    /// - Parameters:
    ///   - onKey: acción de teclado pulsada (`true`) o soltada (`false`).
    ///   - onMouseMove: posición del cursor en la ventana; devuelve si cae sobre el juego.
    ///   - onMouseButton: botón principal pulsado o soltado sobre el juego.
    func start(
        onKey: @escaping @MainActor (InputAction, Bool) -> Void,
        onMouseMove: @escaping @MainActor (CGPoint, NSWindow?) -> Bool,
        onMouseButton: @escaping @MainActor (Bool) -> Void
    ) {
        stop()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            if event.modifierFlags.contains(.command) { return event }
            guard let action = InputAction(keyCode: event.keyCode) else { return event }

            let pressed = event.type == .keyDown
            // La repetición la gestiona el propio juego.
            if pressed && event.isARepeat { return nil }

            MainActor.assumeIsolated {
                onKey(action, pressed)
            }
            return nil
        }

        mouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]
        ) { event in
            let point = event.locationInWindow
            let window = event.window
            let type = event.type
            MainActor.assumeIsolated {
                let inside = onMouseMove(point, window)
                switch type {
                case .leftMouseDown where inside:
                    onMouseButton(true)
                case .leftMouseUp:
                    onMouseButton(false)
                default:
                    break
                }
            }
            return event
        }
    }

    func stop() {
        for monitor in [keyMonitor, mouseMonitor].compactMap({ $0 }) {
            NSEvent.removeMonitor(monitor)
        }
        keyMonitor = nil
        mouseMonitor = nil
    }
}
