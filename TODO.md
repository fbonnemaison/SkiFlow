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
| Distribución | DMG firmado ad hoc. Primero versión previa en repo **privado** para probar; tras aprobarla, repo **público** y `v1.0.0` en GitHub Releases. Sin notarización, Developer ID ni App Store |
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

## Fase 7 — Interfaz y flujo de juego ✅
- [x] Pantalla de título y menú principal en SwiftUI (cordillera de fondo, icono y tarjetas de modo)
- [x] Selector de modo con descripción y mejor marca de la sesión, y semilla opcional para repetir una montaña
- [x] HUD en SwiftUI encima de la partida: datos según el modo (distancia, tiempo, puertas, puntos, racha…), avisos en rojo y turbo
- [x] Pausa con menú (Seguir, Reiniciar, Ajustes, Menú principal); se pausa sola al cambiar de app o de ventana
- [x] Pantalla de resultados con la mejor marca de la sesión (la marca guardada llega en la Fase 10)
- [x] Ajustes (⌘,): volumen de música y efectos (se guarda para la Fase 9), escala de píxel, pantalla completa al abrir y **reasignación de teclas** (dos por acción)
- [x] Menús de macOS: Archivo › Nueva bajada (⌘N), menú Juego (⌘P pausa, ⌘R reiniciar, ⌘1–⌘4 modos, ⇧⌘M menú principal), Visualización › Pantalla completa (⌘F); una sola ventana
- [x] Textos de la interfaz en un String Catalog (español)
- [x] Tests: asignación de teclas, ajustes guardados, marcas por modo, modelo de pantallas/pausa/resultado y HUD
- [ ] Revisar a mano la ventana de Ajustes y el campo de semilla (no se pueden dibujar fuera de pantalla en los tests)
- [x] Navegar los menús con el mando (hecho en la Fase 11)

## Fase 8 — Arte pixel art (packs CC0) ✅
- [x] Packs CC0 elegidos y documentados en `CREDITS.md` (licencias originales en `Licenses/`): **Tiny Ski** de Kenney y la fuente **Public Pixel** de GGBotNet
- [x] Escala base común: 1 píxel de sprite = 3 pt (`GameConfig.pixelScale`), tiles de 16 × 16 y filtrado `nearest`
- [x] Atlas `Kenney.spriteatlas`: banderas de slalom, cuatro esquiadores, mono de nieve (nuevo obstáculo), roca y silla del telesilla. Los tiles del yeti del pack se descartan a propósito
- [x] Sprites propios con contorno automático del mismo color que Kenney para que todo combine (`PixelArt.outlined`)
- [x] El Cuico en pixel art a partir del icono (casco, antiparras espejadas, parka roja con cremallera, esquís con cantos lima)
- [x] Partículas de nieve: derrape al frenar o girar fuerte, estallido al caer y al aterrizar, polvo en el frente de la avalancha y ventisca con el viento blanco
- [x] Fuente pixel en el título, el HUD, los botones, los avisos y los títulos de pausa y resultados
- [x] Icono de la app (`AppIcon`): esquiador pixel art con antiparras frente a los Andes (original en `Design/AppIcon-source.png`)
- [ ] Animaciones por fotogramas del Cuico (de momento: esquís que giran, figura que se tumba, giros y mortales por transformación)
- [x] Redibujar araucarias y queñuas a escala 3 (hecho en la Fase 11)
- [ ] Revisar las partículas en la app (no se ven al dibujar fuera de pantalla en los tests)

## Fase 9 — Audio ✅
- [x] Todo el audio **sintetizado por código** en estilo chiptune (`Synth`): ondas cuadrada, triangular, senoidal y ruido, envolventes ADSR, vibrato, glissando y filtro. Original, sin archivos externos ni licencias de terceros
- [x] Efectos: girar, turbo, brinco, salto, aterrizaje, choque, queja del Cuico al caer (¡ay!), tropiezo, puerta, puerta fallada, meta, atrapado, truco, aterrizaje limpio, selfie, rugido del Kunk, chillido del Chupacabras, avalancha y clic de menú
- [x] Bucles continuos: los esquís sobre la nieve (suben con la velocidad) y el viento blanco
- [x] Música con aire andino en La menor pentatónica (quena, charango, bajo y bombo con ritmo de huayno): menú, bajada, persecución del Kunk y acecho del Chupacabras, con fundido entre temas
- [x] Gestor de audio con `AVAudioEngine` (`AudioManager`): buses de música y efectos con los volúmenes de los Ajustes, música más baja en pausa, síntesis en segundo plano al arrancar y silencio en los tests
- [x] Créditos de audio en `CREDITS.md`
- [x] Tests: síntesis, envolventes, bucles sin cortes, voces de igual longitud, efectos sin saturar y eventos de sonido del juego
- [ ] Escuchar y ajustar la mezcla jugando en la app (las previsualizaciones WAV están en `build/AudioPreview/`)

