import AppKit
import SwiftUI

@main
struct SkiFlowApp: App {
    @State private var settings: SettingsStore
    @State private var model: GameModel

    init() {
        PixelFont.register()
        let settings = SettingsStore()
        // En los tests la app hace de anfitriona: allí no debe sonar nada.
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let audio = isTesting ? nil : AudioManager(musicVolume: settings.musicVolume, effectsVolume: settings.effectsVolume)
        // Récords en disco (en memoria durante los tests). Si falla, se juega sin guardar.
        let records = (try? RecordStore.makeContainer(inMemory: isTesting)).map { RecordStore(container: $0) }
        _settings = State(initialValue: settings)
        _model = State(initialValue: GameModel(settings: settings, audio: audio, records: records))
    }

    var body: some Scene {
        // Una sola ventana de juego.
        Window("SkiFlow", id: "main") {
            ContentView()
                .environment(model)
                .environment(settings)
        }
        .defaultSize(width: GameConfig.sceneSize.width, height: GameConfig.sceneSize.height)
        .commands {
            GameCommands(model: model)
        }

        Settings {
            SettingsView()
                .environment(settings)
        }
    }
}

/// Menús de la barra: Archivo › Nueva bajada, menú Juego, pantalla completa y Ayuda.
private struct GameCommands: Commands {
    let model: GameModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Nueva bajada") {
                if model.screen == .playing {
                    model.newMountain()
                } else {
                    model.start(model.selectedMode)
                }
            }
            .keyboardShortcut("n")
        }
        // ⌘P es la pausa: fuera la impresión.
        CommandGroup(replacing: .printItem) {}

        CommandMenu("Juego") {
            Button(model.isPaused ? "Seguir" : "Pausa") { model.togglePause() }
                .keyboardShortcut("p")
                .disabled(model.screen != .playing || model.outcome != nil)
            Button("Reiniciar bajada") { model.restartRun() }
                .keyboardShortcut("r")
                .disabled(model.screen != .playing)
            Divider()
            ForEach(Array(GameMode.allCases.enumerated()), id: \.element) { index, mode in
                Button(mode.displayName) { model.start(mode) }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))))
            }
            Divider()
            Button("Menú principal") { model.backToMenu() }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .disabled(model.screen == .title)
        }

        // Menú Ayuda: abre la wiki de GitHub en el navegador.
        CommandGroup(replacing: .help) {
            Button("Ayuda de SkiFlow") { NSWorkspace.shared.open(HelpLinks.wiki) }
                .keyboardShortcut("?")
            Divider()
            Button("Controles") { NSWorkspace.shared.open(HelpLinks.controls) }
            Button("Modos de juego") { NSWorkspace.shared.open(HelpLinks.modes) }
            Button("La montaña") { NSWorkspace.shared.open(HelpLinks.mountain) }
            Button("Rivales y criaturas") { NSWorkspace.shared.open(HelpLinks.creatures) }
            Button("Preguntas frecuentes") { NSWorkspace.shared.open(HelpLinks.faq) }
            Divider()
            Button("Novedades y descargas") { NSWorkspace.shared.open(HelpLinks.releases) }
            Button("Informar de un problema") { NSWorkspace.shared.open(HelpLinks.issues) }
        }

        CommandGroup(after: .toolbar) {
            Button("Pantalla completa") {
                NSApp.keyWindow?.toggleFullScreen(nil)
            }
            .keyboardShortcut("f")
        }
    }
}
