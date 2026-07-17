#!/usr/bin/env bash

set -euo pipefail

readonly VERSION_PATTERN='v[0-9]+\.[0-9]+\.[0-9]+'
FILE="${FILE:-go-mod-overrides}"
PROXY="${GOPROXY:-https://proxy.golang.org}"

if [ "$(basename "$FILE")" != "go-mod-overrides" ]; then
  echo "error: FILE must point to go-mod-overrides" >&2
  exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "error: $FILE does not exist" >&2
  exit 1
fi

changed=false
summary="Automated version bumps in \`${FILE}\`:"$'\n'

while IFS= read -r module; do
  module="$(echo "$module" | xargs)"
  [ -z "$module" ] && continue

  escaped_module="${module//\//\\/}"
  current="$(grep -oE "^-replace ${escaped_module}=${escaped_module}@${VERSION_PATTERN}" "$FILE" | grep -oE "${VERSION_PATTERN}\$" || true)"
  [ -z "$current" ] && { echo "skip: $module not pinned in $FILE"; continue; }

  latest="$(curl -fsSL "${PROXY}/${module}/@latest" | jq -r '.Version // empty' 2>/dev/null || true)"
  [ -z "$latest" ] && { echo "warn: could not resolve latest for $module"; continue; }

  if [ "$current" != "$latest" ]; then
    echo "bump: $module $current -> $latest"
    sed -i -E "s#(^-replace ${escaped_module}=${escaped_module}@)${VERSION_PATTERN}#\\1${latest}#" "$FILE"
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
