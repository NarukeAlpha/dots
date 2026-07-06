# Codex Profile Instructions

## Editing Workflow

- Use built-in harness tools for file edits.
- Never use Python to create, edit, rewrite, or patch files.
- Prefer `apply_patch` for text changes.
- Use shell commands only for inspection, verification, formatting, tests, and other non-editing tasks.

## Engineering Priorities

- Optimize for performance, reliability, and predictable behavior under failure.
- If a tradeoff is required, choose correctness and robustness over short-term convenience.
- Prefer shared abstractions over copy-pasted local fixes.
- If behavior duplicates existing logic, extract it instead of patching around it.
- Do not be afraid to change existing code when the current shape is the problem.
- Avoid one-off local logic when a cleaner boundary or shared module is the real fix.
- Do not code defensively by default. Prefer strong types, explicit invariants, and simpler control flow over redundant guards and repeated validation.

Use subagents to parallelize independent, well-scoped work when it materially speeds up execution. Keep blocking or tightly coupled work local. When delegating, assign concrete ownership, avoid overlapping edits, and prefer parallel subagents for independent investigation, disjoint code changes, or verification tasks.

## React Diagnostics

- React diagnostics are installed globally with npm: `react-doctor` and `react-scan`.
- For React codebases, prefer repository-defined validation first. Use `react-doctor .` for static React diagnostics when it adds signal; use `react-doctor . --offline` when the scan should stay local.
- Use `react-scan` for runtime render and performance investigation in a running app. Add or initialize it only within the target project when that instrumentation is requested or clearly useful, and do not leave permanent project changes unless they are part of the requested work.

## External Model Reviews

- When asked for a Gemini code review, use `opencode` through the CLI rather than generic Gemini or Google-provider calls.
- Use OpenRouter's Gemini 3.1 Pro custom-tools model: `openrouter/google/gemini-3.1-pro-preview-customtools`.
- Prefer review-only invocations unless the user explicitly asks the external model to edit files. Attach the relevant files with `--file`, include `--` before the prompt so opencode stops parsing files, and keep Codex responsible for applying or rejecting the feedback.

## Validation

- Before considering work complete, run the repository's formatter, linter, typechecker and build when they exist.
- Prefer repository-defined scripts and wrappers over invoking underlying tools directly.
- When a repository documents a required command path for tests or validation, follow that path exactly.
