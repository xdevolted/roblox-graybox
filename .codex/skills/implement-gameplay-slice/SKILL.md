---
name: implement-gameplay-slice
description: Implement exactly one approved Roblox gameplay slice with engine-free Lune tests, server-authoritative adapters, and deterministic checks. Use when a feature specification, frozen acceptance scenarios, and an approved slice plan already exist and code changes are requested.
---

# Implement Gameplay Slice

## Method

1. Read `AGENTS.md`, the approved feature docs, target ticket, and current branch/diff.
2. Confirm the branch is `feature/<slice>`, the requested slice is unambiguous, and no unrelated user changes would be overwritten.
3. Implement only that slice. Put engine-free rules in `src/shared/`; isolate Instances and services in server/client adapters.
4. Keep outcomes server-authoritative. Validate client type, range, ownership, context, permission, and frequency at the boundary.
5. Add or update `*.spec.luau` coverage for transitions, rejection paths, cleanup, and reset/replay relevant to the slice.
6. Run `./scripts/Checks.ps1`. Fix only failures caused by the slice.
7. Summarize the diff, tests, risk tier, attempts used, and any required Studio scenarios.

## Boundaries

- Modify only files required by the approved slice in `src/`, `tests/`, and its ticket/failure report.
- Never weaken or rewrite frozen acceptance scenarios to make code pass.
- Never publish, migrate data, change permissions, modify monetization/economy, force-push `main`, or perform unrelated refactors.
- Low risk: at most three attempts. Medium gameplay authority/remotes: two. High persistence/economy/release security: stop after one failed attempt and escalate.

## Exit

Finish when the slice and tests are complete, `Checks.ps1` passes, and the change is ready for an independent reviewer. On budget exhaustion, stop with a structured failure report instead of continuing.
