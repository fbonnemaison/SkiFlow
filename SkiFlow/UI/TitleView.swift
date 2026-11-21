import AppKit
import SwiftUI

/// Pantalla de título y menú principal con el selector de modo.
struct TitleView: View {
    @Environment(GameModel.self) private var model

    var body: some View {
        @Bindable var model = model

        ZStack {
            Theme.sky.ignoresSafeArea()
            MountainsShape()
                .fill(Theme.snow)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                header
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                    ForEach(GameMode.allCases) { mode in
                        ModeCard(
                            mode: mode,
                            isSelected: model.selectedMode == mode,
                            best: model.best(for: mode)
                        ) {
                            model.start(mode)
                        }
                    }
                }
                .frame(maxWidth: 980)

                HStack(spacing: 12) {
                    TextField("Semilla (opcional)", text: $model.seedText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .help("Escribe un número para repetir una montaña concreta")
                    SettingsLink {
                        Label("Ajustes", systemImage: "gearshape")
                    }
                    Button {
                        NSApp.terminate(nil)
                    } label: {
                        Label("Salir", systemImage: "xmark.circle")
                    }
                }
                .controlSize(.large)

                Text("Haz clic en un modo o pulsa ↩︎ · ⌘1–⌘4 desde el menú Juego")
                    .font(.callout)
                    .foregroundStyle(Theme.ink.opacity(0.7))
            }
            .padding(32)
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.none)
                .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 4) {
                Text("SkiFlow")
                    .font(.pixel(48))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                Text("El Cuico baja los Andes. El Kunk lo espera.")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }
}

/// Tarjeta de un modo de juego en el menú.
private struct ModeCard: View {
    let mode: GameMode
    let isSelected: Bool
    let best: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: mode.symbolName)
                        .font(.title2)
                        .foregroundStyle(Theme.jacketRed)
                    Text(mode.displayName)
                        .font(.system(.title3, design: .rounded).bold())
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
                Text(mode.summary)
                    .font(.callout)
                    .foregroundStyle(Theme.ink.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text(best.map { "Mejor de la sesión: \($0)" } ?? "Sin marca todavía")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.ink.opacity(0.6))
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Theme.jacketRed : .clear, lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(mode.summary))
    }
}

/// Perfil de cordillera para el fondo del menú.
private struct MountainsShape: Shape {
    func path(in rect: CGRect) -> Path {
        let peaks: [(x: CGFloat, y: CGFloat)] = [
            (0, 0.72), (0.12, 0.55), (0.22, 0.66), (0.36, 0.42), (0.48, 0.6),
            (0.6, 0.38), (0.72, 0.58), (0.84, 0.47), (0.94, 0.62), (1, 0.56),
        ]
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for peak in peaks {
            path.addLine(to: CGPoint(x: rect.minX + peak.x * rect.width, y: rect.minY + peak.y * rect.height))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

extension GameMode: Identifiable {
    var id: String { rawValue }
}
