# TCK-0006 independent gameplay review

**Review type:** External independent initial review and incremental re-reviews

**Independent reviewer:** CodeRabbit

**Base commit:** `1b6431da49cab5d0a789ca74a34d8509995fc678`

**Initial reviewed commit:** `8eb7ab7eb245acd50b8123907837f9592d8d8875`

**Attempt 2 correction:** `36f59958f724e35b7450d19ed19acacf7ec4c64b`

**Final corrected reviewed commit:** `b2481b316891bac0de021ac2fe0f3681d50ae87c`

**Pull request:** `#19`

**Contract:** Frozen first-playable scenarios and the owner-approved TCK-0006 Slice 6
primitive client feedback plan

**Reviewer write boundary:** CodeRabbit changed no repository file. This durable record
and the corresponding ticket-state transition are workflow-only changes made after the
external review completed.

## Initial findings

CodeRabbit's initial review reported six low-value or quick-win nit findings and no
BLOCKER, MAJOR, or MINOR finding.

1. **Resolve `Players.LocalPlayer` lazily when no test Player is injected.**

   **Disposition: resolved in attempt 2.** The controller now uses the injected Player
   first and accesses the Players service only for the production fallback.

2. **Batch objective refresh during initial folder enumeration.**

   **Disposition: resolved in attempt 2.** Existing candidates bind without a
   per-candidate refresh, followed by one final objective classification. Individual
   late additions still refresh immediately.

3. **Reuse the mapper's exported `ViewModel` type.**

   **Disposition: rejected after focused validation.** CodeRabbit's proposed direct
   expression is not valid Luau syntax. Binding the module through the repository's
   conditional Roblox/Lune require pattern erases its exported type namespace under
   strict analysis, while an unconditional Roblox Instance require breaks the Lune
   harness. The exact strict local structural type remains.

4. **Avoid rewriting the view on every render frame when presentation is unchanged.**

   **Disposition: resolved in attempt 2.** The controller maps current replicated state
   and server time, then writes the view only when visible text or tone changes. DHC-04
   proves stable frames do not render, a changed countdown renders once, and zero stays
   presentation-only.

5. **Mark Studio/playtest evidence explicitly pending.**

   **Disposition: resolved in attempt 2.** The attempt record truthfully states that no
   Studio or human playtest evidence exists yet.

6. **Name the active, result, and reset countdown-window constants.**

   **Disposition: resolved in attempt 2.** The approved `20`, `2`, and `1` second
   windows are centralized without changing deadline behavior.

## First incremental re-review

CodeRabbit reviewed attempt 2 and reported four additional outside-diff test-coverage
findings:

1. **DHC-01 allowed one or more initial renders instead of exactly one.**

   **Disposition: resolved in exceptional attempt 3.** Every canonical connection tier
   now requires exactly one initial render.

2. **DHC-07 did not directly prove immediate candidate-listener disconnection.**

   **Disposition: resolved in exceptional attempt 3.** The test now requires the old
   owner listener's disconnect count to equal one immediately after removal, before a
   replacement is added.

3. **DHC-12 flushed old queued work before restart.**

   **Disposition: resolved in exceptional attempt 3.** The test fires retained
   callbacks, starts the fresh controller, and only then flushes the old deferred queue;
   the old callback cannot append a render to the new controller.

4. **Add remote, input, movement, and camera sentinels to DHC-14.**

   **Disposition: rejected as contrary to the approved boundary.** DHC-14 requires
   those dependency surfaces not to exist. Adding them merely to install sentinels
   would widen the fake and production-facing seam. Their absence is established by
   the narrow dependency type and direct strict source inspection; runtime coverage
   continues to prove no Player attribute write, Character replacement, extra view,
   or deferred zero-time outcome behavior.

## Final findings

- BLOCKER: 0
- MAJOR: 0
- MINOR: 0
- NIT: 0

No unresolved review finding remains.

## Contract coverage and assumptions

- The client reads only the five approved replicated Player attributes and server-time
  basis. It has no outcome, lifecycle, remote, Character, movement, input, camera,
  persistence, or economy authority.
- The mapper validates complete snapshot combinations, implements the approved
  nil/zero/inclusive countdown boundaries, returns frozen view models, and carries no
  prior-generation text.
- The controller creates one primitive persistent ScreenGui, prevents duplicate
  bootstrap, coalesces attribute bursts, and avoids redundant visible writes while
  retaining countdown accuracy.
- Objective presentation is computed independently from the local UserId. Zero or
  multiple owner matches fail closed; late hierarchy and owner metadata converge
  without duplicate binding.
- Candidate removal and full stop disconnect owned listeners, restore surviving local
  transparency values, destroy the view, and leave retained callbacks inert across a
  later restart.
- Normal Roblox character controls remain unchanged. No custom movement system was
  added.
- Headless evidence proves mapping and controller orchestration only. It does not prove
  actual rendering, visibility, comprehension, multiplayer playability, or the required
  FP-09 late-join Studio observation.

## Check and review result

- Attempts 1 and 2 each passed their single authorized complete gate with formatting,
  zero Selene diagnostics, sourcemap generation, strict Luau analysis, 131 passing Lune
  tests, whitespace validation, and a successful Rojo place build.
- The owner explicitly authorized exceptional attempt 3 for the three remaining
  test-only corrections. Its single complete gate passed with the same 131 tests and no
  lint, analysis, whitespace, or build failure.
- Exact final-head pull-request CI run `30531023077` and push CI run `30531019039`
  passed for `b2481b316891bac0de021ac2fe0f3681d50ae87c`.
- CodeRabbit's final incremental run
  `84f0eb36-fad6-4776-830a-dfb241af5fd7` reviewed the attempt 3 change and updated the
  PR summary with: "No actionable comments were generated in the recent review."
- PR #19 was open, non-draft, cleanly mergeable, based on `main`, and pointed exactly to
  the final corrected reviewed commit when this record was prepared.
- The implementation branch was clean and synchronized before this workflow-only
  record. Creating this record consumes no additional builder attempt.

No Studio behavior is assessed or inferred by this review. ScreenGui rendering, text
visibility and comprehension, real replication timing, consecutive live replay,
two-player isolation, duplicate LocalScript bootstrap behavior, normal-control
playability, console output, and FP-09 late joining remain for the exact scoped Studio
checkpoint.

## Final disposition

**Ready for scoped Studio validation.** CodeRabbit's initial review and incremental
re-reviews are complete, every finding has a durable disposition, and the exact
corrected implementation has no unresolved BLOCKER, MAJOR, MINOR, or NIT finding.
TCK-0006 may advance to `CODE_REVIEW_PASS`; the next gate is the approved FP-01 through
FP-10 Studio evidence matrix with particular attention to countdown/result/reset
visibility, owner-specific objectives, replay cleanliness, two-player isolation,
duplicate bootstrap prevention, and required FP-09 late joining. This record does not
claim `STUDIO_PASS`, human approval, first-playable stopping-gate completion, merge, or
publishing authority.
