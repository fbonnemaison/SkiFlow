import AppKit

/// Captura las teclas de juego de la ventana activa y las traduce a `InputAction`.
///
/// Usa un monitor local de `NSEvent` porque `SpriteView` no recibe el foco del
/// teclado de forma fiable. Los atajos con ⌘ se dejan pasar al sistema.
@MainActor
final class KeyboardMonitor {
    private var monitor: Any?

    func start(handler: @escaping @MainActor (InputAction, Bool) -> Void) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            if event.modifierFlags.contains(.command) { return event }
            guard let action = InputAction(keyCode: event.keyCode) else { return event }

            let pressed = event.type == .keyDown
            // La repetición la gestiona el propio juego.
            if pressed && event.isARepeat { return nil }

            MainActor.assumeIsolated {
                handler(action, pressed)
            }
            return nil
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
