import Foundation
import Observation

/// Ajustes del juego, guardados en las preferencias del usuario.
@MainActor
@Observable
final class SettingsStore {
    /// Escalas de píxel disponibles (zoom de la cámara).
    static let pixelZooms: [Double] = [1, 1.25, 1.5]

    @ObservationIgnored private let defaults: UserDefaults

    /// Volumen de la música (0…1). El audio llega en la Fase 9.
    var musicVolume: Double { didSet { defaults.set(musicVolume, forKey: Keys.music) } }
    /// Volumen de los efectos (0…1).
    var effectsVolume: Double { didSet { defaults.set(effectsVolume, forKey: Keys.effects) } }
    /// Zoom de la escena: más zoom = píxeles más grandes, menos montaña a la vista.
    var pixelZoom: Double { didSet { defaults.set(pixelZoom, forKey: Keys.zoom) } }
    /// Abrir el juego en pantalla completa.
    var startFullScreen: Bool { didSet { defaults.set(startFullScreen, forKey: Keys.fullScreen) } }
    /// Mientras los Ajustes esperan una tecla, el juego no debe recibirla.
    @ObservationIgnored var isCapturingKey = false

    var keyBindings: KeyBindings {
        didSet {
            if let data = try? JSONEncoder().encode(keyBindings) {
                defaults.set(data, forKey: Keys.bindings)
            }
        }
    }

    private enum Keys {
        static let music = "musicVolume"
        static let effects = "effectsVolume"
        static let zoom = "pixelZoom"
        static let fullScreen = "startFullScreen"
        static let bindings = "keyBindings"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        musicVolume = defaults.object(forKey: Keys.music) as? Double ?? 0.7
        effectsVolume = defaults.object(forKey: Keys.effects) as? Double ?? 0.8
        let zoom = defaults.object(forKey: Keys.zoom) as? Double ?? 1
        pixelZoom = Self.pixelZooms.contains(zoom) ? zoom : 1
        startFullScreen = defaults.bool(forKey: Keys.fullScreen)
        keyBindings = defaults.data(forKey: Keys.bindings)
            .flatMap { try? JSONDecoder().decode(KeyBindings.self, from: $0) } ?? .defaults
    }

    func resetKeyBindings() {
        keyBindings = .defaults
    }
}
