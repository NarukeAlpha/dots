#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILED=0

check_absent_path() {
  local pattern="$1"
  if find "$ROOT" -path "$pattern" -print -quit | grep -q .; then
    echo "Disallowed path present: $pattern" >&2
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

check_absent_path "$ROOT/**/.claude"
check_absent_path "$ROOT/**/auth.json"
check_absent_path "$ROOT/**/node_modules"
check_absent_path "$ROOT/**/dist"
check_literal_secret_assignments

if [ "$FAILED" -ne 0 ]; then
  echo "Secret check failed." >&2
  exit 1
fi

echo "Secret check passed."
