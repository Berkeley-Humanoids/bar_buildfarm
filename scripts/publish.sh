#!/usr/bin/env bash
# Upload the built .conda packages in ./output to the prefix.dev channel.
#   CHANNEL defaults to bar-robotics.
# Auth: OIDC trusted publishing in CI (job has id-token: write, rattler-build
# >=0.31.1 uses it automatically), or PREFIX_API_KEY for a local/manual upload.
# Kept in bash (not a pixi inline task) so ${CHANNEL:-...} + globbing parse —
# pixi's deno_task_shell does not support bash parameter-default expansion.
set -euo pipefail
cd "$(dirname "$0")/.."

CHANNEL="${CHANNEL:-bar-robotics}"
shopt -s nullglob
files=(output/*.conda)
if [ ${#files[@]} -eq 0 ]; then
  echo "::error::no .conda files in output/ — run 'pixi run build-all' first" >&2
  exit 1
fi

echo "uploading ${#files[@]} package(s) to prefix.dev/$CHANNEL:"
printf '  %s\n' "${files[@]}"
rattler-build upload prefix -c "$CHANNEL" "${files[@]}"
