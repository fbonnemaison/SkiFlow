import Foundation

/// Asignación de teclas a acciones. Cada acción reasignable tiene hasta dos teclas.
///
/// Se guarda como JSON en las preferencias. Los atajos de modo (1–4) no se
/// reasignan y siempre funcionan si la tecla no está ocupada.
struct KeyBindings: Codable, Equatable, Sendable {
    static let slotsPerAction = 2

    /// Teclas por acción (por código físico de tecla).
    private(set) var keys: [InputAction: [UInt16]]

    /// Asignación por defecto: flechas y WASD, Espacio, F, Esc/P y R.
    static let defaults = KeyBindings(keys: [
        .left: [123, 0],
        .right: [124, 2],
        .down: [125, 1],
        .brake: [126, 13],
        .jump: [49],
        .turbo: [3],
        .pause: [53, 35],
        .restart: [15],
    ])

    private static let modeKeys: [UInt16: InputAction] = [
        18: .modeFreeDescent, 19: .modeSlalom, 20: .modeTreeSlalom, 21: .modeFreestyle,
    ]

    /// Acción de una tecla, si tiene alguna.
    func action(for keyCode: UInt16) -> InputAction? {
        for (action, codes) in keys where codes.contains(keyCode) {
            return action
        }
        return Self.modeKeys[keyCode]
    }

    /// Teclas de una acción (hasta `slotsPerAction`).
    func keyCodes(for action: InputAction) -> [UInt16] {
        keys[action] ?? []
    }

    /// Asigna una tecla al hueco `slot` de una acción. La tecla se quita de
    /// cualquier otra acción para que no haya duplicados.
    mutating func assign(_ keyCode: UInt16, to action: InputAction, slot: Int) {
        guard InputAction.rebindable.contains(action), (0..<Self.slotsPerAction).contains(slot) else { return }
        for other in keys.keys {
            keys[other]?.removeAll { $0 == keyCode }
        }
        var codes = keys[action] ?? []
        if slot < codes.count {
            codes[slot] = keyCode
        } else {
            codes.append(keyCode)
        }
        keys[action] = codes
    }

    /// Quita la tecla del hueco `slot` de una acción.
    mutating func clear(_ action: InputAction, slot: Int) {
        guard var codes = keys[action], slot < codes.count else { return }
        codes.remove(at: slot)
        keys[action] = codes
    }

    // MARK: Codable con claves legibles

    private init(keys: [InputAction: [UInt16]]) {
        self.keys = keys
    }

    init(from decoder: Decoder) throws {
        let raw = try [String: [UInt16]](from: decoder)
        var keys: [InputAction: [UInt16]] = [:]
        for (name, codes) in raw {
            if let action = InputAction(rawValue: name) { keys[action] = codes }
        }
        self.keys = keys
    }

    func encode(to encoder: Encoder) throws {
        let raw = Dictionary(uniqueKeysWithValues: keys.map { ($0.key.rawValue, $0.value) })
        try raw.encode(to: encoder)
    }
}

/// Nombre legible de una tecla física (para los Ajustes).
enum KeyName {
    private static let names: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8", 29: "0", 31: "O",
        32: "U", 34: "I", 35: "P", 36: "↩︎", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        48: "⇥", 49: "Espacio", 51: "⌫", 53: "Esc", 56: "⇧", 58: "⌥", 59: "⌃",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    static func name(for keyCode: UInt16) -> String {
        names[keyCode] ?? "Tecla \(keyCode)"
    }
}
