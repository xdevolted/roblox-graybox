# TCK-0007 Studio checkpoint - partial visibility evidence

## Scope and exact state

- Date: 2026-08-25.
- Exact reviewed runtime/test commit: `31774d448e671555d3faef4b270e7f81b9e5658e`.
- Branch: `feature/tck-0007-cosmetic-rain`.
- Rojo server: version `7.6.1`, PID `23744`, `127.0.0.1:34872`, session `201483ab-58c5-47e9-99dc-9710453e36ea`.
- Rojo live-tree verification: `RainController` existed, client bootstrap called `RainController.start()`, and the corrected visible-streak source values were present.
- Independent review: initial review plus single permitted documentation-only re-review completed with 0 BLOCKER, 0 MAJOR, 0 MINOR, and 0 NIT findings.
- Checkpoint result: partial only. This record supports `STATIC_PASS -> CODE_REVIEW_PASS`; it does not support `STUDIO_PASS`, `HUMAN_APPROVED`, merge, or publishing.

## Direct owner report

After the old non-Git Rojo server was replaced with the feature-clone server and the visibility correction was synced, the owner stated: `Rain is visible`.

This establishes that recognizable rain rendered in the observed Studio session. The report did not include an exact Player count, exact rain-volume/emitter count, traversal observation, respawn/replay observation, late join, missing-camera recovery, cleanup/restart, frame-rate judgment, or server/client warning and error counts. Those claims remain pending and are not inferred.

## Frozen-scenario status

| Scenario | Current checkpoint status |
| --- | --- |
| RAIN-01 | Partial pass: recognizable rain was owner-observed. Exact-one `GrayboxRainVolume` and `GrayboxRainEmitter` were not counted. |
| RAIN-02 | Pending: cross-platform camera-relative coverage was not reported. |
| RAIN-03 | Deterministic/review evidence confirms no authority path; direct Studio runtime-surface observation remains pending. |
| RAIN-04 | Pending: death/fall, respawn, replay, and no-duplication observation was not reported. |
| RAIN-05 | Pending: safe-zone/platform/HUD readability under rain was not reported. |
| RAIN-06 | Pending: two-client late join and isolation were not observed. |
| RAIN-07 | Deterministic tests cover stop/restart and retained callbacks; Studio shutdown warning/error evidence remains pending. |
| RAIN-08 | Deterministic tests cover malformed/non-finite positions; practical current-camera replacement and error-loop observation remain pending. |

## Remaining Studio checklist

1. In one client, count exactly one `GrayboxRainVolume` with one `GrayboxRainEmitter` while rain is visible.
2. Cross distant platform points and confirm the rain follows the view.
3. Confirm the rain owns no remote or Player attribute writer and does not change health, movement, objective, timer, result, or replay.
4. Die/fall, respawn, and replay; confirm the same single presentation remains without stacking.
5. Confirm safe zone, platform edges, HUD, countdown, success, and failure remain readable.
6. Join a second client late; confirm each client owns one local presentation and both round lifecycles remain isolated.
7. Stop play and record exact server/client warnings and errors.
8. If practical, replace/reset `CurrentCamera`; confirm rain resumes once without duplicates or an error loop.
9. Record whether rain causes noticeable frame-rate degradation.

## Decision

- Continue TCK-0007 Studio validation from `CODE_REVIEW_PASS`.
- Do not merge or begin the dependent heavy-rain ambience implementation until the remaining RAIN-01 through RAIN-08 observations pass and the owner explicitly approves the checkpoint.
