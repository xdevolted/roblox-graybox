# TCK-0007 builder attempts

Risk tier: medium. Builder budget: two complete-gate attempts.

## Attempt 1

- Status: passed.
- Authorization: implement the owner-approved cosmetic rain plan and frozen RAIN-01 through RAIN-08 scenarios.
- Starting state: authoritative `main` commit `3e1b526f0ccc00a8782aed1bae41c0b5b45b7cda`, clean fresh clone, and branch `feature/tck-0007-cosmetic-rain`.
- Accounting: implementation consumed attempt 1; `attempt_budget` remains two and `attempts_used` is one.
- Production implementation: added one client-local `RainController` that owns one invisible 64-by-1-by-64 box-volume `ParticleEmitter`, follows a finite current-camera position 28 studs overhead on one render connection, starts and stops idempotently, fails safely while view state is unavailable, and cleans retained callbacks and runtime objects. Client bootstrap starts it once. No server/shared gameplay code, remotes, Player attributes, Character/Humanoid state, Lighting, dependencies, or project mapping changed.
- Deterministic specifications: added RC-01 through RC-10 for singleton start, movement, malformed/non-finite position rejection, Character/round isolation, cleanup, retained callbacks, restart, construction failure, simulated client isolation, and absence of gameplay authority. The original 131 cases remained present for 141 total.
- Focused pre-gate validation: StyLua formatting/check, Selene with zero diagnostics, sourcemap generation, exact strict Luau analysis, and all 141 Lune cases passed. One initial test-only Selene warning identified a simulated state value that was only written; an explicit assertion corrected it before the complete gate. Fresh-clone setup reused the already installed pinned Rokit tool binaries, ran pinned Wally installation, and copied the exact SHA-256-verified Roblox definitions from the untouched original directory because the Rokit bootstrap executable itself was unavailable. These focused/setup checks were not additional complete-gate attempts.
- Complete gate outcome: passed on the single `scripts/Checks.ps1` run. StyLua passed; Selene reported 0 errors, 0 warnings, and 0 parse errors; sourcemap generation and strict Luau analysis completed without diagnostics; the Lune harness reported 141 passed and 0 failed; unstaged, staged, and tracked-file whitespace validation passed; and Rojo built `RobloxGraybox.rbxlx` successfully.
- Studio/playtest evidence: pending. Studio must still verify recognizable rain, camera-relative coverage, single-emitter behavior across respawn/replay and late join, readability, runtime warnings/errors, and acceptable performance.

## Attempt 2

- Status: passed.
- Trigger: the owner connected Studio after the correct feature-clone Rojo server was restored and reported that no rain was visibly recognizable. The original `0.09`-stud spark particles therefore failed RAIN-01's human visual requirement even though the controller and bootstrap were present in Rojo's live tree.
- Accounting: the visibility correction consumed attempt 2; `attempt_budget` remains two and `attempts_used` is two.
- Correction: changed only default ParticleEmitter presentation values. The emitter now uses Roblox's 400-particle-per-second ceiling, zero initial shaped-emitter speed, global downward acceleration of 110 studs per second squared, a 0.9–1.1 second lifetime, 0.28-stud particles, positive squash for long streaks, camera-upright orientation, higher initial opacity, and stronger light emission. Controller lifecycle, camera tracking, authority isolation, tests, bootstrap, dependencies, and every gameplay module remain unchanged.
- Focused pre-gate validation: formatting, Selene with zero diagnostics, sourcemap generation, exact strict source analysis, and all 141 Lune cases passed.
- Complete gate outcome: passed on the single `scripts/Checks.ps1` run authorized for attempt 2. StyLua passed; Selene reported 0 errors, 0 warnings, and 0 parse errors; sourcemap generation and strict Luau analysis completed without diagnostics; the Lune harness reported 141 passed and 0 failed; whitespace validation passed; and Rojo built `RobloxGraybox.rbxlx` successfully.
- Studio/playtest evidence: the initial visual observation failed and is preserved above. The corrected defaults still require a fresh Play session and owner confirmation for RAIN-01 through RAIN-08; no corrected visual pass is claimed yet.
