---
name: run-static-gates
description: Run and report the Roblox graybox repository's complete deterministic pre-Studio gate, including formatting, linting, sourcemap generation, strict Luau analysis, Lune tests, whitespace validation, and Rojo build. Use before review, Studio testing, merge, or when diagnosing CI/static-check failures.
---

# Run Static Gates

## Method

1. Read `AGENTS.md` and inspect the worktree so existing changes are understood.
2. Run `./scripts/Checks.ps1` from the repository root.
3. Report each gate as pass or fail. For a failure, cite the first actionable diagnostic and the command that produced it.
4. Do not claim later gates passed if execution stopped early.
5. If definitions or tools are missing, report that `./scripts/Setup.ps1` is required; run setup only when the user also authorizes dependency/setup changes.

## Boundaries

- Do not modify tracked files, format in write mode, install or upgrade dependencies, edit tests, or fix failures.
- Generated files under ignored `build/` are allowed.
- Do not start Studio or publish.

## Exit

Return a concise gate report with the exact failing stage, or confirm the complete gate passed.
