#!/usr/bin/env bash
# Drop the conda build manifests in overlays/ into the matching vcs-imported
# source trees. overlays/ mirrors src/ layout, e.g.
#   overlays/mujoco_ament/pixi.toml  →  src/mujoco_ament/pixi.toml
# First-party bar_ros2 packages carry their own pixi.toml in the repo, so they
# are NOT overlaid here — only the third-party deps that ship just a package.xml.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d src ]; then
  echo "error: ./src missing — run 'pixi run import' first" >&2
  exit 1
fi

count=0
while IFS= read -r -d '' f; do
  dest="src/${f#overlays/}"
  mkdir -p "$(dirname "$dest")"
  cp "$f" "$dest"
  echo "overlay → $dest"
  count=$((count + 1))
done < <(find overlays -name pixi.toml -print0)
echo "applied $count overlay manifest(s)"
