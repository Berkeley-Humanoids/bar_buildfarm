#!/usr/bin/env bash
# Build every package in packages.txt into ./output as a .conda.
#   ./scripts/build-all.sh [target-platform]   (default: linux-64)
# Run inside the pixi env (`pixi run build-all`) so `pixi build` sees the
# workspace channels + the pixi-build preview.
set -euo pipefail
cd "$(dirname "$0")/.."

PLATFORM="${1:-linux-64}"
mkdir -p output

while IFS= read -r pkg; do
  case "$pkg" in ''|\#*) continue ;; esac
  # Point --path at the pixi.toml FILE, not the dir: each package dir holds both
  # pixi.toml and package.xml, and some pixi-build-ros backend builds mis-resolve
  # a bare dir ("manifest path '<dir>/package.xml' is a directory"). The explicit
  # file is unambiguous and built green on both arches.
  if [ ! -f "$pkg/pixi.toml" ]; then
    echo "::warning::skipping $pkg (no pixi.toml — did you run import + overlay?)"
    continue
  fi
  echo "::group::build $pkg ($PLATFORM)"
  pixi build --path "$pkg/pixi.toml" -o output --target-platform "$PLATFORM"
  echo "::endgroup::"
done < packages.txt

echo "built artifacts:"
ls -1 output/*.conda 2>/dev/null || echo "  (none)"
