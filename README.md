# dots

Public-safe dotfiles and setup scripts for a macOS development environment.

It keeps the pieces used to recreate or audit the setup: config templates,
helper scripts, selected Codex skills, lockfiles, and source for small local
tools.

## What Is Included

- `config/codex/`: Codex config templates, rules, and installable skills.
- `config/opencode/`: OpenCode config template and package metadata.
- `personal-setup/extensions/x-sync/`: source for a small Chrome extension.
- `scripts/`: bootstrap, sync, audit, verification, Keychain, Obsidian, and
  hosts helpers.
- `list.md`: checklist for rebuilding the environment on a clean machine.

## Usage

Review scripts before running them on a new machine.

```bash
./scripts/install.sh
```

Common variants:

```bash
./scripts/install.sh --skip-tools
./scripts/install.sh --secrets-from-keychain --force
```

Refresh public-safe templates from the current machine:

```bash
./scripts/sync.sh
```

Audit the local machine against the checklist:

```bash
./scripts/audit-machine.sh
```

Run checks:

```bash
./scripts/verify.sh
```
