# TCK-0003 builder attempts

Risk tier: medium. Builder budget: two complete-gate attempts.

## Attempt 1

- Status: passed.
- Authorization: implement only the owner-approved TCK-0003 safe-spawn and per-player objective foundation from merged `main` commit `991a4af21356f79ca237aa906e13978bd87c1da9`.
- Starting state: ticket `PLAN_APPROVED`, zero attempts used, clean `main`, and no prior implementation branch, commit, PR, review, Studio record, or builder attempt.
- Branch: `feature/tck-0003-safe-spawn-objective`.
- Permitted production files: `src/shared/GameLoop/ObjectivePlacement.luau`, `src/server/GameLoop/SafeSpawnObjectiveAdapter.luau`, and `src/server/Bootstrap.server.luau`.
- Permitted test files: `tests/GameLoop/ObjectivePlacement.spec.luau` and `tests/GameLoop/SafeSpawnObjectiveAdapter.spec.luau`.
- Required behavior: deterministic unique assignment across eight canonical slots; explicit ninth-player `NO_AVAILABLE_SLOT` with no objective or existing-assignment mutation; server-owned arena, guarded neutral spawn, objective Instances, association metadata, isolation, removal, shutdown, and read-only lookup seams; no lifecycle event or deferred behavior.
- Accounting: attempt 1 is consumed before production implementation; `attempt_budget` remains two and `attempts_used` becomes one.
- Actual implementation: added the engine-free eight-slot `ObjectivePlacement` registry; added the thin server-owned `SafeSpawnObjectiveAdapter` for exact arena geometry, guarded neutral spawn, per-player objective Instances/metadata, deterministic overflow, isolation, read-only lookup, removal, and shutdown; and started one retained objective controller after the existing round controller in Bootstrap.
- Actual specifications: added all nine planned placement cases and all ten planned adapter cases. The unchanged 40 TCK-0001/TCK-0002/prototype cases remain present.
- Focused pre-gate validation: targeted StyLua formatting/check, targeted Selene, targeted strict Luau analysis, and the Lune harness completed successfully with 59 passed and 0 failed. These focused checks are not the authorized complete gate.
- Complete gate allowance: one `scripts/Checks.ps1` run after implementation. No correction or second complete-gate run is authorized if it fails.
- Complete gate outcome: passed on the single authorized run. StyLua passed; Selene reported 0 errors, 0 warnings, and 0 parse errors; sourcemap generation passed; strict Luau analysis completed with no diagnostics; the Lune harness reported 59 passed and 0 failed; unstaged, staged, and tracked-file whitespace validation passed; and Rojo built `RobloxGraybox.rbxlx` successfully.

## Attempt 2

- Status: passed.
- Authorization: correct only initial-review finding `MINOR-1` (SOA-01 guard-wall descriptor coverage) without changing production behavior.
- Starting state: initial implementation commit `214f2e85db584b1a98fbef02bccdfc88bb3afa3a` at `STATIC_PASS`; initial independent review durably recorded by commit `8242738c16e239373f8bf518cdd96c060c8ee558`; both review-record CI paths green; clean synchronized implementation branch; no Studio checkpoint.
- Permitted test file: `tests/GameLoop/SafeSpawnObjectiveAdapter.spec.luau` only.
- Permitted workflow records: this attempt record and `docs/tickets/TCK-0003.json`; the independent reviewer may later update only the existing TCK-0003 review record and schema-required review metadata.
- Required correction: independently assert the exact class, name, size, position, arena parent, presence, uniqueness, and distinct identity of all three approved guard walls using plan-derived expected values.
- Accounting: attempt 2 is consumed when the test correction begins; `attempt_budget` remains two and `attempts_used` becomes two.
- Complete gate allowance: one `scripts/Checks.ps1` run after the correction and accounting updates. No correction or complete-gate rerun is authorized if it fails.
- Complete gate outcome: passed on the single authorized run. StyLua passed; Selene reported 0 errors, 0 warnings, and 0 parse errors; sourcemap generation passed; strict Luau analysis completed with no diagnostics; the Lune harness reported 59 passed and 0 failed; unstaged, staged, and tracked-file whitespace validation passed; and Rojo built `RobloxGraybox.rbxlx` successfully.
