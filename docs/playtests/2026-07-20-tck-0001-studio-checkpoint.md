# TCK-0001 Studio compatibility checkpoint

**Status:** Passed for the engine-free `TCK-0001` scope only

**Tested implementation/review commit:** `3647912c3336aae3584e592760b273632a9224d0`

**Observed:** 2026-07-20

## Connection and environment

- The repository was on clean branch `feature/tck-0001-round-lifecycle` at the exact tested commit before Studio testing.
- `scripts/Checks.ps1` passed immediately before the checkpoint with 12 tests passed and 0 failed.
- The existing root Rojo server was verified listening on `127.0.0.1:34872`. Its process command served this repository's root `default.project.json`.
- The existing Studio place was `build/RobloxGraybox.rbxlx`.
- Studio MCP listed and selected the connected instance `RobloxGraybox.rbxlx` with connection ID `16c65c57-988c-4fd4-98df-bd31f6460d22`.
- Studio was in Edit mode before and after the checkpoint. A temporary Play session exposed the Server and Client DataModels for the smoke run.

## Behavior observed in Studio

- The Rojo-synchronized module existed exactly once at `ReplicatedStorage.Shared.GameLoop.RoundLifecycle` as a `ModuleScript`.
- An unsaved server-side MCP `execute_luau` smoke script required that mapped module successfully.
- Ten representative contract checks ran under Roblox Luau and passed:
  1. Module require and public functions.
  2. Initial immutable `WAITING` state at generation zero.
  3. Valid `START` to generation-one `ACTIVE` state.
  4. `SUCCESS` result representation.
  5. `TIMEOUT`, `DEATH`, and `VOID` failure representations.
  6. First-result immutability and duplicate terminal-event rejection.
  7. Reset, cleared result, generation increment, and replay.
  8. Duplicate-start rejection.
  9. Stale-generation rejection.
  10. Malformed-event and invalid-transition rejection.
- Accepted transitions returned new immutable states. The representative rejected transitions returned the original state with the expected deterministic rejection reason.
- The temporary smoke code did not create or save scripts, instances, test packages, or implementation changes.

## Relevant Studio console output

```text
[RobloxGraybox] Server bootstrap ready
Plugin loaded
[RobloxGraybox] Client bootstrap ready
Plugin loaded
[TCK-0001-STUDIO][PASS] module requires successfully
[TCK-0001-STUDIO][PASS] initial lifecycle state
[TCK-0001-STUDIO][PASS] valid round start
[TCK-0001-STUDIO][PASS] success representation
[TCK-0001-STUDIO][PASS] timeout death and void failure representation
[TCK-0001-STUDIO][PASS] first result immutability and duplicate rejection
[TCK-0001-STUDIO][PASS] reset generation increment and replay
[TCK-0001-STUDIO][PASS] duplicate start rejection
[TCK-0001-STUDIO][PASS] stale generation rejection
[TCK-0001-STUDIO][PASS] malformed and invalid transition rejection
[TCK-0001-STUDIO][SUMMARY] 10 passed, 0 failed
```

No warnings or errors caused by `RoundLifecycle` or the smoke script were observed. The two `Plugin loaded` entries were informational Studio/plugin output, not warnings or errors.

## Behavior proven only by Lune/static checks

- The repository-owned Lune suite provides the durable exhaustive specification for all allowed phase/event combinations, every supported failure reason, immutable states, stale/future generations, repeated events, malformed shapes, reset, and replay.
- The deterministic harness's recursive discovery, stable ordering, pass/fail accounting, and nonzero failure behavior were not retested in Studio.
- StyLua, Selene, sourcemap generation, strict `luau-lsp` analysis, whitespace validation, and Rojo build are local/CI gates, not Studio gameplay evidence.

## Complete first-playable behavior not yet testable

This checkpoint does not pass any complete first-playable scenario. The following are not implemented and were not tested:

- Server per-player lifecycle adapter and player isolation.
- Player joining, disconnect cleanup, respawn, or late-join behavior.
- Authoritative timer and result/reset intervals.
- Platform, guarded spawn, safe-zone geometry, or valid zone placement.
- Server observation of safe-zone entry, death, or falling into the void.
- Remotes, replication, primitive client feedback, or visible countdown/results.

Those behaviors require later slices, their own frozen-scenario coverage, independent review, and new human-observed Studio evidence.

## Decision

The engine-free module is compatible with Roblox Studio Luau, synchronizes to its intended location, requires successfully, and satisfies the representative scoped smoke checks. `TCK-0001` may advance from `CODE_REVIEW_PASS` to `STUDIO_PASS`. It is not `HUMAN_APPROVED` or `MERGED`.
