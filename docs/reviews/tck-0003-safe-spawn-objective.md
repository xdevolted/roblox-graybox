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
