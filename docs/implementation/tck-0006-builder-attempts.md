# TCK-0006 builder attempts

Risk tier: medium. Builder budget: two complete-gate attempts.

## Attempt 1

- Status: passed.
- Authorization: implement the owner-approved corrected TCK-0006 primitive client
  feedback plan from merged `main` commit
  `1b6431da49cab5d0a789ca74a34d8509995fc678`.
- Starting state: ticket `PLAN_APPROVED`, zero attempts used, clean `main`, planning PR
  #18 merged, and merged-main CI run `30524221711` passed.
- Branch: `feature/tck-0006-primitive-client-feedback`.
- Permitted production files:
  `src/client/Prototype/PrimitiveFeedbackModel.luau` and
  `src/client/Prototype/DebugHudController.luau`.
- Permitted test files: `tests/Prototype/PrimitiveFeedbackModel.spec.luau` and
  `tests/PrototypeControllers.spec.luau`.
- Required behavior: read-only replicated active/result/reset presentation; clear
  success and reason-specific failure feedback; exact deadline nil/zero/boundary
  mapping; controller-computed owner objective readiness; fail-closed local objective
  visibility; partial-replication tolerance; duplicate-start prevention; complete
  listener/transparency/GUI cleanup; late hierarchy and multiplayer isolation; and no
  client outcome, Character, input, movement, camera, remote, or server authority.
- Accounting: attempt 1 is consumed when production/test implementation begins;
  `attempt_budget` remains two and `attempts_used` becomes one.
- Actual implementation: added one engine-free presentation mapper with exact
  phase/result/reason/readiness/deadline mapping; replaced the placeholder debug HUD
  with one primitive persistent ScreenGui and a guarded client controller that reads
  only replicated state, classifies owner objectives locally, fails closed on
  ambiguity, observes late hierarchy replication, coalesces attribute refreshes, and
  restores every listener/transparency/GUI resource on stop. `InputController`,
  Bootstrap, all server/shared gameplay modules, remotes, Character behavior, and
  movement remain unchanged.
- Actual specifications: added all 12 planned mapper cases, all 14 planned controller
  cases, and one additional UI-construction failure/cleanup case. The original 104
  cases remain present for 131 total.
- Focused pre-gate validation: formatting and Selene passed with zero diagnostics; all
  131 Lune cases passed; sourcemap generation succeeded; and exact strict source
  analysis passed. The first focused analysis identified only literal-table widening
  and injected-function union diagnostics; explicit view-model tables and seam types
  resolved them before the complete gate. These focused checks were not complete-gate
  attempts.
- Complete gate allowance: one `scripts/Checks.ps1` run after focused validation.
- Complete gate outcome: passed on the single authorized run. StyLua passed; Selene
  reported 0 errors, 0 warnings, and 0 parse errors; sourcemap generation and strict
  Luau analysis completed without diagnostics; the Lune harness reported 131 passed and
  0 failed; unstaged, staged, and tracked-file whitespace validation passed; and Rojo
  built `RobloxGraybox.rbxlx` successfully.
