# Setup Checklist

Public-safe checklist for rebuilding the working setup on a new machine. Do not
commit real API keys, deploy keys, SSH private keys, auth files, app histories,
session databases, or generated dependency folders.

## 1. Core Package Manager

- [ ] macOS: install Homebrew from `https://brew.sh`.
- [ ] Linux: use the distro package manager; install Linuxbrew only if needed.
- [ ] Windows: use `winget` first, then vendor installers where needed.

## 2. Core CLI Tools

- [ ] Install Git.
- [ ] Install GitHub CLI: `gh`.
- [ ] Authenticate GitHub: `gh auth login`.
- [ ] Install Node.js 24.
- [ ] Install Codex CLI with npm: `npm install -g @openai/codex`.
- [ ] Install React diagnostics with npm:

```bash
npm install -g react-doctor@latest react-scan@latest
```

- [ ] Use `react-doctor` for static React codebase diagnostics and
  `react-scan` for runtime render/performance investigation in browser apps.
- [ ] Install OpenCode CLI.
- [ ] Install Bun.
- [ ] Install latest Go.
- [ ] Install `uv` for Python tooling.
- [ ] Install Python versions through `uv`:

```bash
uv python install 3.10 3.11 3.12
uv python list
```

- [ ] Install Rust through `rustup` if Rust tooling is needed.

## 3. Desktop Apps

- [ ] Install Ghostty.
- [ ] Install Obsidian.
- [ ] Install Claude Desktop.
- [ ] Install OpenCode Desktop.
- [ ] Install Raycast on macOS.
- [ ] Install Shortcat on macOS.
- [ ] Install Tailscale.
- [ ] Install JetBrains Toolbox / Hub.

## 4. Obsidian CLI / Vault Workflow

- [ ] Install Obsidian desktop app.
- [ ] Confirm Obsidian URL handling works:

```bash
open "obsidian://open"
```

- [ ] Set `OBSIDIAN_VAULT_PATH` in Keychain, `.env`, or shell environment.
- [ ] Install the `oco` wrapper from this repo:

```bash
./scripts/install.sh --force
```

- [ ] Confirm `oco` opens `opencode` in the Obsidian vault.

## 5. Codex And OpenCode Config

- [ ] Store secrets outside git. Preferred on macOS: Keychain service `dots`.
- [ ] Required Keychain accounts:
  - [ ] `EXA_API_KEY`
  - [ ] `CONVEX_WRITE_KEY_DEV`
  - [ ] `CONVEX_WRITE_KEY_PROD`
- [ ] Render Codex/OpenCode config from templates:

```bash
./scripts/install.sh --secrets-from-keychain --force
```

- [ ] Confirm Codex config exists at `~/.codex/config.toml`.
- [ ] Confirm Codex skills from `config/codex/skills/` exist at
  `~/.codex/skills/`.
- [ ] Confirm OpenCode config exists at `~/.config/opencode/opencode.json`.
- [ ] Do not commit rendered configs with real secrets.
- [ ] After changing local Codex/OpenCode setup, sync public-safe templates back
  into this repo:

```bash
./scripts/sync.sh
./scripts/check-secrets.sh
```

- [ ] Back up OpenCode auth tokens to macOS Keychain service `opencode-auth`:

```bash
./scripts/opencode-auth-keychain.sh backup
./scripts/opencode-auth-keychain.sh status
```

- [ ] On a new Mac, restore OpenCode auth only when you trust the machine:

```bash
./scripts/opencode-auth-keychain.sh restore
```

## 6. SSH Keys

- [ ] Prefer a fresh SSH key per machine unless a specific key must be reused.
- [ ] Store SSH key passphrases in macOS Keychain:

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

- [ ] Do not store raw private SSH keys in this public repo.
- [ ] If a private key must be backed up, use an encrypted backup instead of git:
  encrypted disk image, hardware-backed password manager, `age`, or equivalent.
- [ ] Add public keys to GitHub as needed.

## 7. Tailscale And Dev Box

- [ ] Install Tailscale.
- [ ] Sign in.
- [ ] Confirm MagicDNS works.
- [ ] Confirm the dev box is reachable:

```bash
ping delta
```

- [ ] If local host mapping is still needed, add:

```text
100.67.176.2 delta
```

to `/etc/hosts`.

## 8. Repositories

- [ ] Clone personal blog:

```bash
gh repo clone NarukeAlpha/blog
```

- [ ] Clone or install `research-publish` MCP server:

```bash
gh repo clone NarukeAlpha/RP-MCP ~/.local/share/rp-mcp
```

- [ ] Clone `ani-cli`:

```bash
gh repo clone pystardust/ani-cli
```

## 9. Install Script Usage

Default install flow bootstraps Node 24 and Codex first, then restores public-safe files:

```bash
./scripts/install.sh
```

Skip Node/Codex bootstrap when only restoring files:

```bash
./scripts/install.sh --skip-tools
```

Restore configs using Keychain secrets:

```bash
./scripts/install.sh --secrets-from-keychain --force
```

Use `.env` / `~/.dots.env` instead of Keychain:

```bash
./scripts/install.sh --with-secrets --force
```

## 10. Public Repo Check

- [ ] Run the secret/public-safety check:

```bash
./scripts/check-secrets.sh
```

- [ ] Confirm no generated folders are staged:
  - [ ] `.claude`
  - [ ] `.idea`
  - [ ] `node_modules`
  - [ ] `dist`
  - [ ] auth files
  - [ ] history/session databases
  - [ ] SSH private keys
