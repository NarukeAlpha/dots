#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

section() {
  printf '\n## %s\n' "$1"
}

command_status() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf 'present\t%s\t%s\n' "$cmd" "$(command -v "$cmd")"
  else
    printf 'missing\t%s\t-\n' "$cmd"
  fi
}

app_status() {
  local name="$1"
  local found=0
  local dir

  for dir in /Applications "$HOME/Applications" "$HOME/Documents"; do
    if [ -d "$dir/$name.app" ]; then
      printf 'present\t%s\t%s\n' "$name" "$dir/$name.app"
      found=1
      break
    fi
  done

  if [ "$found" -eq 0 ]; then
    printf 'missing\t%s\t-\n' "$name"
  fi
}

path_status() {
  local path="$1"
  if [ -e "$path" ]; then
    printf 'present\t%s\n' "$path"
  else
    printf 'missing\t%s\n' "$path"
  fi
}

toml_value() {
  local file="$1"
  local key="$2"
  if [ ! -f "$file" ]; then
    printf 'missing\n'
    return
  fi

  awk -F= -v key="$key" '
    {
      lhs = $1
      gsub(/^[ \t]+|[ \t]+$/, "", lhs)
      if (lhs == key) {
        rhs = $0
        sub(/^[^=]*=/, "", rhs)
        gsub(/^[ \t]+|[ \t]+$/, "", rhs)
        gsub(/^"|"$/, "", rhs)
        print rhs
        found = 1
        exit
      }
    }
    END {
      if (!found) {
        print "missing"
      }
    }
  ' "$file"
}

keychain_status() {
  local service="$1"
  local account="$2"

  if [ "$(uname -s)" != "Darwin" ] || ! command -v security >/dev/null 2>&1; then
    printf 'unknown\t%s\t%s\n' "$service" "$account"
    return
  fi

  if security find-generic-password -s "$service" -a "$account" >/dev/null 2>&1; then
    printf 'present\t%s\t%s\n' "$service" "$account"
  else
    printf 'missing\t%s\t%s\n' "$service" "$account"
  fi
}

section "System"
uname -a
sw_vers 2>/dev/null || true
printf 'shell\t%s\n' "${SHELL:-unknown}"

section "CLI Tools"
for cmd in brew git gh node npm npx codex react-doctor react-scan opencode bun go dotnet uv uvx rustup rustc cargo mo mole pac ncode code cursor zsh security; do
  command_status "$cmd"
done

section "Versions"
for cmd in brew git gh node npm npx codex react-doctor react-scan opencode bun rustup rustc cargo; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '\n%s\n' "$cmd"
    "$cmd" --version 2>&1 | sed -n '1,4p'
  fi
done
if command -v mo >/dev/null 2>&1; then
  printf '\nmo\n'
  mo --version 2>&1 | sed -n '1,8p'
fi
if command -v go >/dev/null 2>&1; then
  printf '\ngo\n'
  go version
fi

if command -v dotnet >/dev/null 2>&1; then
  printf '\ndotnet\n'
  dotnet --version
  dotnet --list-sdks
fi
if [ -x /opt/homebrew/opt/dotnet@8/bin/dotnet ]; then
  printf '\ndotnet@8\n'
  DOTNET_ROOT=/opt/homebrew/opt/dotnet@8/libexec /opt/homebrew/opt/dotnet@8/bin/dotnet --version
  DOTNET_ROOT=/opt/homebrew/opt/dotnet@8/libexec /opt/homebrew/opt/dotnet@8/bin/dotnet --list-sdks
fi

if command -v uv >/dev/null 2>&1; then
  section "UV Python"
  uv python list | grep -v '<download available>' || true
fi

section "Desktop Apps"
for app in Ghostty Obsidian IINA CodexBar Cursor "Visual Studio Code" OpenCode Amphetamine "DaVinci Resolve" Raycast Shortcat Steam Tailscale UTM "JetBrains Toolbox" "JetBrains Hub"; do
  app_status "$app"
done

section "Installed Config"
path_status "$HOME/.codex/config.toml"
path_status "$HOME/.codex/rules/default.rules"
path_status "$HOME/.codex/keybindings.json"
path_status "$HOME/.config/opencode/opencode.json"
path_status "$HOME/.config/opencode/package.json"
path_status "$HOME/.local/bin/oco"
path_status "$HOME/.local/bin/obsidian-open"
path_status "$HOME/.local/bin/delta-hosts-keychain"
path_status "$HOME/.local/share/opencode/auth.json"

section "Codex Permission Mode"
for key in approval_policy sandbox_mode; do
  printf 'repo\t%s\t%s\n' "$key" "$(toml_value "$ROOT/config/codex/config.toml.template" "$key")"
  printf 'installed\t%s\t%s\n' "$key" "$(toml_value "$HOME/.codex/config.toml" "$key")"
done

section "Keychain Entries"
keychain_status dots EXA_API_KEY
keychain_status dots CONVEX_WRITE_KEY_DEV
keychain_status dots CONVEX_WRITE_KEY_PROD
keychain_status dots OBSIDIAN_VAULT_PATH
keychain_status dots DELTA_HOSTS_ENTRY
keychain_status opencode-auth auth.json

section "Codex Skills"
printf 'repo\t%s\n' "$(find "$ROOT/config/codex/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | /usr/bin/wc -l | /usr/bin/tr -d ' ')"
printf 'installed\t%s\n' "$(find "$HOME/.codex/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | /usr/bin/wc -l | /usr/bin/tr -d ' ')"
find "$HOME/.codex/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
  sed "s#^$HOME/.codex/skills/##" |
  grep -vi 'claude' |
  sort

section "Codex Keybindings"
path_status "$ROOT/config/codex/keybindings.json"
path_status "$HOME/.codex/keybindings.json"

section "Codex Pets"
printf 'repo\t%s\n' "$(find "$ROOT/config/codex/pets" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | /usr/bin/wc -l | /usr/bin/tr -d ' ')"
printf 'installed\t%s\n' "$(find "$HOME/.codex/pets" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | /usr/bin/wc -l | /usr/bin/tr -d ' ')"
find "$HOME/.codex/pets" -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
  sed "s#^$HOME/.codex/pets/##" |
  sort

section "Shell Local Bin"
if [ -d "$HOME/.local/bin" ]; then
  find "$HOME/.local/bin" -mindepth 1 -maxdepth 1 ! -iname '*claude*' -print |
    sed "s#^$HOME/.local/bin/##" |
    sort
else
  echo "missing ~/.local/bin"
fi

section "Shell Config"
for file in "$HOME/.zshenv" "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.config/ghostty/config" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"; do
  path_status "$file"
done

section "Expected Repositories"
path_status "$HOME/IdeaProjects/blog"
path_status "$HOME/.local/share/rp-mcp"
path_status "$HOME/ani-cli"
path_status "$HOME/Documents/ani-cli"
path_status "$HOME/IdeaProjects/ani-cli"

section "Tailscale App And Dev Box"
app_status Tailscale
if [ -r /etc/hosts ]; then
  grep -nE '^[^#].*[[:space:]]delta([[:space:]]|$)' /etc/hosts || echo "missing /etc/hosts delta entry"
fi
ping -c 1 -W 1000 delta 2>&1 || true
