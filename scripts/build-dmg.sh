#!/bin/zsh
# Compila SkiFlow en Release con firma ad hoc y lo empaqueta en un DMG.
#
# Uso:
#   scripts/build-dmg.sh 1.0.0-rc.1
#
# La versión que ve macOS es la parte numérica (1.0.0); la etiqueta completa
# (con -rc.N) va en el nombre del DMG. El resultado queda en dist/.
# Sin cuenta de desarrollador de pago: nada de notarización ni Developer ID.
set -euo pipefail

VERSION="${1:?Indica la versión, por ejemplo: scripts/build-dmg.sh 1.0.0-rc.1}"
MARKETING="${VERSION%%-*}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="$ROOT/build/ReleaseDerivedData"
DIST="$ROOT/dist"
STAGING="$ROOT/build/dmg-staging"
APP_NAME="SkiFlow"
DMG="$DIST/$APP_NAME-$VERSION.dmg"

echo "▶︎ Compilando $APP_NAME $VERSION (versión $MARKETING, compilación $BUILD_NUMBER)…"
xcodebuild build \
    -project "$ROOT/$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED" \
    MARKETING_VERSION="$MARKETING" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="" \
    -quiet

APP="$DERIVED/Build/Products/Release/$APP_NAME.app"

echo "▶︎ Firmando ad hoc…"
codesign --force --deep --sign - "$APP"
codesign --verify --strict "$APP"

echo "▶︎ Creando el DMG…"
rm -rf "$STAGING" && mkdir -p "$STAGING" "$DIST"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
cat > "$STAGING/Léeme.txt" <<'TXT'
SkiFlow — instalación

1. Arrastra SkiFlow a la carpeta Aplicaciones.
2. La primera vez, macOS dirá que no puede verificar la app (no está
   notarizada porque no usamos una cuenta de desarrollador de pago).
   Pulsa «OK».
3. Ve a Ajustes del Sistema › Privacidad y seguridad, baja hasta
   «Seguridad» y pulsa «Abrir igualmente» junto al aviso de SkiFlow.
4. Confirma con tu contraseña o Touch ID. Desde entonces se abre normal.

© 2026 App-Zilla · Licencia MIT
TXT
rm -f "$DMG"
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" -quiet

echo "▶︎ Suma SHA-256:"
# Solo el nombre del archivo (sin rutas locales, que se publican con la versión).
(cd "$DIST" && shasum -a 256 "$(basename "$DMG")" | tee "$(basename "$DMG").sha256")
echo "✓ Listo: $DMG"
