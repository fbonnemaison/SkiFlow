# SkiFlow — Plan de desarrollo

Juego de esquí 2D para **macOS 26 o superior**, escrito en **Swift**, inspirado en el clásico *SkiFree* (1991). SkiFlow toma la idea (bajar una montaña esquivando obstáculos mientras algo te persigue), pero el arte, los personajes, los nombres y los sonidos son propios. La acción transcurre en la **cordillera de los Andes**. El protagonista es **el Cuico**, y los perseguidores son el **Kunk**, equivalente sudamericano del Yeti, y el **Chupacabras**.

Autor: **App-Zilla** · Licencia: **MIT**

---

## Decisiones tomadas

| Tema | Decisión |
|---|---|
| Plataforma | macOS 26+, Xcode 27, Swift 6 (concurrencia estricta) |
| Motor | **SpriteKit** para la escena de juego + **SwiftUI** para menús, HUD y ajustes |
| Estilo visual | Pixel art retro, con **packs CC0** adaptados (sin gráficos de SkiFree) |
| Modos | Descenso libre (sin fin), Slalom contrarreloj, Slalom entre árboles, Freestyle |
| Controles | Teclado, ratón/trackpad (apuntar con el cursor) y mando (GameController) |
| Ambientación | **Cordillera de los Andes**: flora, fauna, clima y cultura andinos |
| Protagonista | **El Cuico**: típico chileno que va a la nieve más a posar que a esquiar (descripción provisional, se mejora en la Fase 11) |
| Perseguidor principal | **Kunk**, equivalente sudamericano del Yeti: aparece de forma habitual en Descenso libre |
| Perseguidor secundario | **Chupacabras**: aparición **rara**, mucho menos frecuente que el Kunk, con un comportamiento distinto |
| Evento de presión | **Avalancha** en los modos Slalom y Freestyle |
| Montaña | Generación procedural por trozos con **semilla** (los trazados de slalom se pueden reproducir) |
| Récords | Solo locales (SwiftData). Sin Game Center ni iCloud, porque requieren cuenta de pago |
| Audio | Efectos de sonido + música chiptune (CC0 o generada) |
| Idioma | Solo español (String Catalog preparado por si se traduce más adelante) |
| Distribución | DMG firmado ad hoc en GitHub Releases. Sin notarización, Developer ID ni App Store |
| Calidad | Swift Testing para la lógica + CI en GitHub Actions (compila, testea y genera el DMG) |

---

## Fase 0 — Cimientos del proyecto ✅
- [x] `git init`, `.gitignore` (Xcode/Swift), `LICENSE` MIT © App-Zilla
- [x] Proyecto Xcode `SkiFlow` generado con **XcodeGen** (`project.yml`): app macOS con ciclo de vida SwiftUI y target mínimo macOS 26
- [x] Target de tests con Swift Testing (`SkiFlowTests`)
- [x] Firma ad hoc (`CODE_SIGN_IDENTITY = "-"`), sin equipo de desarrollo
- [x] `NSHumanReadableCopyright` = "© 2026 App-Zilla. Licencia MIT."
- [x] Estructura de carpetas: `App/`, `Game/` (escena, entidades, sistemas), `World/` (generación), `UI/`, `Audio/`, `Persistence/`, `Resources/`
- [x] `README.md` inicial: descripción, requisitos y cómo abrir la app sin notarizar (Ajustes del Sistema › Privacidad y seguridad › «Abrir igualmente»)
- [x] `CHANGELOG.md`

## Fase 1 — Prototipo jugable (núcleo del esquí) ✅
- [x] `SpriteView` dentro de una ventana SwiftUI con una `GameScene` de SpriteKit
- [x] Bucle de juego con `update(_:)` y paso de tiempo fijo (1/120 s) para la física (`FixedTimestep`)
- [x] El Cuico (esquiador protagonista) con **9 posiciones** (atravesado a la izquierda, 3 inclinaciones por lado, recto abajo, atravesado a la derecha) y velocidad según el ángulo
- [x] Física propia sencilla: aceleración en pendiente, rozamiento con velocidad terminal y frenada derrapando con los esquís atravesados (`SkierPhysics`)
- [x] Cámara que sigue al Cuico, adelantada para ver más montaña por delante
- [x] Controles por teclado (flechas/WASD, R para reiniciar) con giro repetido al mantener la tecla
- [x] Sprites provisionales (formas de colores): el Cuico con parka fucsia y lentes de sol, huellas de esquí y motas de nieve
- [x] Indicador de depuración de velocidad (km/h) y distancia (m)
- [x] Tests: direcciones, física, paso fijo, control de giro, teclas y escena

