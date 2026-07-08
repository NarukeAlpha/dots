#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILED=0

check_absent_publishable_name() {
  local name="$1"
  local hits

  hits="$(
    git -C "$ROOT" ls-files -co --exclude-standard | while IFS= read -r path; do
      if [ "$path" = "$name" ] ||
        [[ "$path" == "$name"/* ]] ||
        [[ "$path" == */"$name" ]] ||
        [[ "$path" == */"$name"/* ]]; then
        printf '%s\n' "$path"
      fi
    done
  )"

  if [ -n "$hits" ]; then
    echo "Disallowed publishable path present:" >&2
    echo "$hits" >&2
    FAILED=1
  fi
}

check_literal_secret_assignments() {
  local hits
  hits="$(
    rg -n --hidden \
      --glob '!.git/**' \
      --glob '!.idea/**' \
      --glob '!node_modules/**' \
      --glob '!dist/**' \
      --glob '!package-lock.json' \
      --glob '!bun.lock' \
      '("|'\'')?(EXA_API_KEY|CONVEX_WRITE_KEY|API_KEY|WRITE_KEY|TOKEN|SECRET|PASSWORD)("|'\'')?\s*[:=]\s*("|'\'')[^_"'\''$][^"'\''[:space:]]+' \
      "$ROOT" || true
  )"
  if [ -n "$hits" ]; then
    echo "$hits" >&2
    FAILED=1
  fi
}

check_absent_publishable_name ".claude"
check_absent_publishable_name "auth.json"
check_absent_publishable_name "node_modules"
check_absent_publishable_name "dist"
check_literal_secret_assignments

if [ "$FAILED" -ne 0 ]; then
  echo "Secret check failed." >&2
  exit 1
fi

echo "Secret check passed."
