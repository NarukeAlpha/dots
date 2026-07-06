---
name: t3code-release-merge
description: Release-branch integration workflow for NarukeAlpha/t3code-ide. Use when Codex is asked to sync the T3 Code fork's release branch with fork origin/main, merge open feature PR branches into release without closing those PRs, resolve merge conflicts across package actions, GitHub integration, database connections, or similar feature branches, verify repo gates, push release, or manage/rename the related feature branches safely.
---

# T3Code Release Merge

## Purpose

Use this skill to integrate selected feature PR heads into `release` for `NarukeAlpha/t3code-ide` while keeping the feature work reviewable separately. The expected pattern is: sync `release` from the fork's `origin/main`, merge PR head branches into `release`, resolve conflicts compositionally, run required gates, then push `release`.

## Safety Rules

- Never assume a PR is still open after branch operations. Verify with GitHub.
- Do not merge PRs into `main` unless the user explicitly asks.
- Do not close PRs while preparing `release`.
- Do not delete PR head branches unless the user explicitly asks.
- Do not use GitHub's branch-rename API on open PR head branches when the user wants the original PRs to remain open. In this repo, renaming PR head branches closed the original PRs.
- Use the fork remote `origin` as the release base source. Do not fetch from, merge from, or otherwise sync against an `upstream` remote as part of this workflow.
- Prefer merging the exact PR head refs reported by GitHub over similarly named local branches.
- If a local branch exists with a similar name but a different SHA, treat it as unrelated until proven otherwise.
- Keep the worktree clean between merge steps. Commit each completed merge before starting the next.
- Never run `bun test`; use `bun run test` only when targeted tests are needed.

## Standard Workflow

1. Inspect repo state.
   - Run `git status -sb`.
   - Run `git remote -v`.
   - Confirm current branch and dirty files. If unrelated dirty files exist, do not overwrite them.

2. Identify PR head branches from GitHub.
   - Use GitHub PR metadata, not memory.
   - Record PR number, base branch, head branch, and head SHA.
   - For the current feature split, the branch intent is:
     - Project actions/package scripts: `feature/project-actions-package-scripts`
     - Database connections: `feature/database-connections`
     - Git/GitHub integration: `feature/git-github-integration`

3. Sync refs.
   - Run `git fetch origin --prune`.
   - Confirm `origin/main` is the fork main branch before using it as the release base.
   - If an `upstream` remote exists, leave it untouched unless the user gives a separate explicit instruction outside this release-merge workflow.

4. Prepare `release`.
   - Switch to `release`.
   - If local `release` does not exist, create it from `origin/release`.
   - Merge `origin/main` into `release` with `--no-ff --no-edit` unless a fast-forward is explicitly required.

5. Merge feature PR heads one at a time.
   - Recommended order for this repo:
     - Package actions/scripts first.
     - Git/GitHub integration second.
     - Database connections third.
   - After each `git merge --no-ff --no-edit <head-ref>`, resolve conflicts, run `git diff --check`, stage only the resolved files, then `git commit --no-edit`.

6. Resolve conflicts compositionally.
   - Preserve both feature additions when they touch shared seams.
   - Do not take either side wholesale unless the other side is obsolete.
   - Shared conflict hotspots usually include:
     - `packages/contracts/src/ipc.ts`
     - `packages/contracts/src/rpc.ts`
     - `packages/contracts/src/index.ts`
     - `apps/server/src/ws.ts`
     - `apps/server/src/server.ts`
     - `apps/web/src/environmentApi.ts`
     - `apps/web/src/rpc/wsRpcClient.ts`
     - `apps/web/src/components/ChatView.tsx`
     - `apps/web/src/components/chat/ChatHeader.tsx`

7. Run gates.
   - Run `bun fmt`.
   - Run `bun lint`.
   - Run `bun typecheck`.
   - Run targeted `bun run test ...` only when the change/risk warrants it.
   - Do not call the task done until the required gates pass or a blocker is clearly reported.

8. Push release.
   - Confirm `git status -sb` is clean.
   - Confirm `git rev-list --left-right --count origin/release...release`.
   - Push with `git push origin release`.
   - Verify `release` is even with `origin/release`.

## Conflict Playbook

