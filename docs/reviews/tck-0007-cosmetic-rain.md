# TCK-0007 independent gameplay review

**Review type:** Independent initial review and single permitted re-review

**Reviewed range:** `main..31774d448e671555d3faef4b270e7f81b9e5658e`

**Base commit:** `3e1b526f0ccc00a8782aed1bae41c0b5b45b7cda`

**Contract:** Approved cosmetic-rain specification, frozen RAIN-01 through RAIN-08
acceptance scenarios, and approved slice plan

## Initial findings

- BLOCKER: 0
- MAJOR: 0
- MINOR: 0
- NIT: 1

### NIT — The builder-attempt record contains an invalid base commit hash

`docs/implementation/tck-0007-builder-attempts.md` records the attempt-1 starting
commit as `3e1b526a5ae4d05f8d92b966bf3e11d9295fe908`. That object does not exist in this
repository. The merge base of `main` and the reviewed head is
`3e1b526f0ccc00a8782aed1bae41c0b5b45b7cda`.

This was a provenance typo only; it did not affect the implementation or acceptance
behavior.

**Re-review disposition: resolved.** The builder changed only the invalid hash to
`3e1b526f0ccc00a8782aed1bae41c0b5b45b7cda`. That object exists and matches both
current `main` and the merge base of `main` with reviewed implementation commit
`31774d4`.

## Re-review findings

- BLOCKER: 0
- MAJOR: 0
- MINOR: 0
- NIT: 0

No unresolved review finding remains after the single permitted re-review.

## Assumptions and contract check

- Expectations were re-derived from the specification and frozen scenarios before the
  diff was inspected. The required deterministic behavior is one client-local
  presentation, automatic singleton startup, camera-relative finite positioning,
  idempotent stop/restart, inert retained callbacks, safe missing-view recovery, and no
  gameplay authority.
- `Bootstrap.client.luau` starts the controller once. The module-level singleton makes
  repeated `start()` calls return the same controller without another effect or render
  listener.
- The production effect owns one invisible, anchored, nonphysical Part and one enabled
  ParticleEmitter. Its only per-frame mutation is assigning the owned Part's position
  from `Workspace.CurrentCamera` plus the approved vertical offset after finite-Vector3
  validation.
- Missing or malformed local view positions are skipped. No effect, listener, remote,
  gameplay object, or warning loop is created by an invalid update, and a later valid
  frame resumes positioning the same effect.
- `stop()` invalidates the controller before disconnecting and destroying the effect.
  Repeated stop is harmless, retained callbacks fail the current-controller guard, and
  a later start creates one clean presentation.
- Effect-construction failure is guarded by `pcall`, reports once, connects no render
  listener, and retains a stoppable singleton until an explicit clean retry is allowed.
- The reviewed source contains no RemoteEvent/RemoteFunction call, Player attribute
  write, Character/Humanoid dependency, round-state dependency, server/shared change,
  damage, reward, inventory, persistence, economy, or outcome path. Rain therefore
  remains presentation-only and character/round changes cannot cause controller
  duplication.
- Roblox gives each client its own LocalScript/module environment, so the module
  singleton is client-local. The deterministic RC-09 case checks clean isolation across
  sequential simulated environments; actual simultaneous late-join isolation remains
  a required two-client Studio observation under RAIN-06.
- Particle appearance, camera coverage while traversing the arena, cue readability,
  frame-rate cost, live respawn/replay behavior, true late join, and runtime console
  cleanliness cannot be established by this engine-free review.
- The owner's statement that the corrected rain is visible establishes recognizable
  particles in the observed session only. It does not establish the exact-one-object
  portion of RAIN-01 or any unreported RAIN-02 through RAIN-08 Studio observation.
- Untracked `docs/features/heavy-rain-ambience/` content is a future slice and was
  intentionally excluded from this review.

## Check result

- `git diff --check main..31774d4` completed without whitespace errors.
- Independent `scripts/Test.ps1` execution passed all 141 cases with 0 failures,
  including RC-01 through RC-10.
- Targeted source inspection confirmed the rain diff is limited to client bootstrap,
  the client rain controller, its deterministic tests, and scoped documentation. No
  server/shared gameplay implementation changed.
- The builder-attempt record reports that the complete pre-Studio gate passed after the
  visibility correction: formatting, zero Selene diagnostics, sourcemap generation,
  strict Luau analysis, 141 Lune tests, whitespace validation, and Rojo build. This
  reviewer did not rerun the full gate because it includes generated/build operations;
  the independent read-only test run above corroborates the deterministic suite.
- The re-review inspected the builder's narrow documentation correction. Its diff
  changes exactly one hash, passes `git diff --check`, and the corrected object resolves
  to the actual `main`/merge-base commit. No gameplay or test rerun was necessary for
  this documentation-only correction.
- Other than the corrected builder-attempt record and this review document, the
  worktree still contained only the pre-existing untracked future heavy-rain
  documentation.

## Disposition

**Ready for the remaining scoped human/Studio validation.** There is no unresolved
BLOCKER, MAJOR, MINOR, or NIT finding after the single permitted re-review. RAIN-01's
exact-one presentation check and the unreported portions of RAIN-02 through RAIN-08
remain pending; this review does not claim `STUDIO_PASS`, merge approval, or publishing
authority.
