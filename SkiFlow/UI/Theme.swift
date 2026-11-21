import SwiftUI

/// Colores y estilos comunes de la interfaz, a juego con el icono.
enum Theme {
    static let skyTop = Color(red: 0.05, green: 0.32, blue: 0.75)
    static let skyBottom = Color(red: 0.62, green: 0.84, blue: 1.0)
    static let snow = Color(red: 0.97, green: 0.98, blue: 1.0)
    static let ink = Color(red: 0.10, green: 0.16, blue: 0.30)
    static let jacketRed = Color(red: 0.89, green: 0.12, blue: 0.13)
    static let lime = Color(red: 0.72, green: 0.95, blue: 0.10)
    static let alert = Color(red: 0.80, green: 0.10, blue: 0.10)

    static let sky = LinearGradient(colors: [skyTop, skyBottom], startPoint: .top, endPoint: .bottom)
}

/// Tarjeta oscura semitransparente para pausa y resultados.
struct OverlayCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) { content }
                .padding(32)
                .frame(maxWidth: 520)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(radius: 24)
        }
    }
}

/// Botón ancho de los menús.
struct MenuButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(prominent ? Theme.jacketRed : Color.primary.opacity(0.08))
            )
            .foregroundStyle(prominent ? .white : .primary)
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
