# TCK-0005 independent gameplay review

**Review type:** External independent initial review and one re-review

**Independent reviewer:** CodeRabbit

**Base commit:** `a271be2b0139b04941dbc7f756933a6100459027`

**Initial reviewed commit:** `f77791f4d59de53717cda25ae1dace2bdf59c286`

**Corrected reviewed commit:** `b30f4f6d6ec31ba41697080822cb94d0e180c034`

**Pull request:** `#16`

**Contract:** Frozen first-playable scenarios and the owner-approved TCK-0005 Slice 5 server-owned failure and reliable replay plan

**Reviewer write boundary:** CodeRabbit changed no repository file. This durable record and the corresponding ticket-state transition are workflow-only changes made after the external review completed.

## Initial findings

### BLOCKER

None.

### MAJOR

1. **A failed objective reposition or Character load leaves the player in `RESETTING`.** CodeRabbit recommended a bounded retry or explicit escalation so a transient failure could not strand the player.

   **Disposition: withdrawn as outside the approved boundary.** The owner-approved TCK-0005 plan explicitly requires a failed objective move or Character load to remain in `RESETTING`, report through the server failure seam, and require owner intervention without an automatic or unbounded retry loop. The builder recorded this contract-based disposition on the review thread. CodeRabbit acknowledged it and withdrew the finding.

### MINOR

1. **Replay specifications indexed optional assignment/objective values before explicit non-nil guards.**

   **Disposition: resolved in `b30f4f6d6ec31ba41697080822cb94d0e180c034`.** The specifications now assert the original assignment and objective and every retained full-capacity assignment before property access. CodeRabbit confirmed the finding as addressed.

### NIT

1. **The adapter inferred the next generation as `generation + 1`.**

   **Disposition: resolved.** Reset completion now reads and validates the authoritative post-`START` state and uses its greater generation. Deterministic coverage proves that an authority-provided generation is retained without re-arming the deadline.

2. **A raised per-player update could abort the remaining heartbeat iteration.**

   **Disposition: resolved.** Each player's update is isolated with protected execution and a player-specific server failure report. Deterministic coverage proves that a raised seam error for one player does not prevent another player's valid failure observation.

3. **The sole ownership assumption for global `Players.CharacterAutoLoads` was undocumented.**

   **Disposition: resolved.** A concise comment now states that the adapter is the sole runtime owner while active and that other systems must not change the property before shutdown restores it.

4. **The eight-slot catalog size is duplicated in the safe-spawn/objective adapter.**

   **Disposition: intentionally unchanged.** The approved graybox contract freezes exactly eight canonical slots. Exporting a new catalog-size API would widen the public surface without serving the current slice.

5. **The cyclic slot scans could be extracted into a generic helper, and full-capacity overlap needed explanation.**

   **Disposition: partially adopted without unrelated refactoring.** The implementation now documents that full-capacity overlap is intentional and occupancy counts preserve exact release behavior. Extracting a generic helper was rejected as an unnecessary refactor outside the smallest coherent Slice 5 boundary.

6. **The late-join specification fires `PlayerAdded` twice.**

   **Disposition: clarified and retained.** The duplicate signal is deliberate idempotence coverage; a comment identifies that intent, and the existing exact-once Character-load assertion proves the repeated signal creates no duplicate initialization.

## Final findings

- BLOCKER: 0
- MAJOR: 0
- MINOR: 0
- NIT: 0

No unresolved review finding remains.

## Contract coverage and assumptions

- The server remains final authority for the active deadline, timeout, current-Humanoid death, current-Character void observation, immutable first terminal result, result/reset intervals, Character loading, objective reassignment, reset completion, and greater-generation replay.
- All terminal observations and deferred reset work remain scoped to the current Player, opaque session handle, lifecycle generation, phase, and per-operation token. Duplicate, stale, wrong-session, removed-player, or stopped-controller work cannot mutate authoritative state.
- `ObjectivePlacement.reassign` excludes the addressed player's immediately previous slot, prefers the first free different canonical slot, and uses only the approved deterministic overlap fallback at full eight-player capacity. Other assignments and objective identities remain unchanged.
- `SafeSpawnObjectiveAdapter.repositionObjective` moves the same server-owned objective Instance, preserves owner identity and other properties, and exposes no client, lifecycle, timer, Character, persistence, or presentation authority.
- `FailureReplayAdapter` owns one server heartbeat, the approved `20`/`2`/`1`-second intervals, the `Y = -20` void boundary, controlled Character loading, timing publication, failure/replay orchestration, and per-player cleanup. It creates no remote or client outcome path.
- A reset preparation failure intentionally does not falsely start a new round. It remains reported and blocked in `RESETTING` for owner intervention exactly as required by the approved plan.
- The corrected implementation diff remains limited to the nine authorized implementation, specification, ticket, and attempt-record files. Frozen acceptance scenarios, prior-ticket records, client files, dependencies, configuration, project mappings, persistence, economy, publishing, and Slice 6 remain unchanged.

## Check and review result

- Attempt 1's single authorized complete gate passed at initial implementation commit `f77791f4d59de53717cda25ae1dace2bdf59c286`: formatting, Selene, sourcemap generation, strict Luau analysis, 104 Lune tests, whitespace validation, and Rojo place build all passed.
- Exact-head push CI run `30414313230` and pull-request CI run `30414321056` passed for the initial implementation.
- CodeRabbit initial review `4803243850` inspected the complete base-to-implementation change and reported two actionable comments plus six nit comments.
- Attempt 2's single authorized complete gate passed at corrected commit `b30f4f6d6ec31ba41697080822cb94d0e180c034` with the same 104 passing tests and no lint, strict-analysis, whitespace, or build failure.
- Exact-head push CI run `30414883700` and pull-request CI run `30414885429` passed for the corrected implementation.
- CodeRabbit confirmed the optional-value guards as addressed, acknowledged and withdrew the reset-retry finding after comparison with the approved behavior, and completed its refreshed review with: “No actionable comments were generated in the recent review.”
- PR #16 was open, non-draft, cleanly mergeable, based on `main`, and pointed exactly to corrected reviewed head `b30f4f6d6ec31ba41697080822cb94d0e180c034` when this record was prepared.
- The implementation branch was clean and synchronized before this workflow-only record. No additional builder attempt was consumed.

No Studio behavior is assessed or inferred by this review. Real scheduler cadence, `Humanoid.Died`, void physics, `LoadCharacterAsync`, guarded respawn, objective movement, replication, multiplayer isolation, console output, and human-observed replay remain for the required Studio checkpoint.

## Final disposition

**Ready for human/Studio validation.** CodeRabbit's independent initial review and one re-review are complete, every finding has a durable disposition, and the exact corrected implementation has no unresolved BLOCKER, MAJOR, MINOR, or NIT finding. TCK-0005 may advance to `CODE_REVIEW_PASS`; the next gate is the approved Studio checkpoint for FP-03, FP-04, FP-05, FP-08, and FP-10 on the exact clean review-record commit after its CI passes.
