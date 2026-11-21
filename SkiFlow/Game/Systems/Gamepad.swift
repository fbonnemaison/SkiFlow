import CoreGraphics
import GameController

/// Foto del mando en un instante: botones pulsados y stick izquierdo.
struct GamepadState: Equatable, Sendable {
    var held: Set<InputAction> = []
    var stick: CGVector = .zero

    /// Pulsaciones y sueltas entre dos fotos, en un orden estable.
    static func transitions(from old: GamepadState, to new: GamepadState) -> [(action: InputAction, pressed: Bool)] {
        InputAction.allCases.compactMap { action in
            let before = old.held.contains(action)
            let after = new.held.contains(action)
            guard before != after else { return nil }
            return (action, after)
        }
    }
}

/// Lee el mando conectado (Xbox, PlayStation, MFi…) mediante GameController.
///
/// Se consulta en cada fotograma, así que conectar o desconectar el mando en
/// caliente funciona sin hacer nada especial.
///
/// | Mando | Acción |
/// |---|---|
/// | Stick izquierdo | Apuntar |
/// | Cruceta | Girar / recto / frenar |
/// | A (✕) | Saltar |
/// | B (○) | Frenar |
/// | X (□) o gatillo derecho | Turbo |
/// | Menú (Options) | Pausa |
/// | Vista (Share) | Reiniciar |
@MainActor
final class GamepadReader {
    /// Nombre del mando activo, si hay alguno.
    var controllerName: String? {
        activeController?.vendorName
    }

    private var activeController: GCController? {
        GCController.current ?? GCController.controllers().first { $0.extendedGamepad != nil }
    }

    func read() -> GamepadState? {
        guard let pad = activeController?.extendedGamepad else { return nil }

        var held = Set<InputAction>()
        if pad.dpad.left.isPressed { held.insert(.left) }
        if pad.dpad.right.isPressed { held.insert(.right) }
        if pad.dpad.down.isPressed { held.insert(.down) }
        if pad.dpad.up.isPressed || pad.buttonB.isPressed { held.insert(.brake) }
        if pad.buttonA.isPressed { held.insert(.jump) }
        if pad.buttonX.isPressed || pad.rightTrigger.isPressed { held.insert(.turbo) }
        if pad.buttonMenu.isPressed { held.insert(.pause) }
        if pad.buttonOptions?.isPressed == true { held.insert(.restart) }

        let stick = CGVector(
            dx: CGFloat(pad.leftThumbstick.xAxis.value),
            dy: CGFloat(pad.leftThumbstick.yAxis.value)
        )
        return GamepadState(held: held, stick: stick)
    }
}