### Contracts

When `packages/contracts/src/ipc.ts` conflicts, keep all additive API groups. The expected shape may need all of:

- `projects.listDetectedScripts`
- `git.getRecentGraph`
- `github.*`
- `database.*`

Keep imports grouped by source module and remove duplicate imports from the same module.

### Server Runtime Layers

When `apps/server/src/server.ts` conflicts:

- Keep current base provider/runtime layer changes from `origin/main`.
- Add feature layers through narrow additive seams.
- If `Layer.mergeAll(...)` exceeds typed arity, split the composition into two layer constants rather than weakening types.
- Keep `TextGenerationLive` if the current base replaced older routing text-generation files.

### WebSocket Routing

When `apps/server/src/ws.ts` conflicts:

- Keep all active services yielded from the environment layer.
- Keep all RPC handlers for merged features.
- Preserve base error-handling fixes when composing feature handlers.

### Migrations

When a feature branch adds a migration number that collides with the `origin/main` base:

- Do not overwrite migrations already present on `origin/main`.
- Rename the feature migration to the next unused number.
- Update `apps/server/src/persistence/Migrations.ts` import and `migrationEntries`.
- Rename the migration file itself so history is deterministic.

Example from the release merge:

- Database branch added `026_ProjectDatabaseConnections.ts`.
- Upstream already had `026`, `027`, and `028`.
- The database migration was renamed to `029_ProjectDatabaseConnections.ts`.

### Chat Route And Panels

When database and diff/right-panel code conflict:

- Preserve diff route semantics and existing `diff` search param behavior.
- Keep database panel state client-side unless the feature explicitly persisted it.
- Use shared right-panel shell logic where possible instead of duplicating sidebar behavior.

### Project Actions

When action execution conflicts:

- Prefer the shared project action runner hook over duplicated terminal-launch logic.
- Keep detected package scripts separate from saved actions.
- Ensure saved actions still use persisted `ProjectScript` data.

### GitHub Integration

When Git/GitHub conflicts:

- Keep local Git graph APIs under `git`.
- Keep GitHub PR/check/comment/review APIs under `github`.
- Preserve unsupported-host and missing-auth handling.
- Do not parse human-readable `gh` output when structured output exists.

## Branch Rename Rules

Branch renaming is separate from release merging and is riskier than it looks.

If the user asks to rename feature branches:

1. Warn that renaming the head branch of an open GitHub PR can close the PR.
2. Prefer creating a new branch from the same SHA and opening a replacement PR if the user accepts replacement PR numbers.
3. If the user requires the same PR numbers to stay open, do not rename the open PR head branches through GitHub. Keep old branch names or ask the user to rename through GitHub UI only after confirming behavior.
4. After any rename/replacement, verify PR state with GitHub and report exact PR numbers.

In the observed repo event:

- Renaming open PR head branches with GitHub's branch rename endpoint closed PRs #2, #3, and #4.
- Replacement PRs were opened:
  - #5: `Project actions and package scripts`, head `feature/project-actions-package-scripts`
  - #6: `Database connections workspace`, head `feature/database-connections`
  - #7: `Git and GitHub repository integration`, head `feature/git-github-integration`
- Comments were added to old PRs pointing to replacements.

## Verification Checklist

Before reporting completion:

- `git status -sb` is clean.
- `release` points at the intended final merge commit.
- `origin/release` has been pushed if the user asked for remote release update.
- `bun fmt` passed.
- `bun lint` passed.
- `bun typecheck` passed.
- Any lint/typecheck warnings are distinguished from fatal errors.
- Open PR states are verified directly on GitHub if PR preservation was part of the task.
- If replacement PRs were created, report old PR numbers and new PR numbers explicitly.

## Useful Commands

```bash
git status -sb
git fetch origin --prune
git switch release
git merge --no-ff --no-edit origin/main
git merge --no-ff --no-edit origin/feature/project-actions-package-scripts
git merge --no-ff --no-edit origin/feature/git-github-integration
git merge --no-ff --no-edit origin/feature/database-connections
git diff --check
bun fmt
bun lint
bun typecheck
git push origin release
```

Use GitHub metadata tools or `gh pr view` to verify PR state and exact head refs before and after branch operations.
