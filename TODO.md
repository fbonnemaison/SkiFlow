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
- [x] Sprites provisionales (formas de colores): el Cuico con la estética del icono (parka roja, casco y braga negros, antiparras espejadas, esquís negros con cantos verde lima), huellas de esquí y motas de nieve
- [x] Indicador de depuración de velocidad (km/h) y distancia (m)
- [x] Tests: direcciones, física, paso fijo, control de giro, teclas y escena

## Fase 2 — Mundo procedural y obstáculos ✅
- [x] Generador por **trozos** (chunks) de 768 pt con RNG con semilla (`MountainGenerator`, determinista y testeable); salida despejada
- [x] Obstáculos estáticos andinos: queñuas, araucarias, rocas, piedras, cactus de altura, apachetas, penitentes de hielo, refugios de montaña
- [x] Obstáculos móviles: llamas, guanacos y vicuñas que pastan de lado a lado, perros de refugio, otros esquiadores bajando en eses
- [x] Telesilla: columna de torres a lo largo de la montaña, cable y sillas en movimiento
- [x] Cóndores en vuelo con su sombra en la nieve; solo se chocan en pleno salto
- [x] Rampas (saltos más largos cuanto más rápido), zonas de hielo (cuesta frenar), nieve profunda (frena) y *viento blanco* (empuja de lado y tapa la vista)
- [x] Bandas de altitud: alta montaña (roca, hielo, penitentes, vicuñas) → puna (cactus, llamas, guanacos) → bosque andino (araucarias, queñuas)
- [x] Colisiones con cajas ajustadas a la base de los objetos; en el aire solo chocan los objetos altos (`CollisionResolver`)
- [x] Caída del Cuico (1,2 s en el suelo, velocidad a cero, se levanta atravesado con unos instantes de inmunidad) y tropiezo con piedras pequeñas (pierde velocidad sin caer)
- [x] Carga y descarga de trozos alrededor de la cámara (`MountainNode`) y texturas cacheadas
- [x] Más objetos por trozo según la distancia recorrida (de ~8 a ~22)
- [x] Sprites pixel art provisionales generados por código (`PixelArt`, `ObstacleArt`)
- [x] Tests: misma semilla = mismo mundo; salida despejada; separación y densidad; bandas; movimientos; reglas de choque; superficies, viento y saltos

## Fase 3 — Controles completos ✅
- [x] Ratón/trackpad: el Cuico gira paso a paso hacia el cursor (cursor por encima = frenar); clic para brincar
- [x] Mando con GameController: stick para apuntar, cruceta, botones; se consulta cada fotograma, así que funciona conectado y desconectado en caliente (con aviso en pantalla)
- [x] Acciones comunes: brincar (Espacio / clic / A), **turbo** mantenido (F / X / gatillo derecho), pausa (Esc / P / Menú, y automática al cambiar de app)
- [x] Capa de entrada común (`InputState`): cada dispositivo guarda sus propias pulsaciones; el stick manda sobre el ratón y las teclas desactivan el apuntado con ratón
- [x] Tests: apuntado, flancos de pulsación por dispositivo, transiciones del mando, brinco, turbo, pausa y ratón
- [ ] Reasignación de teclas → se hace junto a los Ajustes en la Fase 7

## Fase 4 — Modo Descenso libre y perseguidores ✅
- [x] HUD con distancia, velocidad, tiempo, caídas, turbo y avisos de persecución
- [x] Protocolo común `Chaser` (aparición, persecución, captura) que comparten las dos criaturas
- [x] Modo `freeDescent`, secuencia de captura (1,8 s) y pantalla de fin de partida con resumen

### Kunk (perseguidor principal)
- [x] Diseño provisional propio del Kunk: mole peluda pardo-gris de ojos rojos, animación de carrera y de captura (arte final en la Fase 8)
- [x] Aparición segura a los 2.000 m, por encima del Cuico y fuera de pantalla
- [x] IA de persecución: empieza a 430 pt/s y acelera hasta 650 (más que el Cuico normal, menos que con turbo); atraviesa los obstáculos y recorta distancia si se queda muy atrás
- [x] Se escapa con el turbo, con el riesgo de chocar al ir tan rápido
- [x] Secuencia de captura y pantalla de fin de partida

### Chupacabras (perseguidor raro)
- [x] Diseño provisional propio del Chupacabras: bicho reptiliano gris verdoso con púas, animación de carrera
- [x] Aparición **poco frecuente** decidida con la semilla de la bajada: 8 % de las partidas, entre los 800 y los 3.000 m
- [x] Comportamiento distinto del Kunk: acecha a un lado, embiste en línea recta hacia donde va a estar el Cuico y se esfuma si falla
- [x] Aviso previo de 1,3 s en pantalla; **saltar por encima lo esquiva**
- [x] Solo aparece en Descenso libre (decidido en las Fases 5 y 6)
- [x] Contador de encuentros en la partida (las estadísticas guardadas llegan en la Fase 10)

