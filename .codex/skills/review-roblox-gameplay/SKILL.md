---
name: review-roblox-gameplay
description: Independently review a Roblox gameplay slice against its specification, frozen acceptance scenarios, project rules, and diff, with emphasis on server authority, remote validation, reset/replay, lifecycle edge cases, tests, and over-engineering. Use after deterministic checks pass and before Studio testing or merge.
---

# Review Roblox Gameplay

## Method

1. Before reading the diff, read `AGENTS.md`, the specification, and frozen acceptance scenarios. Write a private checklist of expected behavior and required authority/validation.
2. Inspect the diff and run read-only checks as needed.
3. Check correctness, server authority, validation, duplicate/replayed requests, cleanup, reset/replay, respawn, disconnect, late join, test adequacy, and unnecessary architecture.
4. Classify every finding as BLOCKER, MAJOR, MINOR, or NIT. Every blocker must cite the scenario or `AGENTS.md` rule it violates.
5. Write `docs/reviews/<slice>.md` with findings first, then assumptions and the check result. Do not emit a single confidence score.

## Boundaries

- Modify only the target review document.
- Never edit `src/`, `tests/`, acceptance scenarios, configuration, dependencies, branches, or Studio.
- Never fix the code being reviewed. The builder owns fixes within its attempt budget.
- Perform one initial review and one re-review after fixes; unresolved blockers prevent approval.

## Exit

Finish with severity-categorized findings and an explicit disposition: blocked, changes required, or ready for human/Studio validation.
