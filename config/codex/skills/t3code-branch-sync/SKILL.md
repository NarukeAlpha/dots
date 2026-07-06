---
name: t3code-branch-sync
description: Keep the current feature branch up to date with fork origin/main without changing pull request metadata. Use when Codex is asked to pull, merge, or sync latest fork main changes into the currently checked-out branch in a T3 Code worktree or any Git repository, especially when the user wants the branch updated while leaving an existing PR open and otherwise untouched.
---

# T3 Code Branch Sync

Use this workflow to update the currently checked-out branch with the latest fork `origin/main` changes. Treat the current worktree and branch as the target unless the user explicitly names another branch.

## Guardrails

- Do not close, merge, retarget, reopen, mark ready, convert to draft, relabel, assign, edit, or otherwise mutate an existing PR.
- Do not run `gh pr merge`, `gh pr close`, `gh pr edit`, GitHub PR write APIs, or similar PR-mutating commands unless the user explicitly asks.
- Do not rebase, force-push, rename branches, or change branch tracking unless the user explicitly asks.
- Do not push by default. If the user explicitly asks to update the remote PR branch, push only the current branch after checks pass.
- Use the fork remote `origin` and source ref `origin/main` for this workflow. Do not fetch from or merge from `upstream`, `origin/HEAD`, `origin/master`, `origin/trunk`, or any discovered default branch.
- Do not run destructive Git commands such as `git reset --hard`, `git checkout --`, or branch deletion unless the user explicitly asks.
- Do not proceed over unrelated uncommitted user work. If the worktree is dirty before syncing, inspect it and either work around it safely or ask before stashing/committing.

## Workflow

1. Inspect repository instructions first, especially `AGENTS.md`, package scripts, and any required completion checks.
2. Check repository state:
   - `git status --short --branch`
   - `git branch --show-current`
   - `git remote -v`
3. Use the fixed source branch `origin/main`.
   - If an `upstream` remote exists, leave it untouched unless the user gives a separate explicit instruction outside this branch-sync workflow.
   - If `origin/main` is missing, stop and report that the fork main ref is unavailable.
4. Fetch the source branch with an explicit ref: `git fetch origin main`.
5. Merge into the current branch with a normal merge commit path: `git merge --no-edit origin/main`.
6. If conflicts occur:
   - Resolve conflicts by preserving branch-specific behavior and incorporating `origin/main` changes.
   - Prefer structured code understanding over choosing one side wholesale.
   - Search for all conflict markers before marking files resolved.
   - Stage only resolved files with `git add`.
7. Run the repository-required checks from the local instructions. For T3 Code, run `bun fmt`, `bun lint`, and `bun typecheck`. Never run `bun test`; use `bun run test` only when tests are specifically needed.
8. Commit the merge if Git has not already created the merge commit.
9. Report the merged source ref `origin/main`, current branch, conflicts resolved, checks run, and whether the update is local only or pushed.

## Source Ref

The source ref is intentionally fixed:

```bash
git fetch origin main
git merge --no-edit origin/main
```

Do not use `git pull` for this workflow. The explicit fetch and merge sequence makes the fork source ref and merge target clear.

## PR Safety

Keeping a branch current can update the commits shown in an existing PR only if the current branch is pushed. This is acceptable only when the user requested a remote update. Even then, push the branch normally and leave all PR metadata unchanged.
