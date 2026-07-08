---
name: control-cleanup-orchestrator
description: Orchestrates Control cleanup and refactor plans into staged, validated batches with clear subagent ownership. Use when the user mentions cleanup.md, cleanup part 2/3, App.tsx or RepositoryPage decomposition, prop collapse, query ownership, deep module extraction, or asks to use subagents for Control refactors.
metadata:
  short-description: Orchestrate Control cleanup refactors
---

# Control Cleanup Orchestrator

## Quick start

Use this for large Control cleanup/refactor work where the user wants staged implementation, subagents, or a plan translated into vertical slices.

1. Confirm the repo/worktree, branch, and plan file with `pwd`, `git status --short --branch`, and `rg --files | rg 'cleanup|AGENTS|package.json'`.
2. Read the local instructions, the cleanup plan, and the specific files named by the user before making claims.
3. Identify the current blocking local task and the independent sidecar tasks that can safely be delegated.
4. Split work by ownership boundary, not by file count. Prefer one route, tab, store, provider slice, or IPC boundary per batch.
5. Run the repo-defined gates after each integrated batch, usually `bun run typecheck`, `bun run lint`, `bun run test`, and final `bun run format` when the repo documents them.

## Batch rules

- Preserve Control's provider seams: GitHub, local paths, SSH/local areas, and future VCS providers must stay first-class.
- Do not turn a deep-module extraction into a prop-bundle move. The destination module should own state, queries, prefetch, refresh, or callbacks that naturally belong there.
- Keep tokens and privileged provider work in the main process. Renderer work should use typed IPC or existing hooks.
- In a dirty worktree, assume other edits are intentional. Do not revert them; integrate around them.
- For each batch, state: owned files, non-owned files, expected imports to adjust, validation commands, and rollback risk.

## Subagent use

Only spawn subagents when the user has asked for subagents or parallel agent work. Use built-in `explorer` for read-only codebase questions and `worker` for bounded edits. Give every worker a disjoint write scope and include:

```text
You are not alone in the codebase. Do not revert or overwrite other edits; adjust to current state.
Work only in <repo>. Own only <files/modules>. Do not edit <conflict scopes>.
Task: <one concrete slice>.
Return changed files, validation run, and remaining gaps.
```

Good recurring briefs:

- **Repository tab explorer**: audit App.tsx/RepositoryPage for tab query ownership, warm prefetch, refresh paths, query keys, and smallest next tab slice.
- **Route surface explorer**: audit collection, organizations, areas, command palette, file finder, or shell event bridge surfaces for line anchors and safest extraction order.
- **Worker slice**: implement one tab/route/store/provider extraction with focused tests and minimal App.tsx wiring.
- **Verification worker**: after integration, run focused tests and report failing files, exact errors, and likely owner module.

## Finish criteria

Finish with changed files, validation results, remaining cleanup gaps, and the next 1-3 highest-leverage low-conflict slices. Avoid pasting broad plan text back to the user unless they ask for a full report.
