# dots

Public-safe setup files for this Mac.

This repo intentionally excludes private machine state, auth files, API keys,
logs, history, session databases, `node_modules`, build output, and Claude
configuration.

## Contents

- `config/codex/`: Codex config template and rules.
- `config/opencode/`: OpenCode config template and package metadata.
- `list.md`: living inventory of commands, configs, software, and clean-machine
  install targets.
- `scripts/install.sh`: bootstraps Node.js 24 and Codex CLI, then installs the
  setup onto a machine with backups.
- `scripts/sync.sh`: reads local Codex/OpenCode setup and refreshes public-safe
  templates in this repo.
- `scripts/opencode-auth-keychain.sh`: backs up/restores OpenCode auth through
  macOS Keychain without printing values.
- `scripts/check-secrets.sh`: checks for obvious leaked secret values before
  publishing.

## Install

Default install flow:

```bash
./scripts/install.sh
```

To skip Node/Codex bootstrap:

```bash
./scripts/install.sh --skip-tools
```

For Codex/OpenCode MCP config, provide secrets through environment variables,
`.env`, or `~/.dots.env`:

```bash
cp .env.example .env
$EDITOR .env
./scripts/install.sh --with-secrets
```

On macOS, prefer Keychain:

```bash
./scripts/install.sh --secrets-from-keychain
```

To refresh templates from the current machine:

```bash
./scripts/sync.sh
./scripts/check-secrets.sh
```

To back up OpenCode auth into Keychain:

```bash
./scripts/opencode-auth-keychain.sh backup
```

Existing files are backed up to `~/.dots-backups/<timestamp>/`.

## Public Repo Check

Run this before pushing:

```bash
./scripts/check-secrets.sh
```
