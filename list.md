# Setup Checklist

Public-safe checklist for rebuilding the working setup on a new machine. Do not
commit real API keys, deploy keys, private keys, auth files, app histories,
session databases, or generated dependency folders.

## 1. Core Package Manager

- [ ] macOS: install Homebrew from `https://brew.sh`.
- [ ] Linux: use the distro package manager; install Linuxbrew only if needed.
- [ ] Windows: use `winget` first, then vendor installers where needed.

## 2. Core CLI Tools

- [ ] Install Git.
- [ ] Install GitHub CLI: `gh`.
- [ ] Authenticate GitHub: `gh auth login`.
- [ ] Install Node.js 24 or newer. This repo's bootstrap uses Homebrew
  `node@24` for a stable baseline.
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
- [ ] Install .NET SDKs used by local Power Platform and Dataverse work:
  - [ ] active latest/LTS via `dotnet`
  - [ ] 8.x via Homebrew `dotnet@8`
- [ ] Install `uv` for Python tooling.

```bash
brew install uv
```

- [ ] Install Python versions through `uv`:

```bash
uv python install 3.10 3.11 3.12
uv python list
```

- [ ] Install Rust through `rustup` if Rust tooling is needed.

## 3. Shell And Terminal

- [ ] Install Ghostty.
- [ ] Review Ghostty config:
  - [ ] macOS app path:
    `~/Library/Application Support/com.mitchellh.ghostty/config`
  - [ ] portable path, if used: `~/.config/ghostty/config`
- [ ] Confirm `zsh` is the login shell.
- [ ] Confirm shell PATH includes intentional tool bins:
  - [ ] `~/.local/bin`
  - [ ] `~/.bun/bin`
  - [ ] `~/.cargo/bin`
  - [ ] `~/.opencode/bin`
- [ ] Keep manually registered shell commands available:
  - [ ] `mo` / `mole` for Mole disk cleanup
  - [ ] `pac`
  - [ ] `ncode` from the manually cloned/registered ncode repo
- [ ] Install repo-managed shell helpers:

```bash
./scripts/install.sh --skip-tools --force
```

- [ ] Review local shell-only tools with:

```bash
./scripts/audit-machine.sh
```

## 4. Desktop Apps

- [ ] Install Obsidian.
- [ ] Install IINA.
- [ ] Install CodexBar.
- [ ] Install Cursor.
- [ ] Install Visual Studio Code.
- [ ] OpenCode Desktop is optional; the CLI is the required setup target.
- [ ] Install Amphetamine.
- [ ] Install DaVinci Resolve.
- [ ] Install Raycast on macOS.
- [ ] Install Shortcat on macOS.
- [ ] Install Steam.
- [ ] Install Tailscale app.
- [ ] Install UTM.
- [ ] Install JetBrains Toolbox / Hub.

## 5. Obsidian CLI / Vault Workflow

- [ ] Install Obsidian desktop app.
- [ ] Confirm Obsidian URL handling works:

```bash
open "obsidian://open"
```

- [ ] Set `OBSIDIAN_VAULT_PATH` in Keychain, `.env`, or shell environment.

```bash
security add-generic-password -U -s dots -a OBSIDIAN_VAULT_PATH -w "/path/to/vault"
```

- [ ] Install the Obsidian CLI wrappers from this repo:

```bash
./scripts/install.sh --force
```

- [ ] Confirm `obsidian-open` opens the configured vault.
- [ ] Confirm `oco` opens `opencode` in the Obsidian vault.

## 6. Codex And OpenCode Config

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
- [ ] Confirm the tracked Codex skill set includes:
  - [ ] `control-cleanup-orchestrator`
  - [ ] `dependency-hygiene`
  - [ ] `gh-address-comments`
  - [ ] `gh-fix-ci`
  - [ ] `hatch-pet`
  - [ ] `playwright`
  - [ ] `playwright-interactive`
  - [ ] `security-best-practices`
  - [ ] `security-threat-model`
  - [ ] `t3code-branch-sync`
  - [ ] `t3code-release-merge`
- [ ] Confirm OpenCode config exists at `~/.config/opencode/opencode.json`.
- [ ] Do not commit rendered configs with real secrets.
- [ ] After changing local Codex/OpenCode setup, sync public-safe templates back
  into this repo:

```bash
./scripts/sync.sh
./scripts/verify.sh
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

## 7. Tailscale App And Dev Box

- [ ] Install Tailscale app.
- [ ] Sign in.
- [ ] Confirm MagicDNS works.
- [ ] Confirm the dev box is reachable:

```bash
ping delta
```

- [ ] Back up the current `delta` host entry to Keychain:

```bash
./scripts/delta-hosts-keychain.sh backup
./scripts/delta-hosts-keychain.sh status
```

- [ ] Restore the `delta` host entry from Keychain when needed:

```bash
./scripts/delta-hosts-keychain.sh restore
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

Default install flow bootstraps Node 24, uv, and Codex first, then restores public-safe files:

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

- [ ] Run the machine audit:

```bash
./scripts/audit-machine.sh
```

- [ ] Run the public-safety and syntax/config checks:

```bash
./scripts/verify.sh
```

- [ ] Confirm no generated folders are staged:
  - [ ] `.idea`
  - [ ] `node_modules`
  - [ ] `dist`
  - [ ] auth files
  - [ ] history/session databases
