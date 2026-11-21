import AppKit
import SwiftUI

/// Ventana de Ajustes (⌘,).
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            ControlsSettingsView()
                .tabItem { Label("Controles", systemImage: "keyboard") }
        }
        .frame(width: 520)
        .padding(20)
    }
}

private struct GeneralSettingsView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Sonido") {
                Slider(value: $settings.musicVolume, in: 0...1) { Text("Música") }
                Slider(value: $settings.effectsVolume, in: 0...1) { Text("Efectos") }
                Text("El audio llegará en una próxima versión; el volumen elegido se guarda.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Pantalla") {
                Picker("Escala de píxel", selection: $settings.pixelZoom) {
                    Text("Normal").tag(1.0)
                    Text("Grande").tag(1.25)
                    Text("Muy grande").tag(1.5)
                }
                Toggle("Abrir en pantalla completa", isOn: $settings.startFullScreen)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ControlsSettingsView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Acción").font(.headline)
                    Text("Tecla 1").font(.headline)
                    Text("Tecla 2").font(.headline)
                }
                Divider()
                ForEach(InputAction.rebindable, id: \.self) { action in
                    GridRow {
                        Text(action.displayName)
                        ForEach(0..<KeyBindings.slotsPerAction, id: \.self) { slot in
                            KeyCaptureButton(action: action, slot: slot)
                        }
                    }
                }
            }

            HStack {
                Button("Restaurar teclas por defecto") { settings.resetKeyBindings() }
                Spacer()
            }

            Text("Haz clic en una tecla y pulsa la nueva (Esc cancela, ⌫ la borra). Ratón: el Cuico apunta al cursor y el clic brinca. Mando: stick o cruceta, A brinca, B frena, X o gatillo derecho turbo, Menú pausa.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Botón que muestra una tecla asignada y, al pulsarlo, espera una nueva.
private struct KeyCaptureButton: View {
    @Environment(SettingsStore.self) private var settings
    let action: InputAction
    let slot: Int

    @State private var isCapturing = false
    @State private var monitor: Any?

    var body: some View {
        let codes = settings.keyBindings.keyCodes(for: action)
        let label = slot < codes.count ? KeyName.name(for: codes[slot]) : "—"

        Button(isCapturing ? "Pulsa una tecla…" : label) {
            isCapturing ? stopCapture() : startCapture()
        }
        .frame(minWidth: 120)
        .accessibilityLabel(Text("\(action.displayName), tecla \(slot + 1): \(label)"))
        .onDisappear {
            if isCapturing { stopCapture() }
        }
    }

    private func startCapture() {
        isCapturing = true
        settings.isCapturingKey = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = event.keyCode
            MainActor.assumeIsolated {
                switch keyCode {
                case 53: break // Esc: cancelar
                case 51: settings.keyBindings.clear(action, slot: slot) // ⌫: borrar
                default: settings.keyBindings.assign(keyCode, to: action, slot: slot)
                }
                stopCapture()
            }
            return nil
        }
    }

    private func stopCapture() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isCapturing = false
        settings.isCapturingKey = false
    }
}
