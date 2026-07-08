#!/usr/bin/env bash
set -euo pipefail

SERVICE="${DOTS_KEYCHAIN_SERVICE:-dots}"
ACCOUNT="${DELTA_HOSTS_KEYCHAIN_ACCOUNT:-DELTA_HOSTS_ENTRY}"

usage() {
  cat <<'EOF'
Usage: scripts/delta-hosts-keychain.sh backup|print|restore|status

Backs up and restores active /etc/hosts entries for the delta host through
macOS Keychain service "dots", account "DELTA_HOSTS_ENTRY".

Commands:
  backup   Store current active delta /etc/hosts lines in Keychain.
  print    Print the stored delta host entry.
  restore  Append the stored entry to /etc/hosts if no active delta entry exists.
  status   Report whether an active or stored delta entry exists.
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

active_delta_entries() {
  grep -E '^[^#].*[[:space:]]delta([[:space:]]|$)' /etc/hosts || true
}

stored_delta_entries() {
  security find-generic-password -s "$SERVICE" -a "$ACCOUNT" -w 2>/dev/null || true
}

backup_entries() {
  require_macos_keychain
  local entries
  entries="$(active_delta_entries)"

  if [ -z "$entries" ]; then
    echo "No active delta entry found in /etc/hosts." >&2
    exit 1
  fi

  security add-generic-password -U -s "$SERVICE" -a "$ACCOUNT" -w "$entries" >/dev/null
  echo "Stored delta host entry in Keychain service $SERVICE, account $ACCOUNT."
}

print_entries() {
  require_macos_keychain
  local entries
  entries="$(stored_delta_entries)"

  if [ -z "$entries" ]; then
    echo "No stored delta host entry found in Keychain service $SERVICE, account $ACCOUNT." >&2
    exit 1
  fi

  printf '%s\n' "$entries"
}

restore_entries() {
  require_macos_keychain
  local entries
  entries="$(stored_delta_entries)"

  if [ -z "$entries" ]; then
    echo "No stored delta host entry found in Keychain service $SERVICE, account $ACCOUNT." >&2
    exit 1
  fi

  if [ -n "$(active_delta_entries)" ]; then
    echo "Active delta entry already exists in /etc/hosts."
    active_delta_entries
    exit 0
  fi

  printf '\n%s\n' "$entries" | sudo tee -a /etc/hosts >/dev/null
  echo "Restored delta host entry to /etc/hosts."
}

status_entries() {
  require_macos_keychain

  if [ -n "$(active_delta_entries)" ]; then
    echo "active: present"
    active_delta_entries
  else
    echo "active: missing"
  fi

  if [ -n "$(stored_delta_entries)" ]; then
    echo "keychain: present"
  else
    echo "keychain: missing"
  fi
}

case "${1:-}" in
  backup)
    backup_entries
    ;;
  print)
    print_entries
    ;;
  restore)
    restore_entries
    ;;
  status)
    status_entries
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
