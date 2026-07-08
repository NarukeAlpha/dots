#!/usr/bin/env bash
set -euo pipefail

DOTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_ROOT="${HOME}/.dots-backups/$(date +%Y%m%d-%H%M%S)"
WITH_SECRETS=0
SECRETS_FROM_KEYCHAIN=0
INSTALL_TOOLS=1
FORCE=0

usage() {
  cat <<'EOF'
Usage: scripts/install.sh [--skip-tools] [--with-secrets] [--secrets-from-keychain] [--force]

Bootstraps Node.js 24, uv, and Codex CLI, then installs public-safe dotfiles and setup scripts.

Options:
  --skip-tools             Skip Node.js 24 and Codex CLI bootstrap.
  --with-secrets           Render Codex/OpenCode configs from templates using env vars.
  --secrets-from-keychain  Read secrets from macOS Keychain service "dots"; implies --with-secrets.
  --force                  Replace existing files after backing them up.

Secrets can be provided by environment, .env in this repo, ~/.dots.env, or
macOS Keychain with --secrets-from-keychain.

Required for --with-secrets:
  EXA_API_KEY
  CONVEX_WRITE_KEY_DEV
  CONVEX_WRITE_KEY_PROD
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-tools)
      INSTALL_TOOLS=0
      ;;
    --with-secrets)
      WITH_SECRETS=1
      ;;
    --secrets-from-keychain)
      SECRETS_FROM_KEYCHAIN=1
      WITH_SECRETS=1
      ;;
    --force)
      FORCE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

load_env_file() {
  local file="$1"
  if [ -f "$file" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$file"
    set +a
  fi
}

backup_file() {
  local target="$1"
  if [ -e "$target" ] || [ -L "$target" ]; then
    local backup="${BACKUP_ROOT}${target}"
    mkdir -p "$(dirname "$backup")"
    cp -p "$target" "$backup"
    echo "Backed up $target -> $backup"
  fi
}

install_file() {
  local source="$1"
  local target="$2"
  local mode="${3:-0644}"
  mkdir -p "$(dirname "$target")"
  if [ -e "$target" ] || [ -L "$target" ]; then
    if [ "$FORCE" -ne 1 ]; then
      echo "Skipping existing $target (use --force to replace)"
      return 0
    fi
    backup_file "$target"
  fi
  install -m "$mode" "$source" "$target"
  echo "Installed $target"
}

install_directory() {
  local source="$1"
  local target="$2"
  mkdir -p "$(dirname "$target")"
  if [ -e "$target" ] || [ -L "$target" ]; then
    if [ "$FORCE" -ne 1 ]; then
      echo "Skipping existing $target (use --force to replace)"
      return 0
    fi
    local backup="${BACKUP_ROOT}${target}"
    mkdir -p "$(dirname "$backup")"
    cp -pR "$target" "$backup"
    echo "Backed up $target -> $backup"
    rm -rf "$target"
  fi
  cp -pR "$source" "$target"
  echo "Installed $target"
}

require_env() {
  local missing=0
  for name in "$@"; do
    if [ -z "${!name:-}" ]; then
      echo "Missing required env var: $name" >&2
      missing=1
    fi
  done
  return "$missing"
}

read_keychain_secret() {
  local account="$1"
  if [ "$(uname -s)" != "Darwin" ]; then
    return 1
  fi
  security find-generic-password -s dots -a "$account" -w 2>/dev/null || true
}

load_keychain_secrets() {
  if [ "$(uname -s)" != "Darwin" ]; then
    echo "--secrets-from-keychain is only supported on macOS." >&2
    exit 1
  fi

  EXA_API_KEY="${EXA_API_KEY:-$(read_keychain_secret EXA_API_KEY)}"
  CONVEX_WRITE_KEY_DEV="${CONVEX_WRITE_KEY_DEV:-$(read_keychain_secret CONVEX_WRITE_KEY_DEV)}"
  CONVEX_WRITE_KEY_PROD="${CONVEX_WRITE_KEY_PROD:-$(read_keychain_secret CONVEX_WRITE_KEY_PROD)}"

  export EXA_API_KEY CONVEX_WRITE_KEY_DEV CONVEX_WRITE_KEY_PROD
}

render_template() {
  local source="$1"
  local target="$2"
  mkdir -p "$(dirname "$target")"
  if [ -e "$target" ] || [ -L "$target" ]; then
    if [ "$FORCE" -ne 1 ]; then
      echo "Skipping existing $target (use --force to replace)"
      return 0
    fi
    backup_file "$target"
  fi
  perl -0pe '
    s#__HOME__#$ENV{HOME}#g;
    s#__EXA_API_KEY__#$ENV{EXA_API_KEY} // ""#ge;
    s#__CONVEX_WRITE_KEY_DEV__#$ENV{CONVEX_WRITE_KEY_DEV} // ""#ge;
    s#__CONVEX_WRITE_KEY_PROD__#$ENV{CONVEX_WRITE_KEY_PROD} // ""#ge;
  ' "$source" > "$target"
  chmod 0600 "$target"
  echo "Rendered $target"
}

render_codex_config() {
  local source="${DOTS_ROOT}/config/codex/config.toml.template"
  local target="${HOME}/.codex/config.toml"
  mkdir -p "$(dirname "$target")"
  if [ -e "$target" ] || [ -L "$target" ]; then
    if [ "$FORCE" -ne 1 ]; then
      echo "Skipping existing $target (use --force to replace)"
      return 0
    fi
    backup_file "$target"
  fi

  perl -0pe '
    s#__HOME__#$ENV{HOME}#g;
    s#__EXA_API_KEY__#$ENV{EXA_API_KEY} // ""#ge;
    s#__CONVEX_WRITE_KEY_DEV__#$ENV{CONVEX_WRITE_KEY_DEV} // ""#ge;
    s#__CONVEX_WRITE_KEY_PROD__#$ENV{CONVEX_WRITE_KEY_PROD} // ""#ge;
  ' "$source" |
    awk -v keep_exa="$([ -n "${EXA_API_KEY:-}" ] && printf 1 || printf 0)" '
      /^\[mcp_servers\.exa\]/ && keep_exa != "1" {
        skip = 1
        next
      }
      /^\[/ {
        skip = 0
      }
      !skip {
        print
      }
    ' > "$target"

  chmod 0600 "$target"
  echo "Rendered $target"
}

install_node_and_codex_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required for macOS tool bootstrap." >&2
    echo "Install it from https://brew.sh, then rerun this script." >&2
    exit 1
  fi

  eval "$(brew shellenv)"
  brew install node@24
  brew install uv

  local node24_bin
  node24_bin="$(brew --prefix node@24)/bin"
  export PATH="$node24_bin:$PATH"

  npm install -g @openai/codex
  echo "Installed Node.js $(node --version) and Codex CLI."
}

install_node_and_codex_linux() {
  if [ -s "$HOME/.nvm/nvm.sh" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.nvm/nvm.sh"
    nvm install 24
    nvm alias default 24
  elif command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    echo "Using existing Node.js $(node --version). Install Node 24 first if this is not v24."
  else
    echo "Install Node.js 24 first, then rerun: npm install -g @openai/codex" >&2
    exit 1
  fi

  npm install -g @openai/codex
  if ! command -v uv >/dev/null 2>&1; then
    echo "Install uv after this script: https://docs.astral.sh/uv/getting-started/installation/" >&2
  fi
  echo "Installed Codex CLI with npm."
}

install_node_and_codex() {
  case "$(uname -s)" in
    Darwin)
      install_node_and_codex_macos
      ;;
    Linux)
      install_node_and_codex_linux
      ;;
    *)
      echo "Automatic Node/Codex bootstrap is supported by this script on macOS and Linux." >&2
      echo "On Windows, install Node.js 24 and run: npm install -g @openai/codex" >&2
      exit 1
      ;;
  esac
}