## Fase 2 — Mundo procedural y obstáculos
- [ ] Generador por **trozos** (chunks) con RNG con semilla (determinista y testeable); el RNG `SeededRandom` ya existe
- [ ] Obstáculos estáticos andinos: queñuas, araucarias, rocas, cactus de altura, apachetas (montículos de piedras), penitentes de hielo, refugios de montaña
- [ ] Obstáculos móviles: llamas, guanacos y vicuñas, perros de refugio, otros esquiadores y telesilla
- [ ] Cóndores en vuelo como elemento decorativo (sombra en la nieve) u obstáculo en los saltos
- [ ] Rampas (saltos) y zonas de hielo, nieve profunda y *viento blanco*
- [ ] Bandas de altitud: más vegetación en la parte baja y más hielo y roca en la alta
- [ ] Colisiones con hitboxes ajustadas (solo la base de los objetos altos)
- [ ] Caída del Cuico: animación, tiempo de recuperación, pérdida de velocidad
- [ ] Reciclado de nodos / descarga de trozos fuera de pantalla (rendimiento)
- [ ] Ajuste de densidad y dificultad según la distancia recorrida
- [ ] Tests: misma semilla = mismo mundo; distribución de obstáculos; colisiones

## Fase 3 — Controles completos
- [ ] Ratón/trackpad: el esquiador apunta hacia el cursor; clic para saltar
- [ ] Mando con GameController (stick, botones, conexión y desconexión en caliente)
- [ ] Acciones comunes: saltar, **turbo** (modo rápido), pausa
- [ ] Capa de entrada abstracta (`InputState`) que unifica los tres dispositivos
- [ ] Reasignación de teclas en Ajustes (opcional dentro de esta fase)

## Fase 4 — Modo Descenso libre y perseguidores
- [ ] Contador de distancia y velocidad en el HUD
- [ ] Protocolo común `Chaser` (aparición, persecución, captura) que comparten las dos criaturas

### Kunk (perseguidor principal)
- [ ] Diseño propio del Kunk: aspecto, animaciones (correr, rugir, atrapar) y ficha de personaje
- [ ] Aparición segura a partir de una distancia configurable (por ejemplo, 2.000 m)
- [ ] IA de persecución: velocidad superior a la normal e inferior al turbo; aceleración progresiva
- [ ] Posibilidad de escapar con el turbo y riesgo de chocar al ir tan rápido
- [ ] Secuencia de captura y pantalla de fin de partida

### Chupacabras (perseguidor raro)
- [ ] Diseño propio del Chupacabras: aspecto y animaciones (acecho, salto, captura)
- [ ] Aparición **poco frecuente** y aleatoria (con semilla), muy por debajo de la del Kunk; por ejemplo, un 5–10 % de las partidas largas
- [ ] Comportamiento distinto del Kunk: emboscada lateral desde rocas o vegetación, *sprint* corto muy rápido y retirada si no te alcanza
- [ ] Aviso previo (sonido o sombra) para que se pueda esquivar
- [ ] Decidir si también aparece en otros modos como sorpresa
- [ ] Contador en las estadísticas de encuentros con el Chupacabras

- [ ] Tests: lógica de aparición (incluida la frecuencia del Chupacabras con semilla fija) y persecución

## Fase 5 — Modos Slalom
- [ ] Banderas/puertas generadas por semilla con trazado reproducible
- [ ] Detección de puerta superada o fallada (lado correcto)
- [ ] Cronómetro, penalización por puerta fallada y meta
- [ ] **Slalom contrarreloj**: trazado abierto con pocos obstáculos
- [ ] **Slalom entre árboles**: misma lógica con bosque denso
- [ ] **Avalancha** como evento de presión si vas demasiado lento
- [ ] Tests: puertas, penalizaciones y tiempos

## Fase 6 — Modo Freestyle
- [ ] Rampas y saltos con tiempo en el aire según la velocidad
- [ ] Trucos en el aire (combinaciones de teclas o botones): giros, mortales, *grabs*
- [ ] Sistema de puntos con multiplicador de combo
- [ ] Aterrizaje: limpio, forzado o caída (que anula los puntos)
- [ ] Avalancha como límite de tiempo o de recorrido
- [ ] Tests: puntuación y combos

