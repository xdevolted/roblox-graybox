# Repo-local skill operational validation

**Workflow exercised:** First-playable specification and `TCK-0001`

**Validation date:** 2026-07-20

**Promotion status:** Repo-local only. No skill was copied or promoted to a user-level/global location.

## specify-roblox-feature

- Trigger: used for the owner-supplied Graybox Survival Platform concept before planning or implementation.
- Write boundary: changed only `GAME_SPEC.md`, `CORE_LOOP.md`, and `docs/features/first-playable/` Markdown files.
- Prohibited actions: did not touch source, tests, configuration, dependencies, Studio, publishing, persistence, economy, or product decisions not supplied by the owner.
- Attempt budget: completed in one specification pass out of the allowed two.
- Required output: produced the game spec, core loop, first-playable behavior/non-goals, ten Given/When/Then scenarios, reset/replay, invalid request, disconnect, late join, proposed slices, and explicit open questions.
- Exit and escalation: stopped before freezing at three material product decisions, presented them to the owner, and resumed only after the owner approved independent rounds, immediate server-confirmed safe-zone success, and immediate independent late-join rounds.
- Result: scenarios were frozen without unresolved material questions.

## plan-gameplay-slice

- Trigger: used only after the owner-approved acceptance scenarios were frozen.
- Write boundary: created only `docs/features/first-playable/plan.md`; the orchestrator separately created the schema-conforming ticket.
- Prohibited actions: did not change frozen scenarios, source, tests, configuration, dependencies, Git state, Studio, or deferred infrastructure.
- Attempt budget: assigned the approved three-attempt low-risk budget to `TCK-0001` and explicit two-attempt medium-risk budgets to later adapter slices.
- Required output: defined state representation, valid and invalid transitions, start/success/failure/reset/replay behavior, deterministic cases, exclusions, dependencies, risks, exit evidence, and ordered later slices.
- Exit and escalation: completed in one pass with the first slice implementable without invention and no new ambiguity to escalate.
- Result: `TCK-0001` advanced truthfully through specification, frozen acceptance, and plan approval.

## implement-gameplay-slice

- Trigger: used on `feature/tck-0001-round-lifecycle` after reading the approved feature docs, plan, ticket, branch, and diff.
- Write boundary: changed only `src/shared/GameLoop/RoundLifecycle.luau`, `tests/GameLoop/RoundLifecycle.spec.luau`, and `docs/tickets/TCK-0001.json`.
- Prohibited actions: introduced no Roblox engine globals/services, remotes, persistence, economy, framework, publishing, permission change, frozen-scenario edit, or unrelated refactor.
- Attempt budget: used three of three low-risk attempts. Attempt 1 stopped at StyLua formatting; attempt 2 stopped at Selene assertions without diagnostic messages; attempt 3 passed the complete gate. No fourth attempt occurred.
- Required output: produced one immutable pure lifecycle model and ten deterministic lifecycle cases covering normal/invalid transitions, all failure reasons, success, reset, replay, stale/future generations, duplicate events, and malformed/forged shapes.
- Exit and escalation: exited only after `Checks.ps1` passed and commit `27107ce` was ready for independent review. The budget was not exceeded; any later implementation correction would require human escalation.
- Result: implementation reached `STATIC_PASS` within its allowed budget.

## run-static-gates

- Trigger: used on committed implementation `27107ce` before review.
- Write boundary: made no tracked-file changes; only ignored `build/` outputs were regenerated.
- Prohibited actions: did not format in write mode, install/upgrade dependencies, fix code, start Studio, or publish.
- Attempt budget: not applicable to this read-only reporting skill; it ran the complete gate once.
- Required output: reported StyLua, Selene, sourcemap, strict analysis, 12 passing/0 failing Lune tests, whitespace validation, and Rojo build as passed.
- Exit and escalation: exited with a complete pass and no diagnostic requiring escalation.
- Result: the worktree remained clean at the reviewed implementation commit.

## review-roblox-gameplay

- Trigger: invoked after the committed static pass as the one independent initial review.
- Independence and write boundary: a separate reviewer task read the contract before the diff and modified only `docs/reviews/tck-0001-round-lifecycle.md`; it did not edit implementation, tests, tickets, scenarios, configuration, dependencies, branches, or Studio.
- Prohibited actions: did not fix code, weaken acceptance, claim Studio evidence, or perform a second review without corrections.
- Attempt budget: one initial review was used; no re-review was needed.
- Required output: findings were organized by severity, assumptions and contract coverage were explicit, the exact reviewed commit/check result was recorded, and the disposition was stated.
- Exit and escalation: found no BLOCKER, MAJOR, MINOR, or NIT issues and exited ready for the next human gate. No escalation was required.
- Result: `TCK-0001` advanced truthfully to `CODE_REVIEW_PASS`, not `STUDIO_PASS` or `HUMAN_APPROVED`.
