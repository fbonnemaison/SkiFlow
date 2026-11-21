# Changelog

Todos los cambios relevantes de SkiFlow se documentan en este archivo.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto usa [Versionado Semántico](https://semver.org/lang/es/).

## [Sin publicar]

### Corregido
- El cronómetro mostraba una décima de menos en algunos tiempos (por ejemplo, 01:15.2 en vez de 01:15.3).

### Añadido
- Modo Freestyle (Fase 6): montaña llena de rampas, trucos en el aire (giros, mortales y el selfie del Cuico), combos, racha, tipos de aterrizaje y meta a los 1.000 m con la avalancha detrás.
- Modos Slalom y Slalom entre árboles (Fase 5): trazado de 20 puertas reproducible, penalización por puerta fallada, meta con cronómetro, avalancha que sepulta a quien va demasiado lento y teclas 1/2/3 para cambiar de modo.
- Modo Descenso libre (Fase 4): el Kunk aparece a los 2.000 m y persigue al Cuico (se escapa con turbo); el Chupacabras aparece en el 8 % de las bajadas, avisa y embiste (se esquiva saltando); HUD con distancia, velocidad y tiempo, y pantalla de fin de partida.
- Controles completos (Fase 3): ratón/trackpad para apuntar y clic para brincar, mando (GameController) con conexión en caliente, brinco, turbo y pausa (también automática al cambiar de app).
- Montaña andina infinita (Fase 2): generación por trozos con semilla, bandas de altitud, obstáculos fijos y móviles (araucarias, queñuas, penitentes, apachetas, refugios, llamas, guanacos, vicuñas, perros, esquiadores, telesilla y cóndores), rampas, hielo, nieve profunda y viento blanco; caídas, tropiezos y saltos.
- Icono de la app en pixel art (esquiador con antiparras frente a los Andes); el original está en `Design/AppIcon-source.png`.
- El Cuico provisional adopta la estética del icono: parka roja, casco y braga negros, antiparras espejadas y esquís negros con cantos verde lima.
- Prototipo jugable (Fase 1): el Cuico baja la montaña con 9 posiciones de esquí, física de paso fijo, frenada derrapando, cámara que lo sigue, huellas en la nieve y controles por teclado (flechas/WASD, R para reiniciar).
- Proyecto Xcode generado con XcodeGen (`project.yml`): app macOS 26+ en Swift 6 con SwiftUI y SpriteKit.
- Escena de SpriteKit vacía como punto de partida.
- Target de tests con Swift Testing.
- Firma ad hoc, licencia MIT, README y plan de desarrollo (`TODO.md`).
- El Cuico como protagonista (descripción provisional).
- Ambientación en la cordillera de los Andes, con el Kunk como perseguidor principal y el Chupacabras como perseguidor raro (definido en el plan).

Autor: App-Zilla
