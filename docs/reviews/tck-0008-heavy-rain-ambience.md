# TCK-0008 independent gameplay review

**Review type:** Independent initial review

**Reviewed range:** `25a0e7b7b03682de4593ca49da08aa4acf911670..8b45b41b4e79e6eb1be712f0e33f347f7158fd06`

**Base commit:** `49a1b9cb86252e4c13de8197f67b9bb0cadc6400`

**Contract:** Approved heavy-rain ambience specification, frozen HRA-01 through
HRA-08 acceptance scenarios, and approved single-slice plan

## Findings

- BLOCKER: 0
- MAJOR: 0
- MINOR: 0
- NIT: 0

No review finding requires a builder correction.

## Assumptions and contract check

- Expected behavior and authority boundaries were independently re-derived from
  `AGENTS.md`, the approved specification, and frozen acceptance scenarios before the
  implementation diff was inspected.
- `Bootstrap.client.luau` starts the controller automatically. The module singleton is
  local to each Roblox client, so repeated starts, Character replacement, and round
  transitions cannot add another controller, rain layer, sound, or render listener.
- Successful startup creates indexed layers 1 and 2. Each owns one invisible,
  nonphysical box-volume Part and one 400-rate downward ParticleEmitter with a distinct
  fixed camera-relative offset. One `RenderStepped` callback positions both existing
  layers only after the target passes finite-Vector3 validation.
- Successful audio startup creates one `GrayboxRainAmbience` Sound under
  `SoundService`, assigns the approved `rbxassetid://1516791621`, enables looping, sets
  volume to `0.35`, and calls `Play()` once. Parenting the Sound to `SoundService` keeps
  the ambience nonspatial and independent of Character lifecycle.
- A visual-layer construction failure rolls back every completed layer, reports once,
  creates no sound or listener, and retains a stoppable singleton failure guard. A
  synchronous sound-construction or `Play()` failure reports once while both visual
  layers and their listener continue without an automatic audio retry.
- `stop()` invalidates the callback first, disconnects the owned listener, stops and
  destroys the successful sound, destroys both layers, and clears the singleton.
  Repeated stop is harmless; retained callbacks are inert; a later start creates a
  complete fresh presentation.
- The reviewed controller contains no Player, Character, Humanoid, Lighting, remote,
  server controller, attribute writer, objective, result, reward, damage, movement,
  persistence, economy, or round-transition path. The slice therefore adds no client
  gameplay authority or request-validation surface.
- The engine-free matrix covers exact successful counts, singleton start, two-layer
  updates, invalid-position rejection and recovery, partial visual rollback, audio
  failure isolation, lifecycle independence, idempotent cleanup, retained callbacks,
  restart, simulated client isolation, and absence of authority calls.
- Engine-free checks cannot establish asynchronous asset availability, audible loop
  seams, perceived density or volume, simultaneous-client late join, live respawn,
  readability, quality-level particle throttling, frame-rate impact, or Studio console
  cleanliness. Those remain observational evidence under HRA-01 through HRA-08.
- The owner's statement that the rain is audible and looks good establishes the
  observed session's basic audio and visual presentation. It does not by itself record
  every required low/high-quality, replay, late-join, object-count, warning, and
  performance observation.

## Check result

- The implementation diff is confined to the approved controller/test boundary plus
  scoped ticket and builder evidence. Client bootstrap, server/shared code,
  configuration, dependencies, and frozen contract documents did not change.
- `git diff --check 25a0e7b..8b45b41` completed without whitespace errors.
- Independent `scripts/Test.ps1` execution passed all 142 cases with 0 failures,
  including HRC-01 through HRC-11.
- Independent read-only StyLua format checking passed. Selene reported 0 errors, 0
  warnings, and 0 parse errors. Strict Luau analysis completed without a diagnostic;
  its only output was the expected client notification that automatic sourcemap file
  watching is unavailable.
- Targeted source inspection confirmed the approved audio ID, looping, volume,
  `SoundService` ownership, two 400-rate emitters, and absence of gameplay-authority
  symbols in the production controller.
- The builder record reports one successful complete `scripts/Checks.ps1` attempt at
  the reviewed commit, including formatting, linting, sourcemap generation, strict
  analysis, 142 tests, whitespace validation, and Rojo build. This reviewer did not
  rerun the full gate because sourcemap/build steps write generated artifacts; the
  independent read-only checks above corroborate its static and deterministic results.

## Disposition

**Ready for the remaining scoped human/Studio validation.** The initial independent
review found no BLOCKER, MAJOR, MINOR, or NIT issue. This disposition does not claim
`STUDIO_PASS`, merge approval, or publishing authority; HRA-01 through HRA-08 still
require the project's exact reviewed-commit evidence and human checkpoint.
