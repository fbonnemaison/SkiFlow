import SwiftUI

/// HUD encima de la partida: datos del modo, avisos y turbo.
struct HUDView: View {
    let hud: HUDSnapshot
    /// Fondo oscuro sólido y texto blanco (Ajustes › Accesibilidad).
    var highContrast = false

    private var labelColor: Color { highContrast ? .white.opacity(0.85) : Theme.ink.opacity(0.6) }
    private var valueColor: Color { highContrast ? .white : Theme.ink }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 18) {
                Text(hud.mode.displayName)
                    .font(.pixel(16))
                    .foregroundStyle(highContrast ? Theme.lime : Theme.jacketRed)
                ForEach(hud.items) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        // Sin mayúsculas: la fuente pixel no tiene vocales acentuadas mayúsculas.
                        Text(item.label)
                            .font(.pixel(8))
                            .foregroundStyle(labelColor)
                        Text(item.value)
                            .font(.pixel(16))
                            .foregroundStyle(valueColor)
                    }
                    .accessibilityElement(children: .combine)
                }
                if hud.isTurbo {
                    Text("TURBO")
                        .font(.pixel(8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.lime, in: Capsule())
                        .foregroundStyle(Theme.ink)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                if highContrast {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.88))
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial)
                }
            }

            if let alert = hud.alert {
                Label(alert, systemImage: "exclamationmark.triangle.fill")
                    .font(.pixel(16))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(highContrast ? Color.black : Theme.alert, in: Capsule())
                    .overlay {
                        if highContrast { Capsule().strokeBorder(Theme.alert, lineWidth: 3) }
                    }
                    .transition(.opacity)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.2), value: hud.alert)
    }
}

/// Menú de pausa.
struct PauseView: View {
    @Environment(GameModel.self) private var model

    var body: some View {
        OverlayCard {
            Text("Pausa")
                .font(.pixel(32))
            Text("Semilla de esta montaña: \(String(model.currentSeed))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            VStack(spacing: 10) {
                Button("Seguir (Esc)") { model.resume() }
                    .buttonStyle(MenuButtonStyle(prominent: true))
                    .keyboardShortcut(.defaultAction)
                Button("Reiniciar bajada (R)") { model.restartRun() }
                    .buttonStyle(MenuButtonStyle())
                SettingsLink { Text("Ajustes…") }
                    .buttonStyle(MenuButtonStyle())
                Button("Menú principal") { model.backToMenu() }
                    .buttonStyle(MenuButtonStyle())
            }
        }
    }
}

/// Pantalla de resultado al terminar una bajada.
struct ResultView: View {
    @Environment(GameModel.self) private var model
    let outcome: RunOutcome

    var body: some View {
        OverlayCard {
            Text(outcome.title)
                .font(.pixel(24))
                .multilineTextAlignment(.center)
            Text(outcome.summary)
                .font(.system(.title3, design: .rounded))
                .multilineTextAlignment(.center)

            if model.isNewBest {
                Label("¡Nuevo récord!", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.lime, in: Capsule())
            } else if let rank = model.lastRank {
                Label("Puesto \(rank) de tu top 10", systemImage: "list.number")
                    .font(.headline)
            } else if let best = model.best(for: model.selectedMode) {
                Text("Récord: \(best)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                if model.selectedMode.hasFinish {
                    Button("Repetir esta montaña (R)") { model.restartRun() }
                        .buttonStyle(MenuButtonStyle(prominent: true))
                        .keyboardShortcut(.defaultAction)
                    Button("Montaña nueva") { model.newMountain() }
                        .buttonStyle(MenuButtonStyle())
                } else {
                    Button("Otra bajada (R)") { model.restartRun() }
                        .buttonStyle(MenuButtonStyle(prominent: true))
                        .keyboardShortcut(.defaultAction)
                }
                Button("Menú principal") { model.backToMenu() }
                    .buttonStyle(MenuButtonStyle())
            }
        }
    }
}
