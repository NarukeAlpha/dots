#!/usr/bin/env bash
set -euo pipefail

SERVICE="${OPENCODE_AUTH_KEYCHAIN_SERVICE:-opencode-auth}"
AUTH_PATH="${OPENCODE_AUTH_PATH:-$HOME/.local/share/opencode/auth.json}"

usage() {
  cat <<'EOF'
Usage: scripts/opencode-auth-keychain.sh backup|restore|status

Backs up or restores OpenCode auth through macOS Keychain. Values are never
printed. The full auth JSON is stored as account "auth.json" under service
"opencode-auth"; selected provider fields are also stored as individual
accounts for inspection/status.

Environment overrides:
  OPENCODE_AUTH_KEYCHAIN_SERVICE  default: opencode-auth
  OPENCODE_AUTH_PATH              default: ~/.local/share/opencode/auth.json
EOF
}

require_macos_keychain() {
  if [ "$(uname -s)" != "Darwin" ]; then
    echo "macOS Keychain is required." >&2
    exit 1
  fi
  command -v security >/dev/null 2>&1 || {
    echo "Missing security command." >&2
    exit 1
  }
}

backup_auth() {
  require_macos_keychain
  command -v node >/dev/null 2>&1 || {
    echo "Missing node command." >&2
    exit 1
  }
  if [ ! -f "$AUTH_PATH" ]; then
    echo "Missing $AUTH_PATH" >&2
    exit 1
  fi

  security add-generic-password -U -s "$SERVICE" -a auth.json -w "$(cat "$AUTH_PATH")" >/dev/null

  node - "$AUTH_PATH" <<'NODE' | while IFS= read -r -d "" account && IFS= read -r -d "" value; do
const fs = require("fs");
const auth = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const entries = {
  "google.key": auth.google?.key,
  "arcee.key": auth.arcee?.key,
  "openai.refresh": auth.openai?.refresh,
  "openai.access": auth.openai?.access,
  "openai.accountId": auth.openai?.accountId,
  "openai.expires": auth.openai?.expires == null ? undefined : String(auth.openai.expires),
  "deepseek.key": auth.deepseek?.key
};
for (const [account, value] of Object.entries(entries)) {
  if (typeof value === "string" && value.length > 0) {
    process.stdout.write(account + "\0" + value + "\0");
  }
}
NODE
    security add-generic-password -U -s "$SERVICE" -a "$account" -w "$value" >/dev/null
  done

  echo "Backed up OpenCode auth to Keychain service $SERVICE."
}

restore_auth() {
  require_macos_keychain
  local value
  value="$(security find-generic-password -s "$SERVICE" -a auth.json -w 2>/dev/null || true)"
  if [ -z "$value" ]; then
    echo "No auth.json entry found in Keychain service $SERVICE." >&2
    exit 1
  fi

  mkdir -p "$(dirname "$AUTH_PATH")"
  umask 077
  printf '%s' "$value" > "$AUTH_PATH"
  chmod 0600 "$AUTH_PATH"
  echo "Restored OpenCode auth to $AUTH_PATH."
}

status_auth() {
  require_macos_keychain
  for account in auth.json google.key arcee.key openai.refresh openai.access openai.accountId openai.expires deepseek.key; do
    if security find-generic-password -s "$SERVICE" -a "$account" >/dev/null 2>&1; then
      echo "$account: present"
    else
      echo "$account: missing"
    fi
  done
}

case "${1:-}" in
  backup)
    backup_auth
    ;;
  restore)
    restore_auth
    ;;
  status)
    status_auth
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    echo "Unknown command: $1" >&2
    usage >&2
    exit 2
    ;;
esac
