#!/usr/bin/env bash

set -euo pipefail

FILE="${FILE:-go-mod-overrides}"
PROXY="${GOPROXY:-https://proxy.golang.org}"

changed=false
summary="Automated version bumps in \`${FILE}\`:"$'\n'

while IFS= read -r module; do
  module="$(echo "$module" | xargs)"
  [ -z "$module" ] && continue

  escaped_module="${module//\//\\/}"
  current="$(grep -oE "^-replace ${escaped_module}=${escaped_module}@v[0-9.]+" "$FILE" | grep -oE 'v[0-9.]+$' || true)"
  [ -z "$current" ] && { echo "skip: $module not pinned in $FILE"; continue; }

  latest="$(curl -fsSL "${PROXY}/${module}/@latest" | python -c 'import json, sys; print(json.load(sys.stdin)["Version"])' 2>/dev/null || true)"
  [ -z "$latest" ] && { echo "warn: could not resolve latest for $module"; continue; }

  if [ "$current" != "$latest" ]; then
    echo "bump: $module $current -> $latest"
    sed -i -E "s#(^-replace ${escaped_module}=${escaped_module}@)v[0-9.]+#\\1${latest}#" "$FILE"
    summary+="- \`${module}\`: ${current} → ${latest}"$'\n'
    changed=true
  else
    echo "ok: $module already at $latest"
  fi
done <<< "${MODULES:-}"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "changed=${changed}" >> "$GITHUB_OUTPUT"
  {
    echo "summary<<EOF"
    echo "$summary"
    echo "EOF"
  } >> "$GITHUB_OUTPUT"
fi