## Fase 10 — Persistencia y récords ✅
- [x] Modelo SwiftData (`RunRecord`): marca por modo (metros, tiempo con penalización o puntos), fecha, semilla, resumen y caídas
- [x] Top 10 local por modo (en slalom gana el menor tiempo); se guardan hasta 50 marcas por modo y se borran las peores
- [x] Estadísticas (`PlayerStats`): bajadas, metros, tiempo en la nieve, caídas, capturas del Kunk, encuentros y capturas del Chupacabras, avalanchas, slaloms terminados y trucos
- [x] Pantalla de **Récords** desde el menú, con ranking por modo, botón **Repetir** (vuelve a jugar la montaña del récord con su semilla), estadísticas y borrado con confirmación
- [x] El récord guardado sustituye a la mejor marca de la sesión en el menú y en los resultados («¡Nuevo récord!» o «Puesto N de tu top 10»)
- [x] Persistencia de ajustes (`SettingsStore` sobre `UserDefaults`, hecha en la Fase 7)
- [x] Almacén en disco en la app y en memoria durante los tests
- [x] Tests: guardado, orden por modo, marcas que no cuentan, top 10, recorte, estadísticas, semillas grandes, repetir y borrar
- [ ] Revisar a mano la tabla de récords (las listas con desplazamiento no se dibujan fuera de pantalla en los tests)

## Fase 11 — Pulido y equilibrio ✅
- [x] Ajuste con un piloto simulado (`BalanceTests`). El Kunk baja su velocidad máxima de 650 a 620 pt/s, se queda hasta ~125 m atrás y **se cansa** si el Cuico le saca ~100 m durante 4 s (vuelve 1.500 m más abajo). El HUD avisa «¡El Kunk se está cansando!»
- [x] Temblor de cámara (caídas, saltos grandes, Kunk, avalancha cerca) y *hit-stop* de 80 ms al chocar
- [x] Rendimiento medido: ~0,05 ms por paso de simulación (presupuesto a 120 fps: 8,3 ms), como mucho 16 trozos cargados y ~1.400 nodos al bajar más de 4 km
- [x] Accesibilidad: **Reducir movimiento** (sin temblores ni hit-stop y con menos partículas) y **HUD de alto contraste**, que siguen por defecto las preferencias de macOS; reasignación de teclas (Fase 7)
- [x] Personalidad del Cuico (borrador para revisar): frases en bocadillo según lo que pasa, sin repetirse y sin hablar sin parar, y pose de selfie si se queda quieto
- [x] Easter eggs: escribir **CUICO** en el menú le pone la parka dorada; bajar **6.961 m** (la altura del Aconcagua) en Descenso libre
- [x] Menús con el mando: en el menú, cruceta o stick eligen el modo y A o Menú empiezan; en resultados, A repite y B vuelve al menú; en pausa, B vuelve al menú
- [x] Araucarias y queñuas redibujadas a la escala común
- [ ] **Revisar con App-Zilla** la descripción y las frases del Cuico (`CuicoLines.swift`) y ajustarlas a la personalidad definitiva
- [ ] Partidas de prueba reales y lista de errores (el piloto simulado no sustituye a jugar): sensación del control, dificultad del Kunk y de la avalancha, mezcla de audio
- [ ] Decidir si se cambian los signos ¡ y ! de la fuente pixel (Public Pixel los dibuja como rombos)

## Fase 12 — CI y distribución
> **Decisión de publicación (en dos pasos):**
> 1. **Repositorio privado** mientras App-Zilla prueba una versión previa (`v1.0.0-rc.N`). El DMG de prueba se genera **en local** con un script, para no gastar minutos de Actions (en repos privados son limitados y los de macOS cuentan unas 10 veces).
> 2. Cuando la versión previa esté **aprobada**, el repositorio pasa a **público**, se activa el CI (gratis en repos públicos) y se publica **`v1.0.0`** con su DMG en GitHub Releases.

- [x] Script local `scripts/build-dmg.sh`: compila en Release (universal), firma ad hoc, crea el DMG con «Léeme» y su SHA-256 en `dist/`
- [x] DMG `v1.0.0-rc.1` generado y comprobado en local (firma, versión, arquitecturas y contenido)
- [ ] Crear el repositorio **privado** en GitHub y subir el código (pendiente de la aprobación de App-Zilla)
- [ ] Versión previa `v1.0.0-rc.1`: DMG generado en local y adjunto a una *pre-release* privada para que App-Zilla la pruebe
- [ ] Corregir lo que salga de la prueba (`rc.2`, `rc.3`… si hace falta)
- [ ] Tras la aprobación: pasar el repositorio a **público**
- [x] Workflow **CI** (`.github/workflows/ci.yml`): tests en cada push/PR; no se ejecuta mientras el repo sea privado
- [x] Workflow **Release** (`.github/workflows/release.yml`): con una etiqueta `v*` pasa los tests, crea el DMG y lo publica (las `-rc` como *pre-release*); no se ejecuta mientras el repo sea privado
- [ ] Comprobar los workflows la primera vez que el repo sea público (versión de Xcode del runner)
- [x] README final: capturas, descarga e instalación, controles, modos, criaturas, cómo abrir la app sin notarizar y cómo crear el DMG
- [x] `CHANGELOG.md` con la sección `1.0.0-rc.1`
- [ ] Publicación de `v1.0.0` (tras aprobar la versión previa)

---

## Ideas para después de la 1.0
- Traducción al inglés (el String Catalog ya estará preparado)
- Repetición de la mejor bajada (*ghost*)
- Reto diario con semilla compartida
- Editor de pistas
- Montañas andinas con nombre (Aconcagua, Ojos del Salado, Chimborazo…) como escenarios temáticos
