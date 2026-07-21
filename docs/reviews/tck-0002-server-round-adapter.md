# TCK-0002 independent gameplay review

**Review type:** Initial independent review

**Reviewed commit:** `a263d050059bd81bfdba47852fd94fc926ca8f63`

**Pull request:** `#7`

**Contract:** Frozen first-playable scenarios and the owner-approved TCK-0002 server-authoritative per-player adapter plan

**Reviewer write boundary:** This review document only

## Findings

No BLOCKER, MAJOR, MINOR, or NIT findings.

The implementation satisfies the approved TCK-0002 contract:

- `PlayerRoundRegistry` owns one immutable `RoundLifecycle` state and one distinct frozen session-handle identity per player key. Duplicate initialization, unknown players, wrong or replaced handles, destroyed registries, malformed events, invalid transitions, and stale or future generations reject without state replacement or publication.
- Lifecycle behavior remains delegated to `RoundLifecycle`; the adapter does not duplicate transition rules. Its exhaustive local rejection normalization narrows only the four documented lifecycle rejection literals and fails explicitly if the model ever returns an undocumented value.
- `PlayerRoundAdapter` loads the canonical Roblox module only inside the default registry factory. Lune tests inject `PlayerRoundRegistry.new`, so test construction does not access `game`; production construction resolves `ReplicatedStorage.Shared.GameLoop.PlayerRoundRegistry` through the Rojo mapping.
- The structural contracts are narrow around lifecycle state, rejection values, publisher, registry, and factory. Broad values are confined to the intentionally generic player-key, raw trusted-event, Players-like test seam, and attribute-value boundaries; there are no type suppressions or unchecked casts in the TCK-0002 production modules.
- The only mutation entry point is the server-side controller. No remote, client script, or client-callable outcome path was added, and session handles are stored only in server memory and are never written to attributes.
- Player signals connect before existing-player enumeration. The initializing and duplicate guards make connect/enumerate races and repeated `PlayerAdded` signals deterministic without a second start or generation increment.
- Accepted state identities alone replace registry state and publish snapshots. Rejected duplicate, wrong-session, invalid-phase, stale, future, and malformed events preserve state and do not republish attributes.
- Leave cleanup removes the registry entry before its removal publication, clears the four approved attributes, and invalidates the old handle. Rejoining creates a distinct handle, and retained old-handle or old-publisher callbacks cannot mutate or publish over the replacement session.
- `stop()` disconnects both owned signals before destroying registry state, clears every remaining player's attributes and handle, and is idempotent. No timer, delayed task, character listener, geometry observer, or other per-player work was introduced that could survive cleanup.
- Reset and replay remain model-driven and generation-safe. Tests cover accepted reset/replay, duplicate reset/finish/start rejection, clean greater generations, terminal-result immutability, and cross-player isolation.
- `Bootstrap.server.luau` starts exactly one adapter controller and retains it for server lifetime. The diff adds no framework, service container, networking abstraction, dependency, configuration change, geometry, timer, character observation, client feedback, persistence, economy, publishing, multiple-place work, or Phase 2 infrastructure.

## Contract coverage and assumptions

- TCK-0002 provides only the adapter portions assigned to FP-01 through FP-10: per-player initialization, server-only lifecycle submission, isolation, generation validation, accepted-snapshot publication, disconnect cleanup, late joining, and reset/replay safety. Spawn geometry, safe-zone qualification, timers, death/void observation, respawn, result/reset intervals, and client presentation remain explicitly blocked on later slices and are not treated as defects here.
- The controller is reachable only from server code under `ServerScriptService`. Future observation adapters are assumed to capture the current session handle and generation and to own and cancel their own connections or delayed work; TCK-0002 intentionally creates none.
- Four separately replicated attributes can be transiently observed between writes. The approved plan explicitly accepts that as presentation-only partial replication; no authoritative decision reads those attributes.
- Roblox `Player:SetAttribute(name, nil)` removes the corresponding attribute. Studio must still verify the real service, Instance, replication, connection, and cleanup behavior on the exact reviewed commit before `STUDIO_PASS` can be claimed.
- The reviewed diff is limited to the seven approved TCK-0002 files. `RoundLifecycle`, its frozen specifications, acceptance scenarios, product decisions, dependencies, configuration, Rojo mapping, and client code are unchanged.

## Check result

- Independent read-only verification at `a263d050059bd81bfdba47852fd94fc926ca8f63`: `git diff --check`, StyLua format check, Selene lint, and `luau-lsp analyze` passed with no diagnostics. The Lune harness reported 40 passed and 0 failed, including 12 adapter, 16 registry, 10 lifecycle, and 2 prototype-controller cases.
- The committed complete `Checks.ps1` gate recorded StyLua, Selene, sourcemap generation, Luau analysis, all 40 Lune tests, whitespace validation, and Rojo build as passed.
- Both GitHub PR #7 `checks` runs were green when reviewed.
- The generated sourcemap maps `PlayerRoundRegistry` once under `ReplicatedStorage.Shared.GameLoop` and `PlayerRoundAdapter` once under `ServerScriptService.Server.GameLoop`.

No Studio behavior was assessed or inferred by this review.

## Disposition

**Ready for human/Studio validation.** There are no review blockers or requested implementation/test changes. The truthful next workflow transition is to `CODE_REVIEW_PASS` after the repository-required post-review gate and review-record commit, followed by the approved narrow Studio checkpoint on that exact clean commit.
