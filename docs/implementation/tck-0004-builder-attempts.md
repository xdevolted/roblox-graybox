# TCK-0004 builder attempts

Risk tier: medium. Builder budget: two complete-gate attempts.

## Attempt 1

- Status: passed.
- Authorization: implement only the owner-approved TCK-0004 server-owned objective qualification and immediate-success slice from merged `main` commit `41c2740d6844a56326b5378e014bf3d958af69ac`.
- Starting state: ticket `PLAN_APPROVED`, zero attempts used, clean `main`, unchanged approved plan, and no prior implementation branch, commit, PR, review, Studio record, or builder attempt.
- Branch: `feature/tck-0004-objective-success-observer`.
- Permitted production files: `src/server/GameLoop/ObjectiveSuccessAdapter.luau` and `src/server/Bootstrap.server.luau`.
- Permitted test file: `tests/GameLoop/ObjectiveSuccessAdapter.spec.luau`.
- Required behavior: server-observed objective `Touched`; current objective and owner/current-living-Character qualification; touch-time capture of the current opaque session handle and active generation; exactly one matching-generation `SUCCEED` attempt per handle/generation; rejection of unrelated, foreign, dead, stale, missing-context, inactive, replaced-objective, duplicate, removed-player, and stopped-adapter contacts; per-player isolation and cleanup; no client authority or deferred lifecycle behavior.
- Accounting: attempt 1 is consumed by this authorized implementation session; `attempt_budget` remains two and `attempts_used` becomes one.
- Actual implementation: added the thin server-only `ObjectiveSuccessAdapter`, bound one retained controller after the two merged provider controllers in Bootstrap, and introduced no remote, polling, timer, failure, reset/replay, respawn, repositioning, presentation, persistence, publishing, multi-place, or later-ticket behavior.
- Actual specifications: added all 14 planned OSA cases. The unchanged 59 TCK-0001 through TCK-0003/prototype cases remain present.
- Focused pre-gate validation: targeted formatting and Selene passed; the Lune harness initially exposed one stale-race fake that incorrectly changed the public handle and was narrowed to same-context final-authority rejection; targeted strict analysis exposed one optional inspection-function narrowing diagnostic and explicit local seam types resolved it; repeated focused checks then passed with 73 tests and no diagnostics. These focused checks were not complete-gate attempts.
- Complete gate allowance: one `scripts/Checks.ps1` run after focused validation.
- Complete gate outcome: passed on the single authorized run. StyLua passed; Selene reported 0 errors, 0 warnings, and 0 parse errors; sourcemap generation and strict Luau analysis completed without diagnostics; the Lune harness reported 73 passed and 0 failed; unstaged, staged, and tracked-file whitespace validation passed; and Rojo built `RobloxGraybox.rbxlx` successfully.
