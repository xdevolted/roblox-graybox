# TCK-0003 independent gameplay review

**Review type:** Initial independent review

**Reviewed commit:** `214f2e85db584b1a98fbef02bccdfc88bb3afa3a`

**Pull request:** `#10`

**Contract:** Frozen first-playable scenarios and the owner-approved TCK-0003 safe-spawn and per-player objective foundation plan

**Reviewer write boundary:** This review document only

## Findings

No BLOCKER or MAJOR findings.

### MINOR

1. **SOA-01 does not verify the approved guard-wall descriptors.** In `tests/GameLoop/SafeSpawnObjectiveAdapter.spec.luau:150`, the test named `creates the exact arena and guarded spawn descriptors once` verifies that three `GUARD` records exist, but the assertions through line 190 inspect exact size and position only for the platform and spawn. They never assert the approved names, sizes, or positions of `StartBackWall`, `StartLeftWall`, and `StartRightWall`. This leaves the detailed TCK-0003 plan's SOA-01 requirement only partially covered: a later regression could move or resize a wall, close the required positive-Z exit, or change which side is guarded while all 59 deterministic tests still pass. The current production descriptors at `src/server/GameLoop/SafeSpawnObjectiveAdapter.luau:63` through line 82 are correct; the required correction is limited to deterministic assertions for all three wall descriptors and their intended parent.

No NIT findings.

## Contract coverage and assumptions

- `ObjectivePlacement` owns a private eight-slot canonical catalog with the exact approved coordinates. It validates an integer preference from one through eight, scans cyclically, creates a distinct frozen assignment identity, rejects duplicate players without mutation, rejects a ninth assignment as `NO_AVAILABLE_SLOT`, releases only the removed player's slot, and clears/inactivates the registry idempotently on destroy.
- `SafeSpawnObjectiveAdapter` creates one server-owned arena root, the exact platform, neutral spawn, three-wall guarded start with a positive-Z opening, and one objectives container. Objective Parts use the approved size, elevation, Neon-green appearance, collision/query/touch settings, owner UserId attribute, and slot attribute.
- The adapter connects both player signals before enumerating existing players. Per-player initialization guards prevent duplicate objectives during enumeration/`PlayerAdded` races, and a late join or overflow rejection preserves existing assignment and Instance identities.
- Player removal clears the adapter's objective association before destroying that objective and releases only the corresponding registry slot. `stop()` blocks later access and initialization, disconnects both signals, clears associations, destroys owned objectives and arena geometry, destroys registry state, and is idempotent.
- The frozen controller exposes only `getAssignment`, `getObjective`, and `stop`. The implementation adds no remote, character observer, touch/occupancy observer, timer, delayed task, lifecycle event, success/failure/reset/replay transition, respawn orchestration, or client presentation path.
- `Bootstrap.server.luau` starts and retains one safe-spawn/objective controller after the existing round controller. The TCK-0001/TCK-0002 public modules and tests are unchanged, and the new adapter does not call or inspect their state/event APIs.
- The approved overflow behavior is an initial-assignment rule: a ninth connected player remains unassigned when all eight slots are occupied. Automatic assignment of a previously rejected connected player after a later slot release is not inferred; the plan limits TCK-0003 to initial assignment.
- The reviewed diff contains exactly the seven authorized implementation/workflow files: the three production files, two deterministic specification files, ticket state/accounting record, and builder-attempt record. Frozen scenarios, the merged plan, prior-ticket files, client code, dependencies, configuration, and project mappings are unchanged.

## Check result

- The committed attempt record reports that the sole authorized complete `Checks.ps1` run passed at the reviewed implementation: StyLua; Selene with 0 errors, 0 warnings, and 0 parse errors; sourcemap generation; strict Luau analysis with no diagnostics; 59 Lune tests passed and 0 failed; all whitespace checks; and the Rojo build.
- Both GitHub PR #10 `checks` runs were complete and successful at reviewed head `214f2e85db584b1a98fbef02bccdfc88bb3afa3a`. The PR was open, cleanly mergeable, and based on `main` commit `991a4af21356f79ca237aa906e13978bd87c1da9` when inspected.
- Independent read-only inspection confirmed the exact seven-file diff, a clean worktree before this review artifact, no diff whitespace errors, and no prohibited production references to remotes, lifecycle transitions, character observation, delayed tasks, respawn calls, or touch/occupancy qualification.
- Per the authorization, the reviewer did not run `scripts/Checks.ps1` or another complete gate.

No Studio behavior was assessed or inferred by this review.

## Disposition

**Changes required.** The implementation has no BLOCKER or MAJOR defect, but the planned SOA-01 deterministic evidence is incomplete until the exact three guard-wall descriptors are asserted. TCK-0003 should remain at `STATIC_PASS`; the reviewer did not change implementation or tests, advance the ticket, begin Studio, or consume another builder attempt.

