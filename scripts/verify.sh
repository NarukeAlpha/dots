#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Running public-safety checks..."
"${ROOT}/scripts/check-secrets.sh"

echo "Checking shell script syntax..."
for script in "${ROOT}"/scripts/*.sh; do
  bash -n "$script"
done

if command -v zsh >/dev/null 2>&1; then
  zsh -n "${ROOT}/scripts/obsidian-open"
  zsh -n "${ROOT}/scripts/opencode-obsidian"
else
  echo "Skipping zsh syntax checks because zsh is not installed."
fi

if command -v node >/dev/null 2>&1; then
  echo "Checking JSON config files..."
  node - "${ROOT}" <<'NODE'
const fs = require("fs");
const path = require("path");

const root = process.argv[2];
const files = [
  "config/opencode/opencode.json.template",
  "config/opencode/package.json",
  "personal-setup/extensions/x-sync/package.json",
  "personal-setup/extensions/x-sync/public/manifest.json",
  "personal-setup/extensions/x-sync/tsconfig.json"
];

for (const file of files) {
  JSON.parse(fs.readFileSync(path.join(root, file), "utf8"));
}
NODE
else
  echo "Skipping JSON checks because node is not installed."
fi

if [ -d "${ROOT}/personal-setup/extensions/x-sync/node_modules" ]; then
  echo "Building x-sync extension..."
  npm --prefix "${ROOT}/personal-setup/extensions/x-sync" run build
else
  echo "Skipping x-sync build because dependencies are not installed. Run npm --prefix personal-setup/extensions/x-sync ci to enable it."
fi

echo "Verify passed."
