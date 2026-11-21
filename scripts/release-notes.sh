#!/bin/zsh
# Notas de una versión a partir de CHANGELOG.md, más las instrucciones de instalación.
# Uso: scripts/release-notes.sh 1.0.0-rc.1
set -euo pipefail
VERSION="${1:?Indica la versión}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Imprime el cuerpo de la sección "## [<nombre>]" del CHANGELOG.
section() {
  awk -v name="[$1]" '
    index($0, "## " name) == 1 { found = 1; next }
    found && /^## \[/ { exit }
    found { print }
  ' "$ROOT/CHANGELOG.md"
}

NOTES="$(section "$VERSION")"
[[ -z "${NOTES//[[:space:]]/}" ]] && NOTES="$(section "Sin publicar")"
print -r -- "$NOTES"

cat <<'TXT'

## Instalación

1. Descarga `SkiFlow-*.dmg`, ábrelo y arrastra **SkiFlow** a Aplicaciones.
2. SkiFlow está firmado ad hoc y **no está notarizado**: la primera vez macOS no te dejará abrirlo. Ve a **Ajustes del Sistema › Privacidad y seguridad**, baja hasta **Seguridad** y pulsa **«Abrir igualmente»**.

Requiere macOS 26 o superior.
TXT
