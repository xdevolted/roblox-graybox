# TCK-0008 heavy-rain ambience independent review

**Review type:** Independent initial review of the clean rebuild

**Reviewed range:** `91f5f1471ad4f25049f5728947c74746642090d6..1c7b31d`

**Base:** Authoritative `main` after TCK-0007 merged through PR #22

**Contract:** Approved heavy-rain ambience specification, frozen HRA-01 through
HRA-08 scenarios, approved slice plan, `AGENTS.md`, and `docs/WORKFLOW.md`

## Findings

- BLOCKER: 0
- MAJOR: 0
- MINOR: 0
- NIT: 0

No unresolved review finding remains in the clean TCK-0008 slice.

## Assumptions and contract check

- TCK-0007 is present on authoritative `main` at `91f5f14`; this branch starts from
  that merged camera-following single-layer rain controller and contains only TCK-0008
  feature, test, ticket, builder, and contract files.
- Successful startup creates exactly two indexed client-local rain layers with distinct
  camera-relative offsets, one nonspatial looped `GrayboxRainAmbience` under
  `SoundService` using `rbxassetid://1516791621` at volume `0.35`, and one
  `RenderStepped` listener.
- Repeated start returns the singleton. Character replacement and round transitions are
  outside the dependency surface, so respawn, result, reset, and replay cannot restart
  or stack layers, sound, playback, or listeners.
- Missing and non-finite camera-relative targets move neither layer. A later finite
  target resumes both existing layers without recreation or warning retries.
- A layer-construction failure destroys every completed layer, creates no sound or
  listener, warns once, and retains a stoppable singleton failure guard.
- The complete production sound configuration, parenting, and `Play()` sequence is
  protected. Failure after a partial `Sound` exists destroys it, warns once through the
  controller, keeps both visual layers and their listener running, and does not retry.
- Stop invalidates first, disconnects once, stops/destroys the successful sound,
  destroys both layers, and clears the singleton. Repeated stop is harmless, retained
  callbacks are inert, and restart creates one clean complete presentation.
- The implementation contains no Player, Character, Humanoid, remote, attribute writer,
  Lighting writer, damage, movement, reward, objective, result, timer, persistence,
  economy, or server/shared authority path.
- Actual asset availability, audible looping and volume, perceived density, cue
  readability, simultaneous late join, low/high quality behavior, warnings/errors, and
  frame-rate impact remain human Studio observations under HRA-01 through HRA-08.

## Check result

- The regression for the original partial-sound finding invoked the production default
  factory with an engine-free fake `Instance` that failed during parenting. It first
  failed with 141 passing cases and one HRC-06 failure because the partial sound was not
  destroyed; after the correction all 142 cases passed.
- `scripts/Checks.ps1` passed at corrected commit `1c7b31d`: StyLua format check,
  Selene with zero errors/warnings/parse errors, sourcemap generation, strict Luau
  analysis, 142 Lune tests, unstaged/staged/tracked whitespace validation, and Rojo
  build.
- `git diff --check 91f5f14...1c7b31d` passed, and the implementation diff changes
  only `RainController.luau` and its deterministic specification. Bootstrap,
  server/shared gameplay, configuration, dependencies, and project mapping are
  unchanged.
- The medium-risk slice used both approved complete-gate attempts. Attempt 1 passed its
  gate but failed later merge-readiness review; attempt 2 is this clean rebuild and
  passed its single complete gate. No attempt remains for further builder correction.

## Disposition

**Ready for human/Studio validation.** There is no unresolved BLOCKER, MAJOR, MINOR,
or NIT finding. HRA-01 through HRA-08 must now be observed from the exact corrected
commit before the slice can be marked Studio-pass or merge-ready.
