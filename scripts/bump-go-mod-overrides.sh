#!/usr/bin/env bash
# Bumps `-replace <module>=<module>@<version>` lines in go-mod-overrides
# to the latest version reported by the Go module proxy.
# Only modules listed in the MODULES env var (one per line) are touched.
set -euo pipefail

FILE="${FILE:-go-mod-overrides}"
PROXY="${GOPROXY:-https://proxy.golang.org}"

changed=false
summary="Automated version bumps in \`${FILE}\`:"$'\n'

while IFS= read -r module; do
  module="$(echo "$module" | xargs)"  # trim whitespace
  [ -z "$module" ] && continue

  # Current pinned version, e.g. v0.55.0
  current="$(grep -oE "^-replace ${module//\//\\/}=${module//\//\\/}@v[0-9.]+" "$FILE" \
              | grep -oE 'v[0-9.]+$' || true)"
  if [ -z "$current" ]; then
    echo "skip: $module not pinned in $FILE"
    continue
  fi

  # Latest version from the module proxy.
  # Module paths with uppercase letters need !-escaping, but golang.org/x/* is already lowercase.
  latest="$(curl -fsSL "${PROXY}/${module}/@latest" | sed -n 's/.*"Version":"\([^"]*\)".*/\1/p')"
  if [ -z "$latest" ]; then
    echo "warn: could not resolve latest for $module"
    continue
  fi

  # Use sort -V to pick the higher version and guard against downgrades.
  higher="$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -n1)"
  if [ "$higher" = "$current" ]; then
    echo "ok: $module already at $current (latest reported: $latest)"
    continue
  fi

  echo "bump: $module $current -> $latest"
  sed -i -E "s#(^-replace ${module//\//\\/}=${module//\//\\/}@)v[0-9.]+#\1${latest}#" "$FILE"
  summary+="- \`${module}\`: ${current} → ${latest}"$'\n'
  changed=true
done <<< "${MODULES:-}"

# Expose outputs to the workflow.
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "changed=${changed}" >> "$GITHUB_OUTPUT"
  {
    echo "summary<<EOF"
    printf '%s' "$summary"
    echo "EOF"
  } >> "$GITHUB_OUTPUT"
fi
