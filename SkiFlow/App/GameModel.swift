import AppKit
import Observation

/// Estado de la app: qué pantalla se ve, el HUD, la pausa y el resultado de la
/// bajada. Hace de puente entre las vistas SwiftUI y la escena de SpriteKit.
@MainActor
@Observable
final class GameModel {
    enum Screen: Equatable {
        case title
        case playing
    }

    private(set) var screen: Screen = .title
    private(set) var hud = HUDSnapshot()
    private(set) var isPaused = false
    private(set) var outcome: RunOutcome?
    /// La bajada que acaba de terminar mejora la marca de la sesión.
    private(set) var isNewBest = false
    /// Mejores marcas de esta sesión (las guardadas llegan en la Fase 10).
    private(set) var sessionBests: [GameMode: Double] = [:]

    var selectedMode: GameMode
    /// Semilla opcional escrita en el menú para repetir una montaña concreta.
    var seedText = ""

    @ObservationIgnored let scene: GameScene
    @ObservationIgnored let settings: SettingsStore

    init(settings: SettingsStore, scene: GameScene? = nil) {
        self.settings = settings
        let scene = scene ?? GameScene(size: GameConfig.sceneSize)
        self.scene = scene
        selectedMode = scene.mode
        scene.pixelZoom = CGFloat(settings.pixelZoom)

        scene.onHUDChange = { [weak self] hud in self?.hud = hud }
        scene.onPauseChange = { [weak self] paused in self?.isPaused = paused }
        scene.onRunEnded = { [weak self] outcome in self?.runEnded(outcome) }
        scene.onRunStarted = { [weak self] mode in self?.runStarted(mode) }
        hud = scene.makeHUD()
    }

    /// Semilla escrita en el menú, si es un número válido.
    var parsedSeed: UInt64? {
        UInt64(seedText.trimmingCharacters(in: .whitespaces))
    }

    /// Semilla de la montaña actual (para poder apuntarla y repetirla).
    var currentSeed: UInt64 { scene.seed }

    // MARK: Acciones

    func start(_ mode: GameMode) {
        selectedMode = mode
        scene.pixelZoom = CGFloat(settings.pixelZoom)
        scene.restart(mode: mode, seed: parsedSeed)
        screen = .playing
    }

    /// Repite la bajada: misma montaña en los modos con meta, nueva en Descenso libre.
    func restartRun() {
        guard screen == .playing else { return }
        scene.restart()
    }

    /// Estrena montaña en el mismo modo.
    func newMountain() {
        guard screen == .playing else { return }
        scene.restart(mode: scene.mode)
    }

    func togglePause() {
        guard screen == .playing, outcome == nil else { return }
        scene.setPaused(!scene.isGamePaused)
    }

    func resume() {
        scene.setPaused(false)
    }

    func pauseIfPlaying() {
        guard screen == .playing, outcome == nil, !scene.isGamePaused else { return }
        scene.releaseAllInput()
        scene.setPaused(true)
    }

    func backToMenu() {
        scene.releaseAllInput()
        if !scene.isGamePaused { scene.setPaused(true) }
        outcome = nil
        isNewBest = false
        screen = .title
    }

    func best(for mode: GameMode) -> String? {
        sessionBests[mode].map(mode.formatRecord)
    }

    // MARK: Entrada

    /// Traduce una tecla según la asignación de los Ajustes. Devuelve `true` si el
    /// juego la usó (y no debe llegar a nadie más).
    ///
    /// Las repeticiones automáticas se tragan (para que no pite) pero no se
    /// reenvían: el juego gestiona su propia repetición de giro.
    func handleKey(_ keyCode: UInt16, pressed: Bool, isRepeat: Bool = false, window: NSWindow?) -> Bool {
        guard !settings.isCapturingKey else { return false }

        switch screen {
        case .title:
            // ↩︎ empieza el modo elegido.
            guard keyCode == 36, pressed, !isRepeat, window?.isKeyWindow ?? true else { return false }
            start(selectedMode)
            return true
        case .playing:
            guard window == nil || window === scene.view?.window,
                  let action = settings.keyBindings.action(for: keyCode)
            else { return false }
            if !isRepeat {
                scene.handle(action, pressed: pressed, source: .keyboard)
            }
            return true
        }
    }

    func handleMouseMove(windowPoint: CGPoint, window: NSWindow?) -> Bool {
        guard screen == .playing, outcome == nil, !isPaused else { return false }
        return scene.aimMouse(windowPoint: windowPoint, window: window)
    }

    func handleMouseButton(pressed: Bool) {
        guard screen == .playing, outcome == nil, !isPaused else {
            if !pressed { scene.handle(.jump, pressed: false, source: .mouse) }
            return
        }
        scene.handle(.jump, pressed: pressed, source: .mouse)
    }

    // MARK: Avisos de la escena

    private func runStarted(_ mode: GameMode) {
        selectedMode = mode
        outcome = nil
        isNewBest = false
    }

    private func runEnded(_ outcome: RunOutcome) {
        self.outcome = outcome
        let mode = scene.mode
        guard let value = outcome.recordValue(in: mode) else {
            isNewBest = false
            return
        }
        isNewBest = mode.isBetter(value, than: sessionBests[mode])
        if isNewBest { sessionBests[mode] = value }
    }
}
