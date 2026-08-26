# TCK-0008 clean rebuild Studio checkpoint - owner-confirmed pass

## Scope and exact state

- Date: 2026-08-25.
- Exact Studio runtime/test head: `121aa8d6297be156972f6c7620a3d37a819dfdd1`.
- Corrected implementation commit: `1c7b31d`.
- Independent review commit: `5162aad` with 0 BLOCKER, 0 MAJOR, 0 MINOR,
  and 0 NIT findings.
- Branch: `feature/tck-0008-heavy-rain-ambience-v2`.
- Rojo server: version `7.6.1`, PID `28388`, listening on `127.0.0.1:34872`.
- Deterministic evidence: the complete gate passed with 142 tests and 0 failures.
- Checkpoint result: owner-confirmed `STUDIO_PASS`. Human approval and merge remain
  separate explicit decisions.

## Direct owner report

The owner was given a numbered checklist covering exact heavy-rain layer count and
density, one comfortable looping ambience sound, respawn/replay duplication and audio
restart, gameplay readability and authority, second-client late join, cleanup, low- and
high-quality performance, and client/server console output. The owner replied:
`all pass`.

This directly confirms the scoped observations at the exact runtime head. No automated
Studio transcript, numeric frame-time capture, or object-identity dump was supplied;
this record preserves those evidence limits rather than inventing measurements.

## Frozen-scenario status

| Scenario | Checkpoint status |
| --- | --- |
| HRA-01 | Pass: exactly two local rain layers were visibly heavier than the prior single layer. |
| HRA-02 | Pass: one continuous comfortable local ambience loop played without extra input. |
| HRA-03 | Pass: death, respawn, and automatic replay did not duplicate or restart layers, sound, playback, or listener behavior. |
| HRA-04 | Pass: safe zone, platform edges, HUD, countdown, results, movement, health, and existing gameplay remained readable and unchanged. |
| HRA-05 | Pass by deterministic production-factory regression: construction/parenting failure destroys the partial sound, preserves both visual layers, warns once, and does not retry. Deliberate live asset denial was optional and was not separately claimed. |
| HRA-06 | Pass: a late second client owned its isolated two layers and one sound without affecting the existing player. |
| HRA-07 | Pass: Studio cleanup produced no warning/error; deterministic stop/restart and retained-callback coverage also passed. |
| HRA-08 | Pass: low- and high-quality movement and consecutive rounds remained heavy, readable, audible, and acceptably performant. |

## Console and performance

- Client/server warnings or errors: none reported.
- Low-quality unacceptable frame-rate degradation: none reported.
- High-quality unacceptable frame-rate degradation: none reported.
- Audio comfort or loop-seam issue: none reported.

## Decision

TCK-0008 advances from `CODE_REVIEW_PASS` to `STUDIO_PASS`. The corrected clean rebuild
satisfies HRA-01 through HRA-08 with the stated human-evidence limitations. Human
approval and the merge decision remain pending; publishing is not authorized.

## Subsequent human approval and merge

After this Studio checkpoint, the owner explicitly answered `yes` when asked whether
to merge PR #24. PR #24 was then squash-merged into authoritative `main` as commit
`a756b66ef0b5b947accfbfb4b9ff044624f5e671` on 2026-08-25 Pacific time
(2026-08-26 UTC). This records the transition from `STUDIO_PASS` through explicit
human approval to `MERGED`. Publishing remains unauthorized.
