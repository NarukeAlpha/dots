# dots

Public-safe setup files for this Mac: config templates, selected Codex skills,
small helper scripts, lockfiles, and source for small personal setup tools.

Keep out secrets, rendered auth/config state, logs, histories, generated output,
vendored dependencies, broad notes, and temporary project material.

## Contents

- `config/codex/`: Codex config template, rules, and installable skills.
- `config/opencode/`: OpenCode template and package metadata.
- `personal-setup/extensions/x-sync/`: Chrome extension source; no `dist/` or
  `node_modules/`.
- `scripts/`: install, sync, audit, verify, Keychain, Obsidian, and hosts
  helpers.
- `list.md`: clean-machine setup checklist.

## Commands

```bash
./scripts/install.sh
./scripts/install.sh --skip-tools
./scripts/install.sh --secrets-from-keychain --force

./scripts/sync.sh
./scripts/audit-machine.sh
./scripts/verify.sh
```

Use `.env`, `~/.dots.env`, or macOS Keychain service `dots` for template
secrets. Existing installed files are backed up to `~/.dots-backups/<timestamp>/`
before replacement.

## Checks

Run before pushing:

```bash
./scripts/verify.sh
```
