# TCK-0005 builder attempts

Risk tier: medium. Builder budget: two complete-gate attempts.

## Attempt 1

- Status: passed.
- Authorization: implement only the owner-approved TCK-0005 server-owned failure and reliable replay slice from merged `main` commit `a271be2b0139b04941dbc7f756933a6100459027`.
- Starting state: ticket `PLAN_APPROVED`, zero attempts used, clean `main`, approved planning PR #15 merged, merged-main CI run `30413789115` passed, and no prior TCK-0005 implementation branch, commit, PR, review, Studio record, or builder attempt.
- Branch: `feature/tck-0005-failure-replay-adapter`.
- Permitted production files: `src/shared/GameLoop/ObjectivePlacement.luau`, `src/server/GameLoop/SafeSpawnObjectiveAdapter.luau`, `src/server/GameLoop/FailureReplayAdapter.luau`, and `src/server/Bootstrap.server.luau`.
- Permitted test files: `tests/GameLoop/ObjectivePlacement.spec.luau`, `tests/GameLoop/SafeSpawnObjectiveAdapter.spec.luau`, and `tests/GameLoop/FailureReplayAdapter.spec.luau`.
- Required behavior: server-owned timeout/death/void failure; first-result immutability; 20/2/1-second server-time deadlines; `Y = -20` void observation; controlled initial/reset Character loading; exact-once result/reset/replay; in-place different-slot objective repositioning with the approved deterministic full-capacity fallback; per-player isolation; timing publication; and disconnect/respawn/shutdown cleanup.
- Accounting: attempt 1 is consumed by this authorized implementation session; `attempt_budget` remains two and `attempts_used` becomes one.
- Actual implementation: extended the engine-free placement registry with previous-slot-excluding reassignment and the approved full-capacity overlap fallback; added an in-place server objective-reposition seam; added one server-only failure/replay adapter owning the authoritative clock, timeout/death/void observations, controlled Character loading, exact-once result/reset/replay, timing publication, isolation, and cleanup; and retained it after the three merged provider controllers in Bootstrap.
- Actual specifications: added all 6 planned placement-replay cases, all 5 planned safe-spawn/objective replay cases, and all 20 planned failure/replay adapter cases. The original 73 cases remain present for 104 total.
- Focused pre-gate validation: targeted formatting and Selene passed; the first Lune run exposed two fixture assertions that allowed the independent control player to time out while testing another player's invalid/removal path, and narrowing those fake time advances produced 104 passing cases; targeted strict source analysis exposed one placement-rejection normalization diagnostic, optional injected-function narrowing diagnostics, and two optional-deadline narrowing diagnostics, all resolved with exhaustive normalization, explicit seam types, and asserted initialized deadlines; repeated formatting, lint, tests, and exact production analysis then passed. These focused checks were not complete-gate attempts.
- Complete gate allowance: one `scripts/Checks.ps1` run after focused validation.
- Complete gate outcome: passed on the single authorized run. StyLua passed; Selene reported 0 errors, 0 warnings, and 0 parse errors; sourcemap generation and strict Luau analysis completed without diagnostics; the Lune harness reported 104 passed and 0 failed; unstaged, staged, and tracked-file whitespace validation passed; and Rojo built `RobloxGraybox.rbxlx` successfully.
