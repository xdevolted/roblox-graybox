# TCK-0007 Studio checkpoint - owner-confirmed pass

## Scope and exact state

- Date: 2026-08-25.
- Exact reviewed runtime/test commit: `31774d448e671555d3faef4b270e7f81b9e5658e`.
- Branch: `feature/tck-0007-cosmetic-rain`.
- Rojo server: version `7.6.1`, PID `23744`, `127.0.0.1:34872`, session `201483ab-58c5-47e9-99dc-9710453e36ea`.
- Rojo live-tree verification: `RainController` existed, client bootstrap called `RainController.start()`, and the corrected visible-streak source values were present.
- Independent review: initial review plus single permitted documentation-only re-review completed with 0 BLOCKER, 0 MAJOR, 0 MINOR, and 0 NIT findings.
- Checkpoint result: owner-confirmed pass. This record supports `CODE_REVIEW_PASS -> STUDIO_PASS -> HUMAN_APPROVED`; it does not authorize publishing.

## Direct owner report

After the old non-Git Rojo server was replaced with the feature-clone server and the visibility correction was synced, the owner stated: `Rain is visible`.

This established that recognizable rain rendered in the observed Studio session. The initial report did not include the remaining checklist details.

After receiving the explicit remaining checklist, the owner reported `all tests pass` and directed work to continue to the next slice. This is direct human confirmation that the exact-one presentation count, movement coverage, respawn/replay duplication check, gameplay readability, late-join isolation, console cleanliness, and performance judgment all passed. No automated Studio transcript, numeric frame-time capture, or detailed warning/error listing was supplied, so this record preserves those evidence limitations rather than inventing measurements.

## Frozen-scenario status

| Scenario | Current checkpoint status |
| --- | --- |
| RAIN-01 | Pass by owner confirmation: recognizable rain and exactly one local volume/emitter presentation. |
| RAIN-02 | Pass by owner confirmation: rain followed the view across platform movement. |
| RAIN-03 | Pass by deterministic/review evidence plus owner confirmation that gameplay behavior remained unchanged. |
| RAIN-04 | Pass by owner confirmation: death/respawn/replay did not duplicate rain. |
| RAIN-05 | Pass by owner confirmation: safe zone, platform, HUD, countdown, and results remained readable. |
| RAIN-06 | Pass by owner confirmation: late-join presentation and player lifecycles remained isolated. |
| RAIN-07 | Pass by deterministic evidence and owner confirmation of clean Studio shutdown/runtime behavior. |
| RAIN-08 | Pass by deterministic malformed-position evidence and owner confirmation of runtime recovery/cleanliness. |

## Completed Studio checklist

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

- TCK-0007 passes the scoped Studio checkpoint with human-reported evidence limitations recorded above.
- The owner explicitly approved the result and directed work to continue to the dependent heavy-rain ambience slice.
- This supports human approval and merge of TCK-0007; it does not authorize publishing.