## Fase 7 — Interfaz y flujo de juego
- [ ] Pantalla de título y menú principal (SwiftUI)
- [ ] Selector de modo (y semilla opcional para slalom)
- [ ] HUD superpuesto: tiempo, distancia, velocidad, puntos y puertas
- [ ] Pausa (Esc/P/botón Menú) y reanudar
- [ ] Pantalla de resultados con récord personal
- [ ] Ajustes: volumen, controles, pantalla completa y escala de píxel
- [ ] Menús de la barra de macOS y atajos estándar (⌘F pantalla completa, ⌘Q)
- [ ] Textos en String Catalog (español)

## Fase 8 — Arte pixel art (packs CC0)
- [ ] Elegir y documentar los packs CC0 (fuente, autor y licencia en `CREDITS.md`)
- [ ] Definir la escala base (por ejemplo, sprites de 16×16/32×32) con filtrado `nearest`
- [ ] Paleta andina: nieve y hielo de altura, roca volcánica, verdes de queñua y araucaria, cielo de alta montaña
- [ ] Diseño del Cuico: equipo de marca reluciente, lentes de sol y pose de foto; animaciones propias (posar, *selfie* al detenerse, caída indignada)
- [ ] Atlas de texturas (`.spriteatlas`) para el Cuico, los obstáculos andinos, el Kunk, el Chupacabras, las banderas y la avalancha
- [ ] Adaptar o dibujar los sprites que no existan en packs CC0 (Kunk, Chupacabras, llamas, cóndores, apachetas, penitentes)
- [ ] Animaciones: 9 posiciones, caída, salto, trucos, Kunk, Chupacabras y avalancha
- [ ] Partículas de nieve (estela de esquís, choques, avalancha, viento blanco)
- [ ] Icono de la app (`AppIcon`) y fuente pixel con licencia libre

## Fase 9 — Audio
- [ ] Efectos: deslizar, girar, choque, salto, aterrizaje, puerta, quejas del Cuico al caer, rugido del Kunk, chillido del Chupacabras, viento y avalancha
- [ ] Música chiptune con aire andino (timbres que evocan quena, charango y bombo): menú, partida y persecución
- [ ] Temas de persecución distintos para el Kunk y para el Chupacabras
- [ ] Gestor de audio (`AVAudioEngine` o `SKAudioNode`) con mezcla y volúmenes
- [ ] Créditos de audio en `CREDITS.md`

## Fase 10 — Persistencia y récords
- [ ] Modelo SwiftData: récords por modo (distancia, tiempo y puntos), fecha y semilla
- [ ] Tabla de mejores marcas por modo (top 10 local)
- [ ] Estadísticas: partidas, metros totales, capturas del Kunk y encuentros con el Chupacabras
- [ ] Persistencia de ajustes (`@AppStorage`)
- [ ] Tests: guardado y ordenación de récords

## Fase 11 — Pulido y equilibrio
- [ ] Ajuste fino de la física, la dificultad y la persecución
- [ ] *Screen shake*, *hit-stop* y otros detalles de respuesta al jugador
- [ ] Rendimiento: 60/120 fps estables (ProMotion) y uso de memoria con mundo infinito
- [ ] Accesibilidad: reducir movimiento, alto contraste en el HUD y reasignación de controles
- [ ] Mejorar la descripción y personalidad del Cuico (texto definitivo, frases y gestos) y reflejarla en el arte y los textos
- [ ] Easter eggs propios
- [ ] Partidas de prueba y lista de errores

## Fase 12 — CI y distribución
- [ ] GitHub Actions: compilar y ejecutar tests en cada push/PR (runner macOS)
- [ ] Workflow de release: compilar en Release, firmar ad hoc y crear el DMG (`hdiutil`)
- [ ] Publicar el DMG en GitHub Releases al crear una etiqueta `vX.Y.Z`
- [ ] README final: capturas, controles, modos, instalación y cómo abrir la app sin notarizar
- [ ] `CHANGELOG.md` actualizado y primera versión `v1.0.0`

---

## Ideas para después de la 1.0
- Traducción al inglés (el String Catalog ya estará preparado)
- Repetición de la mejor bajada (*ghost*)
- Reto diario con semilla compartida
- Editor de pistas
- Montañas andinas con nombre (Aconcagua, Ojos del Salado, Chimborazo…) como escenarios temáticos