load_env_file "${DOTS_ROOT}/.env"
load_env_file "${HOME}/.dots.env"

if [ "$SECRETS_FROM_KEYCHAIN" -eq 1 ]; then
  load_keychain_secrets
fi

if [ "$INSTALL_TOOLS" -eq 1 ]; then
  install_node_and_codex
fi

install_file "${DOTS_ROOT}/scripts/opencode-obsidian" "${HOME}/.local/bin/oco" 0755
install_file "${DOTS_ROOT}/scripts/obsidian-open" "${HOME}/.local/bin/obsidian-open" 0755
install_file "${DOTS_ROOT}/scripts/delta-hosts-keychain.sh" "${HOME}/.local/bin/delta-hosts-keychain" 0755

install_file "${DOTS_ROOT}/config/codex/rules/default.rules" "${HOME}/.codex/rules/default.rules"
install_file "${DOTS_ROOT}/config/codex/keybindings.json" "${HOME}/.codex/keybindings.json"
for skill_dir in "${DOTS_ROOT}"/config/codex/skills/*; do
  [ -d "$skill_dir" ] || continue
  install_directory "$skill_dir" "${HOME}/.codex/skills/$(basename "$skill_dir")"
done
for pet_dir in "${DOTS_ROOT}"/config/codex/pets/*; do
  [ -d "$pet_dir" ] || continue
  install_directory "$pet_dir" "${HOME}/.codex/pets/$(basename "$pet_dir")"
done

install_file "${DOTS_ROOT}/config/opencode/package.json" "${HOME}/.config/opencode/package.json"

if [ "$WITH_SECRETS" -eq 1 ]; then
  require_env EXA_API_KEY CONVEX_WRITE_KEY_DEV CONVEX_WRITE_KEY_PROD
  render_codex_config
  render_template "${DOTS_ROOT}/config/opencode/opencode.json.template" "${HOME}/.config/opencode/opencode.json"
else
  render_codex_config
  echo "Skipped OpenCode and secret-bearing integrations. Rerun with --with-secrets to render them."
fi

echo "Install complete."