## Independent re-review

**Review type:** One authorized independent re-review

**Initial implementation commit:** `214f2e85db584b1a98fbef02bccdfc88bb3afa3a`

**Initial review-record commit:** `8242738c16e239373f8bf518cdd96c060c8ee558`

**Corrected implementation commit:** `de47e3e2297eca05040d82a095d1a91144d36a6b`

### Final findings

- BLOCKER: 0
- MAJOR: 0
- MINOR: 0
- NIT: 0

No new or remaining findings.

### Resolution of the original MINOR

**Resolved.** SOA-01 now obtains exactly three `GUARD` records and defines independent plan-derived expectations for `StartBackWall`, `StartLeftWall`, and `StartRightWall` in `tests/GameLoop/SafeSpawnObjectiveAdapter.spec.luau:165` through line 210. The loop at lines 212 through 231 rejects an unexpected or duplicate name and independently checks each wall's exact `Part` class, arena-root parent, size, and position. Lines 233 through 240 require all three expected names and distinct Instance identities. Therefore, a missing, duplicate, unexpected, renamed, resized, repositioned, reparented, non-`Part`, or identity-aliased guard wall fails deterministically.

The expectations are not obtained from `SafeSpawnObjectiveAdapter`. Their literal names, sizes, and positions match the approved contract at `docs/features/first-playable/plan.md:227` through line 229, independently of the production descriptors at `src/server/GameLoop/SafeSpawnObjectiveAdapter.luau:63` through line 82.

### Complete implementation revalidation

- `ObjectivePlacement` retains the exact private eight-slot catalog at `src/shared/GameLoop/ObjectivePlacement.luau:24` through line 34, validates the preferred index and assigns by a deterministic cyclic first-free scan at lines 36 through 71, and returns `NO_AVAILABLE_SLOT` without mutation after all eight slots are occupied. Its immutable per-player assignments, isolated removal, and idempotent destruction remain covered by OPL-01 through OPL-09 in `tests/GameLoop/ObjectivePlacement.spec.luau`.
- `SafeSpawnObjectiveAdapter` remains exclusively server-owned: it creates the approved arena and inert objective geometry, connects `PlayerAdded` and `PlayerRemoving` before enumeration, guards duplicate initialization, keeps one objective association per assigned Player, and leaves existing assignments and Instance identities stable during late join and overflow. The adapter exposes only `getAssignment`, `getObjective`, and `stop` at `src/server/GameLoop/SafeSpawnObjectiveAdapter.luau:260` through line 264.
- Player removal invalidates only the addressed adapter association before Instance destruction and slot release at `src/server/GameLoop/SafeSpawnObjectiveAdapter.luau:199` through line 211. `stop()` disconnects both signals, clears all associations, destroys owned Instances and registry state, and is idempotent at lines 236 through 258. SOA-04 through SOA-09 cover duplicate signals, late-join isolation, character-reload non-observation, per-player cleanup, ninth-player overflow, and shutdown.
- The production slice still introduces no remote, client ingress, character observer, touch/occupancy qualification, lifecycle transition, timer, delayed task, respawn orchestration, persistence, economy, or client presentation. Objective qualification and success, failure observation, reset/replay, and feedback remain deferred exactly as approved. `Bootstrap.server.luau` still starts one safe-spawn/objective controller after the existing round controller and makes no other runtime change.
- Attempt 2 changed only `docs/implementation/tck-0003-builder-attempts.md`, `docs/tickets/TCK-0003.json`, and `tests/GameLoop/SafeSpawnObjectiveAdapter.spec.luau` in correction commit `de47e3e2297eca05040d82a095d1a91144d36a6b`. No production source file or runtime behavior changed after the initial implementation commit.

### Re-review check result

- The infrastructure-only retry of pull-request CI run `29815068801`, attempt 2, tested exact commit `de47e3e2297eca05040d82a095d1a91144d36a6b` and completed successfully. Repository checkout, Rokit 1.2.0 installation, pinned dependency setup, deterministic checks, and job completion all passed; the deterministic stage reported 59 tests passed and 0 failed.
- Push CI on the same corrected commit remained successful. PR #10 was open, cleanly mergeable, and limited to the eight authorized implementation, test, ticket, attempt, and review files when re-inspected.
- Read-only Git inspection confirmed the exact original and correction commits, no diff whitespace errors, synchronized local/remote implementation heads, and no production/runtime delta in attempt 2. The reviewer did not run `scripts/Checks.ps1`, edit reviewed code or tests, perform Studio work, advance the ticket, commit, push, or consume another builder attempt.

No Studio behavior was assessed or inferred by this re-review.

### Final disposition

**Ready for human/Studio validation.** The original MINOR is resolved, the corrected implementation has zero BLOCKER, MAJOR, MINOR, and NIT findings, and the re-review threshold is met. The initial findings and disposition above remain preserved as historical review evidence.