- [x] Ajustes para probar al lanzar la app: `-kunkSpawnMeters`, `-chupacabrasChance`, `-chupacabrasMeters`
- [x] Tests: aparición, persecución, escape con turbo, frecuencia del Chupacabras con semillas fijas, esquive saltando y fin de partida

## Fase 5 — Modos Slalom ✅
- [x] Puertas generadas por semilla con trazado reproducible (`SlalomCourse`): 20 puertas en zigzag, rojas y azules alternas
- [x] Detección de puerta superada o fallada al cruzar su línea (con interpolación, `SlalomProgress`)
- [x] Cronómetro con décimas, penalización de 5 s por puerta fallada, línea de meta y pantalla de resultado
- [x] **Slalom contrarreloj**: pista abierta con pocos obstáculos de alta montaña (perfil `slalom` del generador)
- [x] **Slalom entre árboles**: misma lógica en un bosque denso de araucarias y queñuas (perfil `treeSlalom`)
- [x] El generador deja libres las puertas y la meta; sin telesilla en los modos de slalom
- [x] **Avalancha** como evento de presión: se suelta a los 2,5 s y acelera hasta 320 pt/s; sepulta a quien se para o se cae demasiado
- [x] R repite el mismo trazado para mejorar el tiempo; teclas 1/2/3 cambian de modo (provisional hasta el menú de la Fase 7) y `-mode slalom` al lanzar
- [x] El Kunk y el Chupacabras no aparecen en slalom, para que las contrarrelojes sean justas
- [x] Tests: trazado reproducible, puertas despejadas, densidad por perfil, pasar/fallar/meta, avalancha y un "piloto" simulado que termina el slalom por delante de la avalancha

## Fase 6 — Modo Freestyle ✅
- [x] Montaña con muchas rampas (perfil `freestyle`) y saltos un 50 % más largos para que quepan los trucos
- [x] Trucos en el aire (en freestyle, las teclas de giro y salto hacen trucos): giro 360 (←/→, 100), mortal adelante (↓, 150), mortal atrás (↑, 150) y **selfie** (Espacio, 50) con flash
- [x] Sistema de puntos: varios trucos en un salto multiplican (×1, ×1,5, ×2…) y cada aterrizaje limpio sube la racha (hasta ×4)
- [x] Aterrizaje limpio, forzado (justo al terminar el truco o con los esquís atravesados: medio premio y se corta la racha) o caída (a mitad de truco o chocando en el aire: se pierden los puntos del salto)
- [x] Meta a los 1.000 m con la avalancha detrás; pantalla de fin con puntos, mejor salto y trucos; R repite la montaña y 4 estrena otra
- [x] El Kunk y el Chupacabras tampoco aparecen en freestyle
- [x] Tests: trucos, combos, racha, tipos de aterrizaje, perfil de rampas, saltos más largos y escena (giro en el aire y caída a mitad de mortal)

## Fase 7 — Interfaz y flujo de juego
- [ ] Pantalla de título y menú principal (SwiftUI)
- [ ] Selector de modo (y semilla opcional para slalom)
- [ ] HUD superpuesto: tiempo, distancia, velocidad, puntos y puertas
- [ ] Pausa (Esc/P/botón Menú) y reanudar
- [ ] Pantalla de resultados con récord personal
- [ ] Ajustes: volumen, controles (incluida la reasignación de teclas), pantalla completa y escala de píxel
- [ ] Menús de la barra de macOS y atajos estándar (⌘F pantalla completa, ⌘Q)
- [ ] Textos en String Catalog (español)

## Fase 8 — Arte pixel art (packs CC0)
- [ ] Elegir y documentar los packs CC0 (fuente, autor y licencia en `CREDITS.md`)
- [ ] Definir la escala base (por ejemplo, sprites de 16×16/32×32) con filtrado `nearest`
- [ ] Paleta andina: nieve y hielo de altura, roca volcánica, verdes de queñua y araucaria, cielo de alta montaña
- [ ] Diseño del Cuico basado en el icono (parka roja, casco negro, antiparras espejadas con marco rojo, esquís negros con cantos verde lima), con equipo de marca reluciente y pose de foto; animaciones propias (posar, *selfie* al detenerse, caída indignada)
- [ ] Atlas de texturas (`.spriteatlas`) para el Cuico, los obstáculos andinos, el Kunk, el Chupacabras, las banderas y la avalancha
- [ ] Adaptar o dibujar los sprites que no existan en packs CC0 (Kunk, Chupacabras, llamas, cóndores, apachetas, penitentes)
- [ ] Animaciones: 9 posiciones, caída, salto, trucos, Kunk, Chupacabras y avalancha
- [ ] Partículas de nieve (estela de esquís, choques, avalancha, viento blanco)
- [x] Icono de la app (`AppIcon`): esquiador pixel art con antiparras frente a los Andes (original en `Design/AppIcon-source.png`)
- [ ] Fuente pixel con licencia libre

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
