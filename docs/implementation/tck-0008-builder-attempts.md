# TCK-0008 builder attempts

Risk tier: medium. Builder budget: two complete-gate attempts.

## Attempt 1

- Status: passed.
- Authorization: implement the owner-approved heavy-rain ambience plan and frozen HRA-01 through HRA-08 scenarios after TCK-0007 merged.
- Starting state: authoritative `main` commit `49a1b9cb86252e4c13de8197f67b9bb0cadc6400`, clean branch `feature/tck-0008-heavy-rain-ambience`, and approved plan commit `25a0e7b7b03682de4593ca49da08aa4acf911670`.
- Accounting: implementation consumed attempt 1; `attempt_budget` remains two and `attempts_used` is one.
- Production implementation: expanded the existing client-local singleton controller to own exactly two independently offset 400-rate rain layers, one nonspatial looped `GrayboxRainAmbience` sound under `SoundService` using owner-approved asset `1516791621` at volume `0.35`, and one render listener. Visual construction failure rolls back completed layers and prevents audio/listener creation. Audio construction or playback failure destroys its partial production sound, warns once, and leaves both visual layers running without retry. Stop and restart clean every owned object and retained callback without adding a gameplay or authority path.
- Deterministic specifications: replaced the prior rain-controller matrix with HRC-01 through HRC-11 for exact counts, singleton start, dual-layer updates, invalid-position rejection and recovery, partial layer rollback, audio failure isolation and partial cleanup, lifecycle isolation, idempotent cleanup, retained callbacks and restart, simulated client isolation, and absence of gameplay authority.
- Focused pre-gate validation: repository formatting completed and all 142 Lune cases passed with 0 failures. The implementation was adjusted before this focused run so Roblox `Vector3` values are constructed only inside the production factory, preserving engine-free module loading.
- Complete gate outcome: passed on the single `scripts/Checks.ps1` run. StyLua passed; Selene reported 0 errors, 0 warnings, and 0 parse errors; sourcemap generation and strict Luau analysis completed without diagnostics; all 142 Lune cases passed with 0 failures; whitespace validation passed; and Rojo built `RobloxGraybox.rbxlx` successfully.
- Remaining evidence: independent review and owner Studio validation of HRA-01 through HRA-08 from the exact reviewed commit remain pending. Headless checks do not establish asset availability, audible looping, comfortable volume, perceived density, readability, client quality throttling, or frame-rate impact.
