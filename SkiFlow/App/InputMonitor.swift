import AppKit

/// Captura teclado y ratón de la app y se los pasa al modelo del juego.
///
/// Usa monitores locales de `NSEvent` porque `SpriteView` no recibe el foco del
/// teclado de forma fiable. Los atajos con ⌘ se dejan pasar al sistema (menús),
/// y los eventos de ratón siguen su curso normal (botones, mover la ventana…).
@MainActor
final class InputMonitor {
    private var keyMonitor: Any?
    private var mouseMonitor: Any?

    /// - Parameters:
    ///   - onKey: código de tecla, pulsada (`true`) o soltada, si es repetición
    ///     automática, y ventana del evento. Devuelve `true` si el juego la usó
    ///     (entonces no llega a nadie más).
    ///   - onMouseMove: posición del cursor en la ventana; devuelve si cae sobre el juego.
    ///   - onMouseButton: botón principal pulsado o soltado sobre el juego.
    func start(
        onKey: @escaping @MainActor (UInt16, Bool, Bool, NSWindow?) -> Bool,
        onMouseMove: @escaping @MainActor (CGPoint, NSWindow?) -> Bool,
        onMouseButton: @escaping @MainActor (Bool) -> Void
    ) {
        stop()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            if event.modifierFlags.contains(.command) { return event }
            let pressed = event.type == .keyDown
            let isRepeat = pressed && event.isARepeat
            let keyCode = event.keyCode
            let window = event.window
            let used = MainActor.assumeIsolated {
                onKey(keyCode, pressed, isRepeat, window)
            }
            return used ? nil : event
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
