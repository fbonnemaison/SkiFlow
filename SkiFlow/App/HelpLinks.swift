import Foundation

/// Enlaces de la ayuda del juego: la wiki del proyecto en GitHub.
enum HelpLinks {
    static let repository = URL(string: "https://github.com/fbonnemaison/SkiFlow")!
    /// Portada de la wiki (la ayuda de SkiFlow).
    static let wiki = repository.appending(path: "wiki")
    static let controls = page("Controles")
    static let modes = page("Modos-de-juego")
    static let mountain = page("La-montaña")
    static let creatures = page("Rivales-y-criaturas")
    static let faq = page("Preguntas-frecuentes")
    static let releases = repository.appending(path: "releases")
    static let issues = repository.appending(path: "issues")

    /// Página de la wiki por su nombre (con guiones en vez de espacios).
    static func page(_ name: String) -> URL {
        wiki.appending(path: name)
    }
}
