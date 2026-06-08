#!/usr/bin/env bash
# Upload the built .conda packages in ./output to the prefix.dev channel.
#   CHANNEL defaults to bar-robotics.
# Auth, in order of preference:
#   1. PREFIX_API_KEY env -> passed explicitly as --api-key (reliable).
#   2. else OIDC trusted publishing (CI job needs id-token: write; rattler-build
#      >=0.31.1 exchanges the GitHub OIDC token automatically).
# Kept in bash (not a pixi inline task): deno_task_shell can't parse ${VAR:-default}.
set -euo pipefail
cd "$(dirname "$0")/.."

CHANNEL="${CHANNEL:-bar-robotics}"

# Prefer rattler-build on PATH (under `pixi run`); fall back to the project env
# binary so this also works when invoked as a plain `bash scripts/publish.sh`.
RB="rattler-build"
command -v "$RB" >/dev/null 2>&1 || RB="$PWD/.pixi/envs/default/bin/rattler-build"

shopt -s nullglob
files=(output/*.conda)
if [ ${#files[@]} -eq 0 ]; then
  echo "::error::no .conda files in output/ — run 'pixi run build-all' first" >&2
  exit 1
fi
echo "uploading ${#files[@]} package(s) to prefix.dev/$CHANNEL:"
printf '  %s\n' "${files[@]}"

if [ -n "${PREFIX_API_KEY:-}" ]; then
  echo "auth: PREFIX_API_KEY"
  "$RB" upload prefix -c "$CHANNEL" --api-key "$PREFIX_API_KEY" "${files[@]}"
else
  echo "auth: OIDC trusted publishing (no PREFIX_API_KEY set)"
  "$RB" upload prefix -c "$CHANNEL" "${files[@]}"
fi
