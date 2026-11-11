#!/bin/sh
# make-release.sh — собрать публичный архив прошивки EE71.
# Архив = flash-пакет (скрипты + образы) + README + CHANGELOG + sha256sums.
# Использование: sh tools/make-release.sh [VERSION]   (default: v1.3)
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=${1:-v1.3}
DIR="EE71-firmware-$VERSION"
OUT="$ROOT/release/$DIR"

rm -rf "$ROOT/release"
mkdir -p "$OUT"

cp -R "$ROOT/flash" "$OUT/flash"
cp "$ROOT/README.md" "$ROOT/CHANGELOG.md" "$OUT/"

# контрольные суммы (macOS: shasum, Linux: sha256sum)
if command -v sha256sum >/dev/null 2>&1; then
    SUM="sha256sum"
else
    SUM="shasum -a 256"
fi
(cd "$OUT" && find . -type f -exec $SUM {} + | sed 's| \./| |' | sort -k2 > sha256sums.txt)

if command -v zip >/dev/null 2>&1; then
    (cd "$ROOT/release" && zip -qr "$DIR.zip" "$DIR")
    echo "== release: $ROOT/release/$DIR.zip"
    ls -lh "$ROOT/release/$DIR.zip" | awk '{print "   size:", $5}'
else
    echo "== zip not found, raw dir: $OUT"
fi
echo "== files: $(find "$OUT" -type f | wc -l)"
