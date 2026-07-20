---
name: specify-roblox-feature
description: Convert a voice transcript or written Roblox gameplay idea into concise game-level and feature-level specifications with frozen acceptance scenarios. Use before planning or implementing a new feature, especially the first playable, when player-facing behavior, state transitions, authority boundaries, non-goals, or open product questions are not yet explicit.
---

# Specify Roblox Feature

## Method

1. Read `AGENTS.md`, `GAME_SPEC.md`, `CORE_LOOP.md`, and relevant existing decisions and feature docs.
2. Identify the player fantasy, one primary action, objective, failure, result, reset path, session constraints, and minimum player count. Ask the human only for product choices that cannot be derived.
3. Write only:
   - `GAME_SPEC.md` and `CORE_LOOP.md` when game-level truth changes.
   - `docs/features/<feature>/specification.md` for behavior, non-goals, states, events, and guards.
   - `docs/features/<feature>/acceptance-tests.md` with 5-10 Given/When/Then scenarios.
   - `docs/features/<feature>/open-questions.md` for unresolved assumptions.
4. State exactly what the server decides and what clients may only request. Include type, range, ownership, context, permission, and frequency validation where remotes are involved.
5. Include reset/replay and, when shared state is involved, invalid request, disconnect, respawn, and late-join scenarios.
6. Mark acceptance scenarios frozen only after the human resolves material open questions and approves them.

## Boundaries

- Modify only the game-level Markdown files and the target feature's documentation.
- Do not modify `src/`, `tests/`, configuration, packages, branches, or Studio.
- Do not invent game IDs, place IDs, mechanics, rewards, or product decisions.
- Keep persistence, economy, final art/UI, multi-place, and frameworks out of the graybox unless explicitly approved.
- Stop after two unsuccessful specification passes and report the exact decisions needed.

## Exit

Finish when behavior, non-goals, transitions, authority, frozen scenarios, and remaining questions are explicit enough to plan without invention.
