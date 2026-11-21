# SkiFlow

Juego de esquí 2D para macOS inspirado en el clásico *SkiFree* (1991), ambientado en la **cordillera de los Andes**. Eres **el Cuico**, un típico chileno que sube a la nieve más a posar que a esquiar. Baja la montaña esquivando queñuas, rocas, llamas y otros esquiadores, compite contra el reloj en slalom, haz acrobacias en freestyle… y huye del **Kunk**. Y si tienes muy mala suerte, también del **Chupacabras**.

> Estado: en desarrollo (los cuatro modos jugables, Fase 6). Consulta el plan en [TODO.md](TODO.md).

## Controles

| Teclado | Ratón / trackpad | Mando | Acción |
|---|---|---|---|
| ← / A, → / D | Mover el cursor | Stick izquierdo o cruceta | Girar (mantén la tecla para seguir girando) |
| ↓ / S | Cursor bajo el Cuico | Cruceta ↓ | Apuntar recto hacia abajo |
| ↑ / W | Cursor por encima | Cruceta ↑ o B (○) | Frenar (esquís atravesados) |
| Espacio | Clic | A (✕) | Brincar |
| F (mantener) | | X (□) o gatillo derecho | Turbo |
| Esc / P | | Menú (Options) | Pausa |
| R | | Vista (Share) | Reiniciar (montaña nueva en Descenso libre; mismo trazado en slalom) |
| 1 / 2 / 3 / 4 | | | Descenso libre / Slalom / Slalom entre árboles / Freestyle (provisional hasta tener menú) |

Al tocar las teclas de giro se desactiva el apuntado con ratón; vuelve a activarse en cuanto mueves el ratón. La partida se pausa sola si cambias de app.

## En la montaña

- **Alta montaña**: rocas, penitentes de hielo, apachetas y vicuñas. Más abajo aparecen cactus, llamas y guanacos, y al final el bosque de araucarias y queñuas.
- **Rampas**: saltas sobre lo que sea bajo (rocas, animales…), pero no sobre árboles, refugios ni torres. ¡Ojo con los cóndores en pleno vuelo!
- **Hielo**: cuesta frenar. **Nieve profunda**: frena. **Viento blanco**: te empuja de lado y tapa la vista.
- Las piedras pequeñas te hacen tropezar; todo lo demás te tira al suelo.

## Modos

- **Descenso libre**: baja lo más lejos posible. A partir de los 2.000 m te persigue el Kunk.
- **Slalom**: 20 puertas en una pista abierta. Pasa entre las dos banderas de cada puerta; cada puerta fallada suma 5 s. R repite el mismo trazado para mejorar tu tiempo.
- **Slalom entre árboles**: lo mismo, pero en un bosque cerrado de araucarias y queñuas.
- **Freestyle**: 1.000 m llenos de rampas para sumar puntos con trucos (ver abajo).
- En los slalom y en freestyle no hay criaturas, pero sí una **avalancha** que baja detrás de ti: si te paras o te caes demasiado, te sepulta.

### Trucos (Freestyle, en el aire)

| Tecla / botón | Truco | Puntos |
|---|---|---|
| ← / → | Giro 360 | 100 |
| ↓ | Mortal adelante | 150 |
| ↑ | Mortal atrás | 150 |
| Espacio (A en el mando) | Selfie | 50 |

Varios trucos en el mismo salto multiplican los puntos, y cada aterrizaje limpio sube la racha (hasta ×4). Si terminas el truco justo al tocar el suelo o aterrizas atravesado, solo te llevas la mitad y se corta la racha. Si tocas el suelo a mitad de un truco, te caes y pierdes los puntos del salto.

## Las criaturas

- **El Kunk**: a partir de los 2.000 m sale a por ti y no para. Corre más que tú… salvo que mantengas el **turbo** (F). Si te caes, te alcanza.
- **El Chupacabras**: casi nunca aparece (más o menos en una de cada doce bajadas largas). Cuando acecha verás un aviso: tienes poco más de un segundo antes de que embista. **Salta** (Espacio) para esquivarlo.

## Requisitos

- macOS 26 o superior
- Para compilar: Xcode 27 y [XcodeGen](https://github.com/yonaskolb/XcodeGen) (solo si cambias `project.yml`)

## Compilar desde el código

```bash
git clone <url-del-repositorio> SkiFlow
cd SkiFlow
open SkiFlow.xcodeproj
```

El proyecto `SkiFlow.xcodeproj` se genera a partir de `project.yml`. Si añades targets o cambias ajustes del proyecto, edita `project.yml` y regenera:

```bash
xcodegen generate
```

Para probar las criaturas sin bajar 2 km, se pueden pasar ajustes al lanzar la app (en Xcode, en *Product › Scheme › Edit Scheme… › Arguments*; o desde la terminal, si compilaste con `-derivedDataPath build/DerivedData`):

```bash
open build/DerivedData/Build/Products/Debug/SkiFlow.app --args -kunkSpawnMeters 150 -chupacabrasChance 1 -chupacabrasMeters 80
open build/DerivedData/Build/Products/Debug/SkiFlow.app --args -mode treeSlalom
```

Ejecutar los tests desde la terminal:

```bash
xcodebuild test -project SkiFlow.xcodeproj -scheme SkiFlow -destination 'platform=macOS'
```

## Abrir la app por primera vez

SkiFlow se distribuye con **firma ad hoc** y **sin notarizar** (no se usa una cuenta de desarrollador de Apple de pago), así que macOS la bloqueará la primera vez:

1. Abre `SkiFlow.app`. macOS mostrará un aviso diciendo que no puede verificar la app; pulsa **OK**.
2. Ve a **Ajustes del Sistema › Privacidad y seguridad**.
3. Baja hasta la sección **Seguridad**, donde aparecerá un mensaje sobre SkiFlow, y pulsa **«Abrir igualmente»**.
4. Confirma con tu contraseña o Touch ID. A partir de ahí la app se abre con normalidad.

## Estructura

```
SkiFlow/
├── App/          Punto de entrada y ventana principal (SwiftUI)
├── Game/         Escena de SpriteKit, entidades y sistemas
├── World/        Generación procedural de la montaña
├── UI/           Menús, HUD y ajustes (SwiftUI)
├── Audio/        Efectos y música
├── Persistence/  Récords y ajustes
└── Resources/    Assets, atlas de sprites y sonidos
SkiFlowTests/     Tests con Swift Testing
```

## Licencia

[MIT](LICENSE) © 2026 App-Zilla
