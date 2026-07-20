---
name: plan-gameplay-slice
description: Turn an approved Roblox feature specification and frozen acceptance scenarios into the smallest ordered behavioral slices, test strategy, affected boundaries, and risks. Use after specification approval and before implementation, or when an existing feature plan must be revised without writing gameplay code.
---

# Plan Gameplay Slice

## Method

1. Read `AGENTS.md`, the feature specification, frozen acceptance scenarios, open questions, and relevant source/tests.
2. Refuse to plan around unresolved product questions that would materially change behavior.
3. Re-derive the required behavior and divide it into small, independently verifiable slices. Prefer this order:
   - Engine-free rules/state and Lune tests.
   - Server-authoritative Roblox adapter and request validation.
   - Client input and temporary feedback.
   - Multiplayer hardening only when shared state requires it.
4. For each slice, state behavior, files or subsystem boundaries, dependencies, tests, risk tier, attempt budget, and exit evidence.
5. Write `docs/features/<feature>/plan.md`. Update `open-questions.md` only when planning discovers a real ambiguity.

## Boundaries

- Modify only the target feature's `plan.md` and `open-questions.md`.
- Never change frozen acceptance scenarios, production code, tests, configuration, dependencies, Git state, or Studio.
- Do not introduce frameworks, broad refactors, persistence, economy, or multi-place work without an approved demonstrated need.
- Use three attempts for low risk, two for medium risk, and one for high risk; escalate rather than expanding scope.

## Exit

Finish when the first slice is implementable without further design choices and later slices are ordered with explicit gates.
