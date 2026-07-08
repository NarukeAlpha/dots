#!/usr/bin/env bash
set -euo pipefail

DOTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: scripts/sync.sh

Reads local Codex/OpenCode setup and writes public-safe templates back into this
repo. Secret values are replaced with placeholders. Generated state, auth files,
logs, histories, caches, and Claude config are not copied.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

sanitize_codex_config() {
  local source="${HOME}/.codex/config.toml"
  local target="${DOTS_ROOT}/config/codex/config.toml.template"
  local tmp

  if [ ! -f "$source" ]; then
    echo "Skipping missing $source"
    return 0
  fi

  mkdir -p "$(dirname "$target")"
  tmp="$(mktemp)"

  perl -pe '
    BEGIN { $home = quotemeta($ENV{HOME}); }
    s#$home#__HOME__#g;
    s#(EXA_API_KEY\s*=\s*")[^"]*(")#$1__EXA_API_KEY__$2#g;
    s#(CONVEX_WRITE_KEY\s*=\s*")[^"]*(")#$1__CONVEX_WRITE_KEY_PROD__$2#g;
  ' "$source" > "$tmp"

  awk '
    function should_skip_section(line) {
      return line ~ /^\[marketplaces\./ ||
        line ~ /^\[mcp_servers\.node_repl(\.env)?\]/ ||
        line ~ /^\[mcp_servers\.robinhood\]/
    }
    /^notify[[:space:]]*=/ { next }
    /^\[projects\./ {
      if ($0 == "[projects.\"__HOME__\"]" || $0 == "[projects.\"/\"]") {
        skip = 0
        print
        next
      }
      skip = 1
      next
    }
    /^\[/ {
      if (should_skip_section($0)) {
        skip = 1
        next
      }
      skip = 0
    }
    !skip { print }
  ' "$tmp" > "$target"

  rm -f "$tmp"
  echo "Synced $target"
}

sanitize_opencode_config() {
  local source="${HOME}/.config/opencode/opencode.json"
  local target="${DOTS_ROOT}/config/opencode/opencode.json.template"

  if [ ! -f "$source" ]; then
    echo "Skipping missing $source"
    return 0
  fi

  mkdir -p "$(dirname "$target")"
  node - "$source" "$target" <<'NODE'
const fs = require("fs");
const [source, target] = process.argv.slice(2);
const home = process.env.HOME;
const config = JSON.parse(fs.readFileSync(source, "utf8"));

function walk(value) {
  if (typeof value === "string") {
    return value.split(home).join("__HOME__");
  }
  if (Array.isArray(value)) {
    return value.map(walk);
  }
  if (value && typeof value === "object") {
    for (const key of Object.keys(value)) {
      value[key] = walk(value[key]);
    }
  }
  return value;
}

walk(config);

if (config.mcp?.exa?.environment) {
  config.mcp.exa.environment.EXA_API_KEY = "__EXA_API_KEY__";
}
if (config.mcp?.rp_dev?.environment) {
  config.mcp.rp_dev.environment.CONVEX_WRITE_KEY = "__CONVEX_WRITE_KEY_DEV__";
}
if (config.mcp?.rp_prod?.environment) {
  config.mcp.rp_prod.environment.CONVEX_WRITE_KEY = "__CONVEX_WRITE_KEY_PROD__";
}

fs.writeFileSync(target, JSON.stringify(config, null, 2) + "\n");
NODE
  echo "Synced $target"
}

sync_file_if_present() {
  local source="$1"
  local target="$2"
  if [ -f "$source" ]; then
    mkdir -p "$(dirname "$target")"
    cp "$source" "$target"
    echo "Synced $target"
  else
    echo "Skipping missing $source"
  fi
}

sync_directory_if_present() {
  local source="$1"
  local target="$2"
  if [ -d "$source" ]; then
    rm -rf "$target"
    mkdir -p "$(dirname "$target")"
    cp -pR "$source" "$target"
    echo "Synced $target"
  else
    echo "Skipping missing $source"
  fi
}

sanitize_codex_config
sync_file_if_present "${HOME}/.codex/rules/default.rules" "${DOTS_ROOT}/config/codex/rules/default.rules"
sync_file_if_present "${HOME}/.codex/keybindings.json" "${DOTS_ROOT}/config/codex/keybindings.json"
for skill_dir in "${DOTS_ROOT}"/config/codex/skills/*; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  sync_directory_if_present "${HOME}/.codex/skills/$skill_name" "${DOTS_ROOT}/config/codex/skills/$skill_name"
done
if [ -d "${HOME}/.codex/pets" ]; then
  rm -rf "${DOTS_ROOT}/config/codex/pets"
  mkdir -p "${DOTS_ROOT}/config/codex/pets"
  find "${HOME}/.codex/pets" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r pet_dir; do
    pet_name="$(basename "$pet_dir")"
    mkdir -p "${DOTS_ROOT}/config/codex/pets/$pet_name"
    sync_file_if_present "$pet_dir/pet.json" "${DOTS_ROOT}/config/codex/pets/$pet_name/pet.json"
    sync_file_if_present "$pet_dir/spritesheet.webp" "${DOTS_ROOT}/config/codex/pets/$pet_name/spritesheet.webp"
  done
  echo "Synced ${DOTS_ROOT}/config/codex/pets"
else
  echo "Skipping missing ${HOME}/.codex/pets"
fi

sanitize_opencode_config
sync_file_if_present "${HOME}/.config/opencode/package.json" "${DOTS_ROOT}/config/opencode/package.json"
sync_file_if_present "${HOME}/.config/opencode/package-lock.json" "${DOTS_ROOT}/config/opencode/package-lock.json"
sync_file_if_present "${HOME}/.config/opencode/bun.lock" "${DOTS_ROOT}/config/opencode/bun.lock"

echo "Sync complete. Run scripts/check-secrets.sh before committing."
