---
name: dependency-hygiene
description: Audits runtime dependencies, explains necessity and risk, and applies pinning or removal decisions for JavaScript and TypeScript projects. Use when the user asks about dependencies, package.json, version pinning, vulnerable packages, dependency reports, or whether dependencies are necessary.
metadata:
  short-description: Audit and pin runtime dependencies
---

# Dependency Hygiene

## Quick start

Use this when the user wants a practical dependency report or a dependency cleanup/pinning change.

1. Inspect package manager files first: `package.json`, lockfiles, workspace configs, and repo scripts.
2. Separate runtime dependencies from dev dependencies unless the user explicitly asks for both.
3. Map each direct runtime dependency to evidence of use with `rg`, imports, build config, and package scripts.
4. Report each dependency as keep, question, replace, or remove. Give the reason, not just the package name.
5. If the user asks for exact pinning, remove semver ranges from direct runtime dependencies and update the lockfile with the repo's package manager.

## Report shape

For each runtime dependency include:

- package and current version/range
- what imports or config use it
- why it exists in the product
- whether it is runtime-critical, optional, replaceable, or unused
- pinning/removal recommendation

For security concerns, prefer the repo's audit command or package-manager audit. Treat network audit data as current-at-run-time and separate vulnerability findings from general dependency bloat.

## Edit rules

- Do not remove a package from `package.json` unless import/config evidence supports removal or the user explicitly accepts the risk.
- Pin only direct runtime dependencies when that is the request; avoid churn in dev dependencies unless asked.
- Preserve the package manager already used by the repo.
- After edits, run the repo-defined install/lockfile update, typecheck, lint, and tests when available.

## Finish criteria

Finish with the dependency decisions, changed files, lockfile status, and validation commands. Call out packages that still need human product judgment.
