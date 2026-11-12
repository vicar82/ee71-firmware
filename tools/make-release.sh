#!/bin/sh
# make-release.sh — собрать публичные архивы EE71.
#   EE71-firmware-VERSION.zip  — flash-пакет (Update-only) + README + CHANGELOG + sha256
#   EE71-unbrick-kit.zip       — стоковые образы + mtdwriter + инструкция по восстановлению
# Использование: sh tools/make-release.sh [VERSION]   (default: v1.3)
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=${1:-v1.3}
DIR="EE71-firmware-$VERSION"
OUT="$ROOT/release/$DIR"
KIT="$ROOT/release/unbrick-kit"

rm -rf "$ROOT/release" "$ROOT/release-staging"
mkdir -p "$OUT" "$KIT"

# --- firmware ---
cp -R "$ROOT/flash" "$OUT/flash"
cp "$ROOT/README.md" "$ROOT/CHANGELOG.md" "$OUT/"

# --- unbrick kit ---
cp "$ROOT/flash/images/mdm9640-sysfs.ubi"   "$KIT/stock-sysfs.ubi"
cp "$ROOT/flash/images/jrdresource.ubi"     "$KIT/stock-jrdresource.ubi"
cp "$ROOT/docs-mtdtools/mtdwriter"          "$KIT/mtdwriter"
cp "$ROOT/docs/UNBRICK.md"                  "$KIT/README-UNBRICK.md"

# контрольные суммы (macOS: shasum, Linux: sha256sum)
if command -v sha256sum >/dev/null 2>&1; then
    SUM="sha256sum"
else
    SUM="shasum -a 256"
fi
(cd "$OUT" && find . -type f -exec $SUM {} + | sed 's| \./| |' | sort -k2 > sha256sums.txt)

if command -v zip >/dev/null 2>&1; then
    (cd "$ROOT/release" && zip -qr "$DIR.zip" "$DIR")
    (cd "$KIT" && zip -qr "$ROOT/release/EE71-unbrick-kit.zip" .)
    echo "== release: $ROOT/release/$DIR.zip"
    ls -lh "$ROOT/release/$DIR.zip" "$ROOT/release/EE71-unbrick-kit.zip" | awk '{print "   ", $5, $9}'
else
    echo "== zip not found, raw dirs: $OUT, $KIT"
fi
echo "== firmware files: $(find "$OUT" -type f | wc -l), kit files: $(find "$KIT" -type f | wc -l)"
