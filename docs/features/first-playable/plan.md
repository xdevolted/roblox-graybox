# First playable slice plan

## Contract

The frozen scenarios in `acceptance-tests.md` are the behavioral contract. Each player owns an independent server-authoritative lifecycle. Success follows server-confirmed safe-zone entry immediately; a late joiner starts an independent round immediately. Later Roblox adapters translate engine observations into the pure lifecycle without giving clients authority over outcomes.

## Slice 1 — TCK-0001 pure round lifecycle

### Behavior

Represent one player's lifecycle as an immutable value with:

- `phase`: `WAITING`, `ACTIVE`, `RESULT`, or `RESETTING`.
- `generation`: a nonnegative integer that increases exactly once on each accepted `START`.
- `result`: `SUCCESS`, `FAILURE`, or `nil`.
- `failureReason`: `TIMEOUT`, `DEATH`, `VOID`, or `nil`.

Expose a pure constructor and transition function. Accepted transitions return a new immutable value. Rejected transitions return the original value unchanged plus a deterministic rejection reason.

| Current phase | Event | Required context | Next phase | State effect |
| --- | --- | --- | --- | --- |
| `WAITING` | `START` | No generation supplied | `ACTIVE` | Increment generation; clear result and failure reason |
| `ACTIVE` | `SUCCEED` | Matching generation | `RESULT` | Set immutable success result |
| `ACTIVE` | `FAIL` | Matching generation and a valid failure reason | `RESULT` | Set immutable failure result and reason |
| `RESULT` | `BEGIN_RESET` | Matching generation | `RESETTING` | Clear the displayed result and failure reason |
| `RESETTING` | `FINISH_RESET` | Matching generation | `WAITING` | Preserve generation, ready for replay |

All other state/event combinations are invalid. Malformed events, stale or future generations, missing failure reasons, and duplicate terminal/reset/start events are rejected without mutation. The first accepted terminal result cannot be replaced.

### Deterministic specifications

- Constructor produces generation zero in `WAITING` with no result.
- Start increments generation and produces a clean `ACTIVE` state.
- Success and each allowed failure reason terminate only the matching active generation.
- Success cannot be replaced by failure; failure cannot be replaced by success or another failure.
- Stale and future-generation events are rejected without mutation.
- Events valid in another phase are rejected without mutation.
- Reset clears terminal data and returns to `WAITING` without changing generation.
- Replay increments generation exactly once and starts cleanly.
- Repeated start, terminal, reset, and finish events are deterministic no-ops after the first accepted event.
- Malformed event shape/type and invalid failure reason are rejected.

### Boundaries and exclusions

- Files: one engine-free module under `src/shared/`, its Lune spec under `tests/`, and `docs/tickets/TCK-0001.json`.
- No `game`, `script`, Instances, Roblox services, clocks, tasks, remotes, players, characters, positions, safe-zone geometry, spawn/reset calls, UI, or persistence.
- The model represents a single player's state and does not store player identity. Isolation is enforced by later server adapters owning one model per player.
- Risk: low, pure deterministic rules. Attempt budget: three builder attempts.
- Exit evidence: all relevant pure portions of FP-02 through FP-07 and FP-10 pass as Lune specifications, the complete `Checks.ps1` gate passes, and an independent review has no unresolved blockers.

## Slice 2 — Server-authoritative per-player adapter

**Ticket:** `TCK-0002` — Server-authoritative per-player round adapter

**Plan status:** Proposed. The owner must explicitly approve this detailed slice before the ticket may advance from `ACCEPTANCE_TESTS_FROZEN` to `PLAN_APPROVED` or the implementation branch may be created.

### Behavior and authority boundary

- Own exactly one `RoundLifecycle` state and one opaque server session handle for each connected player.
- Initialize a joining player once, immediately apply the model's `START` event, and publish the resulting clean `ACTIVE` generation without changing any other player.
- Accept lifecycle events only through a server-only adapter API used by later trusted observation adapters. There is no client-callable start, success, failure, reset, timer, or generation API.
- Require the current player session handle for every server event. The underlying `RoundLifecycle` continues to validate phase, event shape, failure reason, and matching generation.
- Publish only a read-only snapshot for later primitive feedback. This slice creates no client controller or UI and consumes no client request.
- Remove the player's state and invalidate its session handle before cleanup completes. Repeated cleanup is a deterministic no-op.
- Preserve reset and replay correctness when trusted later adapters send `BEGIN_RESET`, `FINISH_RESET`, and `START`; this slice does not schedule those events or implement their intervals.

### Design and APIs

#### Engine-free player registry

Add a small `PlayerRoundRegistry` beside `RoundLifecycle`. It is not a replacement for or modification of the pure lifecycle model. It owns a map from opaque player keys to `{ state, sessionHandle }` entries and receives one injected snapshot publisher so its behavior is deterministic under Lune.

Planned API:

| API | Responsibility |
| --- | --- |
| `new(publishSnapshot)` | Construct an empty registry with no Roblox globals or Instances. |
| `initialize(playerKey)` | Reject a duplicate key; otherwise create a lifecycle, accept exactly one `START`, store it, publish once, and return a new opaque session handle. |
| `applyServerEvent(playerKey, sessionHandle, event)` | Reject unknown players or a non-current handle, delegate to `RoundLifecycle.transition`, store and publish only an accepted new state, and return the model or registry rejection. |
| `getState(playerKey)` | Return the current immutable lifecycle state or `nil`; callers cannot mutate it. |
| `remove(playerKey)` | Invalidate and remove the entry before publishing removal; return false without side effects when already absent. |
| `destroy()` | Invalidate all handles, remove all entries, publish removals, and make later operations reject deterministically. |

Registry-level rejections are limited to `DUPLICATE_PLAYER`, `UNKNOWN_PLAYER`, `SESSION_MISMATCH`, and `DESTROYED`; lifecycle rejections remain the existing `RoundLifecycle.Rejection` values. Session-handle identity prevents a delayed callback captured before remove/destroy from mutating a replacement session for the same logical player. Rejected duplicate, stale, future, cross-session, or invalid-phase events do not republish state.

#### Thin Roblox server adapter

Add one server adapter that owns the `Players.PlayerAdded` and `Players.PlayerRemoving` connections and a single registry. It connects both signals before enumerating `Players:GetPlayers()` so startup cannot miss a player; the registry's duplicate guard makes the connect/enumerate race harmless. `Bootstrap.server.luau` starts this adapter once and retains its controller for the server lifetime.

For deterministic adapter tests, construction may accept only a Players-like dependency, registry constructor, and attribute writer with the exact operations the adapter uses. Normal production construction defaults to the real Roblox `Players` service, the real registry, and `Player:SetAttribute`. This seam must not become a framework, service container, generalized signal abstraction, networking layer, or additional runtime architecture.

The controller exposes only server-side methods to obtain the current session handle, submit a trusted lifecycle event with that handle, inspect an immutable state for other server adapters, and stop. No method is connected to a `RemoteEvent` or `RemoteFunction`.

The injected publisher writes these server-owned attributes on the corresponding `Player` and removes them during cleanup:

- `GrayboxRoundPhase`
- `GrayboxRoundGeneration`
- `GrayboxRoundResult`
- `GrayboxRoundFailureReason`

Clients may later read these attributes for presentation. Local client changes cannot become server authority, and later client presentation must treat the server replication stream as its source. Four attributes are sufficient for the current model, avoid a networking abstraction, and require no new Instances or remotes.

### Event flow and cleanup ownership

1. Server bootstrap starts the adapter once.
2. The adapter connects join/leave signals, then initializes any players already present.
3. Join initialization creates a fresh opaque session handle, transitions `WAITING → ACTIVE` exactly once, stores the immutable state, and publishes the four attributes.
4. A later server-owned observer captures the current handle and generation, then submits an event. The registry first validates player/session ownership and then delegates lifecycle validation.
5. Accepted events replace only that player's immutable state and republish it. Rejected events preserve every player's state and publish nothing.
6. On leave, the adapter removes its player-to-handle association and the registry invalidates/removes the entry before attributes are cleared. Any callback holding the old handle is rejected afterward.
7. `stop()` disconnects the two global signals and destroys the registry. TCK-0002 introduces no timers, `task.delay`, character listeners, zone listeners, or per-player coroutines.

The server adapter owns Roblox signal connections and Player attributes. The registry owns lifecycle entries and handle validity. Future timer, character, and geometry adapters must own and cancel their own work; the required handle plus generation prevents any missed late callback from mutating a cleaned-up or replayed session.

### Exact planned implementation files

| File | Planned responsibility |
| --- | --- |
| `src/shared/GameLoop/PlayerRoundRegistry.luau` | Engine-free per-player ownership, session-handle validation, lifecycle delegation, snapshot publication seam, and deterministic cleanup. |
| `src/server/GameLoop/PlayerRoundAdapter.luau` | Thin `Players` integration, server-only controller API, Player attribute publication, join/leave wiring, and connection cleanup. |
| `src/server/Bootstrap.server.luau` | Start exactly one adapter controller; no other gameplay behavior. |
| `tests/GameLoop/PlayerRoundRegistry.spec.luau` | Complete deterministic registry, authority, isolation, stale-event, cleanup, and replay coverage with fake player keys and a recording publisher. |
| `tests/GameLoop/PlayerRoundAdapter.spec.luau` | Deterministic Players signal ordering, duplicate-start protection, attribute publication, session secrecy, leave cleanup, shutdown, and retained-callback coverage using narrow fakes. |

`RoundLifecycle.luau`, `RoundLifecycle.spec.luau`, all client files, the frozen scenarios, and product-decision documents are not planned to change. No package, project-map, configuration, framework, service container, generalized networking layer, or dependency upgrade is required.

### Deterministic Lune test matrix

| ID | Test |
| --- | --- |
| PRR-01 | A new registry is empty and returns no state for an unknown player. |
| PRR-02 | First initialization creates one frozen `ACTIVE` generation-one state, one handle, and exactly one published snapshot. |
| PRR-03 | Duplicate initialization is rejected without a second handle, transition, generation increment, or publication. |
| PRR-04 | Two players initialize independently; neither state or handle aliases the other. |
| PRR-05 | An accepted success or failure changes and publishes only the addressed player's state. |
| PRR-06 | A duplicate terminal observation is rejected without mutation or republishing and cannot replace the first result. |
| PRR-07 | Stale-generation and future-generation events are rejected without mutation or republishing. |
| PRR-08 | An event for an unknown or disconnected player is rejected without affecting a connected player. |
| PRR-09 | A handle belonging to another player or an earlier session is rejected, preventing cross-player/session leakage. |
| PRR-10 | Remove invalidates the handle, removes state, publishes removal once, and repeated remove is a no-op. |
| PRR-11 | A simulated delayed callback using an old handle after remove and reinitialize is rejected and cannot mutate the replacement session. |
| PRR-12 | `BEGIN_RESET → FINISH_RESET → START` produces one clean greater generation with no carried result or failure reason. |
| PRR-13 | Duplicate reset, finish, or replay-start events do not corrupt state or generate duplicate publications. |
| PRR-14 | Malformed events and invalid failure reasons preserve the current state and publisher history. |
| PRR-15 | Destroy removes every player independently, invalidates all handles, disconnect-seam cleanup is idempotent, and later operations reject as destroyed. |
| PRR-16 | Every published non-nil snapshot is the same immutable state accepted from `RoundLifecycle`; rejected operations never publish. |

Thin adapter wiring matrix:

| ID | Test |
| --- | --- |
| PRA-01 | `PlayerAdded` and `PlayerRemoving` are connected before existing players are enumerated. |
| PRA-02 | A player present during startup is initialized exactly once. |
| PRA-03 | A connect/enumeration race or duplicate `PlayerAdded` does not create a second lifecycle or session. |
| PRA-04 | Two players remain isolated through initialization, accepted transitions, and publication. |
| PRA-05 | Accepted snapshots write exactly the four approved server-owned attributes with the accepted values. |
| PRA-06 | Rejected, duplicate, stale, future, wrong-session, and invalid events do not republish attributes. |
| PRA-07 | Session handles are never written to attributes, returned through replication, or otherwise exposed to clients. |
| PRA-08 | `PlayerRemoving` removes and invalidates only that player without changing another player. |
| PRA-09 | `stop()` disconnects every owned signal connection, destroys registry state, and is idempotent. |
| PRA-10 | Signals fired after `stop()` cannot initialize, mutate, publish, or recreate state. |
| PRA-11 | Registry or publication callbacks retained from an old session cannot mutate a rejoined player. |
| PRA-12 | Production and test construction introduce no `RemoteEvent`, `RemoteFunction`, or client-authoritative transition path. |

The existing `RoundLifecycle.spec.luau` suite remains unchanged and continues to prove the model's event-shape, phase, generation, terminal immutability, reset, and replay rules.

### Frozen-scenario coverage

| Scenario | TCK-0002 contribution | Still blocked after this slice |
| --- | --- | --- |
| FP-01 | Exactly one authoritative lifecycle starts immediately on join; duplicate initialization is rejected. | Character spawn, guarded start, safe-zone placement, and timer. |
| FP-02 | Trusted success events are generation-scoped and first-result immutable. | Server safe-zone geometry and qualification observation. |
| FP-03 | A trusted `TIMEOUT` failure can be translated without client authority. | Authoritative timer and expiry scheduling. |
| FP-04 | Trusted `DEATH` and `VOID` failures can be translated and deduplicated. | Character death and void-boundary observers. |
| FP-05 | Reset/replay events remain per-player, clean, and generation-safe. | Result/reset intervals, respawn, safe-zone replacement, and timer restart. |
| FP-06 | No result remote or client transition API exists; all mutation entry points are server-only. | Later client/replication layers must preserve the same no-authority boundary. |
| FP-07 | Duplicate, stale, future, wrong-session, and invalid-phase events are deterministic no-ops. | Later observation sources must attach the correct handle and generation. |
| FP-08 | Player state/handle removal is deterministic and leaves other players unchanged. | Cleanup of later character, timer, geometry, and feedback listeners. |
| FP-09 | A late joiner gets exactly one independent active lifecycle without changing existing states. | Safe spawn, objective placement, and a running timer. |
| FP-10 | Registry-level reset and replay produce clean greater generations without duplicate bootstrap. | Real success/failure sources, intervals, respawn, timer, and different zone placement. |

No complete first-playable scenario is claimed by TCK-0002 alone.

### Required Studio checkpoint after implementation and review

Use the exact clean implementation/review commit only after `Checks.ps1` passes and independent review has no unresolved blocker. Record the commit, Studio place, Rojo/MCP connection, player count, warnings/errors, observations, and remaining limitations.

1. Build and synchronize the root project; confirm `PlayerRoundRegistry` maps once under `ReplicatedStorage.Shared.GameLoop` and `PlayerRoundAdapter` maps once under `ServerScriptService.Server.GameLoop`.
2. Start a one-player session and confirm the Player immediately receives `ACTIVE`, generation `1`, nil result, and nil failure attributes exactly once, with no server/client warning or error caused by the slice.
3. Respawn the same character and confirm character creation alone does not duplicate player initialization or increment the generation.
4. In a local server session, add a late second player after the first is active; confirm the second player receives an independent `ACTIVE` generation `1` state and the first player's attributes do not change.
5. Remove one player; confirm the remaining player's attributes and lifecycle do not change and no late callback, duplicate transition, or cleanup error is observed.
6. Confirm no result `RemoteEvent`/`RemoteFunction` or client transition path exists. A client-local attribute edit must not mutate the server-observed snapshot or another player.
7. Run an unsaved server-side smoke check against the mapped registry for duplicate initialization, wrong handle, stale/future generation, accepted terminal result, removal, old-handle rejection, and clean reset/replay; create or save no Studio instances or scripts.
8. Stop play mode and record all server/client warnings and errors, including an explicit zero count when none occur.

This checkpoint may support only the TCK-0002 portions of FP-01, FP-02 through FP-10 listed above. It cannot claim spawn geometry, zone qualification, timers, death/void detection, respawn, visual feedback, or a complete first-playable loop.

### Risks and controls

- **Authority leakage:** a remote or client callback could become a transition ingress. Control: no remotes and no client changes; controller methods exist only in server code.
- **Duplicate bootstrap:** connect/enumerate ordering can observe a player twice. Control: connect first and enforce registry duplicate rejection without generation change.
- **Cross-player leakage:** a reused key or wrong handle could target another entry. Control: opaque per-session handle identity plus player-key match before lifecycle delegation.
- **Late asynchronous work:** callbacks can fire after leave, adapter stop, or replacement initialization. Control: invalidate entries before cleanup and require current handle plus generation for every event.
- **Replay corruption:** duplicated reset/start signals can increment or carry state incorrectly. Control: delegate all transitions to the immutable model and publish accepted states only.
- **Partial replication:** multiple attributes can be observed between writes. This affects presentation only, never authority; later feedback reads a full snapshot after change and must tolerate transient presentation refreshes.
- **Cleanup leaks:** global Player connections or registry entries can survive shutdown. Control: one controller owns both connections and an idempotent `stop()` destroys the registry.

Risk is medium because this slice establishes gameplay authority and Roblox lifecycle ownership. The builder has two attempts. Any second failed full-gate attempt stops implementation and requires human direction rather than broader architecture.

### Rollback and exit evidence

Rollback is a normal `git revert` of the TCK-0002 implementation commit/PR. The slice owns no persistence, economy, published assets, migrations, place topology, or irreversible data. Removing the bootstrap start restores the prior inert server bootstrap; deleting the two new modules/tests removes the slice.

Implementation exit requires the complete deterministic gate, all planned Lune cases, an independent review with no unresolved blockers, and the scoped human Studio evidence above. Ticket advancement remains sequential: `PLAN_APPROVED → BUILDING → STATIC_PASS → CODE_REVIEW_PASS → STUDIO_PASS → HUMAN_APPROVED → MERGED`. No later state is inferred from headless checks.

## Slice 3 — TCK-0003 safe spawn and per-player objective foundation

**Ticket:** `TCK-0003` — Server-owned safe spawn and per-player objective placement

**Plan status:** Proposed. The owner must explicitly approve this detailed slice before the ticket may advance from `ACCEPTANCE_TESTS_FROZEN` to `PLAN_APPROVED`, an implementation branch may be created, or a builder attempt may be consumed.

### Exact behavioral boundary

TCK-0003 creates the inert world and assignment foundation needed before authoritative objective observation:

- At server startup, create exactly one server-owned placeholder arena under `Workspace`: one anchored gray platform, one shared neutral `SpawnLocation`, three anchored guard walls around the start with one open exit, and an objectives container.
- Use a `96 x 1 x 96` platform centered at `(0, 0, 0)`. Its top surface is at `Y = 0.5`.
- Use a `16 x 1 x 16` `SpawnLocation` centered at `(0, 1, 0)`. Guard walls rest on the platform: a `20 x 4 x 1` back wall centered at `(0, 2.5, -10)`, plus `1 x 4 x 20` left and right walls centered at `(-10, 2.5, 0)` and `(10, 2.5, 0)`. The start is open toward positive Z so normal character movement can leave it.
- Give every connected player exactly one server-created, anchored, non-collidable, queryable/touch-capable `10 x 0.5 x 10` Neon green objective Part. The Part center uses `Y = 0.75`, so it rests on the platform without replacing the platform floor.
- Assign objectives to one of eight immutable candidate slots, relative to the arena origin: `1=(-30,-30)`, `2=(0,-30)`, `3=(30,-30)`, `4=(-30,0)`, `5=(30,0)`, `6=(-30,30)`, `7=(0,30)`, and `8=(30,30)`. Every slot is inside the platform margin and outside the guarded start.
- Associate each objective with exactly one current Player in server memory. The objective carries server-written `GrayboxObjectiveOwnerUserId` and `GrayboxObjectiveSlot` attributes for inspection and later presentation; clients do not write or decide either value.
- Replicate the server-created arena and objectives normally. With multiple players, all objective Parts are temporarily visible to every client; owner-specific filtering or labels belong to the later client-feedback slice and are not required for this foundation.
- Keep the merged round state unchanged. Entering or touching an objective in TCK-0003 produces no lifecycle event and no success result.

This deliberately splits the earlier high-level Slice 3 description. Safe-zone qualification and the validated `SUCCEED` path become Slice 4. Combining world construction, player assignment, physics observation, and an authority-sensitive terminal transition would not be the smallest independently verifiable slice.

### Server authority, ownership, and isolation

- The server owns arena construction, spawn configuration, objective-slot selection, player association, metadata, and cleanup. No client API, `RemoteEvent`, or `RemoteFunction` is introduced.
- One thin Roblox adapter owns the arena root, its geometry, `Players.PlayerAdded`/`PlayerRemoving` connections, the per-player objective Instance map, and shutdown cleanup.
- One engine-free placement registry owns candidate availability and immutable per-player assignments. It contains no Roblox globals, Instances, characters, physics, lifecycle transitions, or clocks.
- Each connected player receives a different occupied slot while capacity remains. A join, leave, character reload, or duplicate signal for one player cannot move, replace, or remove another player's objective.
- The approved experience supports at most eight players, matching the eight slots. A ninth assignment returns `NO_AVAILABLE_SLOT`, creates no objective, and preserves all existing assignments; it does not change round state.
- Player removal invalidates the adapter's association before destroying that player's objective and releasing only that slot. Repeated removal is a no-op. `stop()` disconnects both player signals, invalidates every association, destroys all owned objectives and arena geometry, destroys the placement registry, and is idempotent.

### Spawn and respawn assumptions

- TCK-0003 relies on Roblox's normal neutral `SpawnLocation` behavior for initial character placement and later default character reloads. It does not call `LoadCharacter`, `PivotTo`, or schedule a respawn.
- The shared spawn pad and three walls provide the minimum safe initial placement on the platform. Per-player spawn lanes, checkpoints, force-field tuning, and custom respawn ordering are not introduced.
- Character creation or reload does not create a new assignment, move an objective, increment the round generation, or add a character listener. Reliable result-driven respawn and replay remain in Slice 5.

### Deterministic placement rules and APIs

Add an engine-free `ObjectivePlacement` module containing the immutable slot catalog and a small assignment registry. Coordinates are plain numbers; the Roblox adapter alone translates them to `Vector3`/`CFrame` values.

Planned registry API:

| API | Responsibility |
| --- | --- |
| `new()` | Construct an empty registry over the eight canonical slots. |
| `assign(playerKey, preferredIndex)` | Validate an integer index from 1 through 8, reject a duplicate player, then scan cyclically from that index and reserve the first free slot. Return one frozen `{ slotId, x, z }` assignment or `INVALID_PREFERENCE`, `DUPLICATE_PLAYER`, `NO_AVAILABLE_SLOT`, or `DESTROYED`. |
| `get(playerKey)` | Return the current frozen assignment or `nil`; callers cannot mutate it. |
| `remove(playerKey)` | Remove only that player's assignment and release its slot; repeated removal returns false without side effects. |
| `destroy()` | Invalidate every assignment and make later assignment attempts reject as `DESTROYED`; repeated destruction is a no-op. |

Production derives the preferred index as `(math.abs(player.UserId) % 8) + 1`. A narrow injected preferred-index function permits stable fake-player tests without changing production selection. Collision resolution is the fixed cyclic slot order, not randomness. TCK-0003 performs only initial assignment; previous-slot exclusion, objective movement, and replay selection are deferred until Slice 5, which must preserve the frozen requirement that a replay not reuse the immediately previous position.

### Thin Roblox adapter and merged-round interaction

Add `SafeSpawnObjectiveAdapter.start()` with optional narrow test dependencies for a Players-like source, world/Instance construction operations, placement-registry factory, and preferred-index function. Production defaults to `Players`, `Workspace`, `Instance.new`, the real placement registry, and the UserId-derived index. The seam must not become a service container, framework, generalized Instance abstraction, or networking layer.

The frozen controller exposes only:

| API | Responsibility |
| --- | --- |
| `getAssignment(player)` | Return the player's immutable slot assignment or `nil`. |
| `getObjective(player)` | Return the currently owned objective Instance or `nil`. This is the smallest server-only seam for a later objective observer. |
| `stop()` | Perform idempotent signal, player-assignment, objective, registry, and arena cleanup. |

`Bootstrap.server.luau` continues to start and retain exactly one `PlayerRoundAdapter` controller, then starts and retains exactly one safe-spawn/objective controller. TCK-0003 does not call `getSessionHandle`, `getState`, or `applyServerEvent`, does not edit the round adapter, and does not read replicated attributes as authority. Slice 4 will combine `getObjective(player)` with the current round controller handle and generation when translating a server-confirmed qualification into `SUCCEED`.

### Exact implementation and workflow files

Builder implementation is limited to these paths:

| File | Planned responsibility |
| --- | --- |
| `src/shared/GameLoop/ObjectivePlacement.luau` | Immutable slot catalog, deterministic assignment, capacity, isolation, removal, and destroy behavior. |
| `src/server/GameLoop/SafeSpawnObjectiveAdapter.luau` | Server-owned arena/SpawnLocation/objective construction, Player wiring, association metadata, read-only objective seam, and cleanup. |
| `src/server/Bootstrap.server.luau` | Start and retain exactly one additional safe-spawn/objective controller after the existing round controller. |
| `tests/GameLoop/ObjectivePlacement.spec.luau` | Pure deterministic placement and assignment specifications. |
| `tests/GameLoop/SafeSpawnObjectiveAdapter.spec.luau` | Narrow-fake wiring, ownership, isolation, duplicate-signal, removal, and shutdown specifications. |

Workflow-only records may additionally change `docs/tickets/TCK-0003.json`, `docs/implementation/tck-0003-builder-attempts.md`, the TCK-0003 independent review record, and the TCK-0003 Studio checkpoint record at their respective gates. This planning update changes only this plan and the ticket.

`RoundLifecycle.luau`, `PlayerRoundRegistry.luau`, `PlayerRoundAdapter.luau`, their tests, all client files, the frozen scenarios, approved product decisions, `default.project.json`, dependencies, configuration, and project mappings are prohibited from changing. No Workspace Instances are saved manually in Studio or added to Rojo mappings.

### Deterministic Lune specifications

Placement registry matrix:

| ID | Test |
| --- | --- |
| OPL-01 | The canonical catalog has exactly eight unique slots with the approved coordinates; every objective footprint stays within the platform and outside the guarded start. |
| OPL-02 | A preferred free index produces the matching frozen assignment and one stored identity. |
| OPL-03 | An occupied preferred index scans cyclically to the first free slot deterministically. |
| OPL-04 | Duplicate assignment rejects without replacing the existing assignment or consuming a slot. |
| OPL-05 | Invalid, fractional, missing, and out-of-range preferred indices reject without mutation. |
| OPL-06 | Two through eight players receive distinct assignments; no player state or assignment aliases another. |
| OPL-07 | A ninth assignment rejects as `NO_AVAILABLE_SLOT` without changing the first eight. |
| OPL-08 | Removing one player frees only its slot, repeated removal is a no-op, and the next deterministic scan may reuse that free slot. |
| OPL-09 | Destroy clears all assignments, is idempotent, and rejects later assignment without mutation. |

Thin adapter matrix using only narrow fakes:

| ID | Test |
| --- | --- |
| SOA-01 | Startup creates exactly one arena root, platform, neutral SpawnLocation, three guard walls, and objectives container with the approved descriptors. |
| SOA-02 | PlayerAdded and PlayerRemoving connect before existing players are enumerated. |
| SOA-03 | An existing player receives exactly one objective with the assigned position and approved owner/slot metadata. |
| SOA-04 | Enumeration/PlayerAdded races and duplicate PlayerAdded signals create no duplicate assignment or Instance. |
| SOA-05 | A late second player receives a distinct objective without changing the first player's assignment or Instance identity. |
| SOA-06 | Character-related data or reloads are not observed and cannot duplicate or move an assignment. |
| SOA-07 | Removing one player invalidates and destroys only that player's objective and leaves every other player unchanged. |
| SOA-08 | Full capacity creates no ninth objective and preserves all existing objective identities. |
| SOA-09 | `stop()` disconnects both signals, destroys all owned Instances and registry state, and is idempotent; signals after stop have no effect. |
| SOA-10 | The controller exposes only read-only assignment/objective lookup and stop; no remote, client transition, lifecycle event, timer, or delayed task surface exists. |

The existing 40 deterministic TCK-0001/TCK-0002 cases remain unchanged and must continue to pass. Static analysis must prove the strict types and canonical Roblox requires; Lune proves only rules and adapter orchestration through fakes, not actual Roblox geometry, spawning, physics, rendering, replication, materials, or Instance destruction.

### Required Studio checkpoint after implementation and review

Use the exact clean implementation/review commit only after the complete `Checks.ps1` gate passes and independent review has no unresolved blocker. Record place, Rojo/Studio connection, exact player counts, all server/client warnings and errors, and every limitation.

Single-player scenario:

1. Build and synchronize the root project; confirm each new module maps exactly once and no saved Workspace geometry or new remote exists.
2. Start one player. Confirm exactly one arena root, one platform, one neutral SpawnLocation, three guard walls, and one objective exist with the approved sizes, positions, properties, and attributes.
3. Confirm the character spawns on the guarded pad above the platform and can leave through the positive-Z opening using ordinary movement.
4. Confirm the objective is visible, rests wholly on the platform at its assigned slot, and the server-side controller associates it with that Player.
5. Walk into or across the objective and confirm the player's round remains `ACTIVE`, generation `1`, nil result, and nil failure reason; TCK-0003 must not qualify success.
6. Reload the character and confirm it returns to the guarded spawn without duplicating/moving the objective or changing round generation/state.

Two-player scenario:

1. Begin with player one active and assigned. Add a late player two and confirm player two spawns safely and receives one distinct objective/slot while player one's objective identity, assignment, and round state remain unchanged.
2. Confirm both clients receive the server-created arena and both objective Instances with truthful owner/slot metadata. Owner-specific visual filtering is not claimed.
3. Remove player two and wait until server-side `Players` removal actually completes. Confirm only player two's objective is destroyed/freed and player one's objective and `ACTIVE` generation-one round remain unchanged.
4. Confirm no duplicate geometry, assignment, transition, cleanup error, late callback, repository warning/error, or TCK-0003 remote appears. Record explicit server and per-client warning/error counts.

This checkpoint supports only the spawn/placement foundations of FP-01, FP-02, FP-06, FP-08, FP-09, and FP-10. It does not complete any frozen scenario because timers, qualification/outcomes, failure observation, reset/replay, and client feedback remain absent.

### Risks, controls, and rejected alternatives

- **Unsafe spawn timing or geometry:** runtime creation could occur too late or place a character over the void. Control: bootstrap-owned creation, exact dimensions/coordinates, static descriptors, and real Studio spawn/physics observation.
- **Duplicate arena or objective bootstrap:** repeated signals or accidental second startup could duplicate Instances. Control: one retained bootstrap controller, registry duplicate rejection, adapter guards, exact-count tests, and idempotent stop.
- **Cross-player objective leakage:** one player's join/leave could move or destroy another's objective. Control: distinct immutable assignments and Instances keyed by Player, with two-player identity assertions.
- **Capacity/collision errors:** two players could receive the same slot or an objective could overlap the start/platform edge. Control: an engine-free occupied-slot registry and catalog-boundary tests.
- **Client authority leakage:** a client-created zone or reported entry could become authoritative. Control: server construction only, no remotes, no observer, and no lifecycle calls in this slice.
- **Visual ambiguity:** all players temporarily see every objective. Control: owner metadata is truthful; client-specific filtering is deferred rather than smuggled into a server-foundation slice.
- **Cleanup leaks:** objectives or signal connections could survive leave/stop. Control: invalidate association first, destroy only owned Instances, release the slot, disconnect globally, and test idempotence.

Rejected larger alternatives:

- Combining touch/occupancy detection and `SUCCEED` with this slice is rejected because it couples geometry, physics filtering, round-session capture, and terminal authority before the foundation is independently proven.
- One shared movable objective is rejected because repositioning it for one independent round would change other players' targets.
- Separate arenas/places, client-local objective authority, remotes, a geometry framework, saved Studio-built Workspace content, randomized placement, custom respawn orchestration, and early UI are unnecessary for this boundary.

Risk is medium because this slice creates replicated Roblox Instances and owns per-player join/leave cleanup, even though it makes no outcome transition. The builder receives two complete-gate attempts. Any second failed complete gate stops implementation and requires human direction.

### Rollback, exit evidence, and approval gate

Rollback is a normal revert of the future TCK-0003 implementation commit. The slice owns no saved place edits, persistence, economy, published assets, migrations, or irreversible data; removing the additional bootstrap start and the two new modules/tests restores the merged TCK-0002 runtime.

Implementation exit requires the planned Lune matrices, the unchanged existing suite, a complete green `Checks.ps1`, an independent review with no unresolved blockers, and the scoped one-player/two-player human Studio evidence above. Ticket advancement remains sequential: `PLAN_APPROVED → BUILDING → STATIC_PASS → CODE_REVIEW_PASS → STUDIO_PASS → HUMAN_APPROVED → MERGED`. No later state is inferred.

The exact next decision is: the owner must approve this TCK-0003 boundary, file list, medium-risk/two-attempt budget, deferred Slice 4 qualification path, deterministic evidence matrix, and Studio checkpoint before the ticket may become `PLAN_APPROVED` or implementation may begin.

## Slice 4 — Server-owned objective qualification and success

**Ticket:** `TCK-0004` — Server-owned objective qualification and immediate success

**Plan status:** Proposed. The owner must explicitly approve this detailed slice before the ticket may advance from `ACCEPTANCE_TESTS_FROZEN` to `PLAN_APPROVED`, an implementation branch may be created, or a builder attempt may be consumed.

### Exact behavioral boundary

TCK-0004 turns the inert per-player objective foundation into one server-authoritative success path:

- Observe the server-created objective currently associated with each connected Player through the merged `SafeSpawnObjectiveAdapter` controller's read-only `getObjective(player)` seam.
- Treat the first server-observed `Touched` signal from a BasePart descending from that Player's current living Character as confirmed entry into that Player's own objective.
- At qualification time, read the current opaque session handle and immutable round state from the merged `PlayerRoundAdapter` controller. Require a current handle, `ACTIVE` phase, and a nonnegative integer generation.
- Submit exactly one server-owned `{ type = "SUCCEED", generation = currentGeneration }` event for that player/session/generation through `applyServerEvent` immediately after qualification.
- Let the merged lifecycle and registry remain the final authority. An accepted event publishes `RESULT`, generation unchanged, `SUCCESS`, and nil failure reason through the four existing Player attributes.
- Ignore unrelated physical contacts, another player's Character, a dead or missing Humanoid, a stale Character, a stale/replaced objective, a missing player/session/state, a non-`ACTIVE` state, and repeated contacts for a session/generation without mutation or another submission.
- Preserve every other player's objective, session, lifecycle, and attributes. A success for one player cannot qualify or transition another.

This slice implements only objective qualification and immediate success. It does not add a round timer, timeout/death/void failure, result duration, reset, replay, respawn orchestration, objective repositioning, client presentation, publishing, or any complete first-playable claim.

### Server authority, validation, and deduplication

- The server owns objective identity, Character identity, living-state inspection, qualification, session/generation capture, and lifecycle submission. No client request or replicated attribute is read as authority.
- A touch qualifies only when the touched BasePart is a descendant of `player.Character`, that Character is still the Player's current Character, and its current Humanoid exists with `Health > 0`.
- The bound objective must still be identical to `objectiveController.getObjective(player)` when the callback runs. A retained callback from a destroyed, removed, or replaced objective is rejected.
- The adapter reads `getSessionHandle(player)` and `getState(player)` at touch time rather than capturing them when the objective listener is connected. This prevents a listener retained across Character or session changes from intentionally targeting an old round.
- Before submitting, the adapter records the attempted opaque handle plus generation. Further body-part touches or repeated `Touched` signals for that exact pair are ignored whether the trusted lifecycle submission accepts or rejects; a genuinely new handle or later generation is independently eligible for future slices.
- `PlayerRoundAdapter.applyServerEvent` remains responsible for the final session-handle, phase, event-shape, and generation checks. A race that makes the captured context stale is rejected without republishing state.
- No `RemoteEvent`, `RemoteFunction`, client script, client callback, Bindable-based client ingress, or writable success attribute is introduced.

### Thin objective-success adapter and event flow

Add `ObjectiveSuccessAdapter.start(roundController, objectiveController)` with optional narrow test dependencies for a Players-like source and the exact Character/Humanoid inspection operations used by production. Normal production construction defaults to the real `Players` service and Roblox Instance APIs; the seam must not become a service container, physics framework, generalized signal abstraction, or networking layer.

The frozen controller exposes only:

| API | Responsibility |
| --- | --- |
| `stop()` | Disconnect global and per-player signals, invalidate retained callbacks, clear observation state, and remain idempotent. |

Event flow:

1. `Bootstrap.server.luau` starts and retains the merged round controller, then the merged safe-spawn/objective controller, then exactly one objective-success controller receiving both existing controllers.
2. The objective-success adapter connects `PlayerAdded` and `PlayerRemoving` before enumerating current players. It starts after both provider controllers so existing players already have a round session and objective.
3. Per-player setup connects `CharacterAdded` as an idempotent retry point, queries the current objective through `getObjective`, and connects that objective's `Touched` signal at most once. A normal late join is observed after the provider controllers; Character creation retries setup without a delayed task if the objective was not yet available.
4. A touch callback performs the objective, current-Character, living-Humanoid, owner, handle, state, phase, generation, and per-handle/generation duplicate checks before submitting `SUCCEED`.
5. An accepted transition is published only by the merged round controller. The objective-success adapter writes no Player attributes and changes no objective Instance.
6. Character replacement preserves the player's objective listener but makes Parts from the old Character ineligible. The new current living Character may qualify only if the same session/generation has not already attempted success.
7. `PlayerRemoving` invalidates and disconnects only that player's Character/objective observations. Any retained callback checks the invalidated observation and current controller identities before it can submit.
8. `stop()` first prevents new work, disconnects both global signals and every owned per-player connection, invalidates all observation records, and is a repeated no-op after the first call.

TCK-0004 introduces no polling loop, `RunService` step, `GetPartsInPart` occupancy scan, dwell interval, `task.delay`, timer, coroutine, result scheduler, reset callback, or objective movement.

### Exact implementation and workflow files

Builder implementation is limited to these paths:

| File | Planned responsibility |
| --- | --- |
| `src/server/GameLoop/ObjectiveSuccessAdapter.luau` | Server-owned per-player objective touch observation, living/current Character filtering, current round-context capture, exact-once `SUCCEED` submission, isolation, and cleanup. |
| `src/server/Bootstrap.server.luau` | Start and retain exactly one objective-success controller after the two merged provider controllers and pass their server-only seams. |
| `tests/GameLoop/ObjectiveSuccessAdapter.spec.luau` | Narrow-fake qualification, authority, exact-once, stale-context, late-join, isolation, removal, and shutdown specifications. |

Workflow-only records may additionally change `docs/tickets/TCK-0004.json`, the TCK-0004 builder-attempt record, independent review record, and Studio checkpoint record at their respective gates. This planning update changes only this plan and the new ticket.

`RoundLifecycle.luau`, `PlayerRoundRegistry.luau`, `PlayerRoundAdapter.luau`, `ObjectivePlacement.luau`, `SafeSpawnObjectiveAdapter.luau`, all five merged suites for those modules, all client files, frozen scenarios, approved product decisions, `default.project.json`, dependencies, configuration, and project mappings are prohibited from changing. No Workspace Instance or script is saved manually in Studio.

### Deterministic Lune specifications

The new adapter suite uses narrow Players, Character, Humanoid, objective-signal, round-controller, and objective-controller fakes. It does not claim to reproduce Roblox physics.

| ID | Test |
| --- | --- |
| OSA-01 | `PlayerAdded` and `PlayerRemoving` connect before existing-player enumeration; one current player receives exactly one Character retry connection and one objective touch connection. |
| OSA-02 | A valid Part from the owner's current living Character touching the owner's current objective reads the current handle/state and submits exactly `{ type = "SUCCEED", generation = state.generation }`. |
| OSA-03 | The adapter submits through the server-only round controller and never writes lifecycle attributes or changes the objective itself. |
| OSA-04 | World geometry, an unrelated Part, and a Part from another player's Character do not submit or mutate either player. |
| OSA-05 | A missing Humanoid, dead Humanoid, and Part from a stale replaced Character do not qualify; a Part from the new current living Character can qualify when the generation has not been attempted. |
| OSA-06 | A missing or replaced objective, a missing handle/state, and a non-`ACTIVE` state reject without submission. A retained callback from the old objective cannot target the replacement. |
| OSA-07 | Multiple body-part contacts and repeated signals submit at most once for one opaque handle/generation, including when the trusted round controller rejects the attempted event. |
| OSA-08 | A stale handle or generation race rejected by `applyServerEvent` produces no retry, publication, or cross-player mutation for that handle/generation. |
| OSA-09 | A genuinely new session handle or later active generation is independently eligible, while an older retained callback cannot target it with stale context. |
| OSA-10 | Two players bind distinct objectives; each can qualify only through their own current living Character and success submission affects only the addressed player. |
| OSA-11 | A late player is observed once without reconnecting, resubmitting, or changing any existing player's objective or round state; Character-added retry remains idempotent. |
| OSA-12 | Removing one player invalidates and disconnects only that player's observations; repeated removal and retained signals are no-ops and the other player remains observable. |
| OSA-13 | `stop()` disconnects all global, Character, and objective signals, invalidates every observation, is idempotent, and makes later signals inert. |
| OSA-14 | The controller exposes only `stop`; construction creates no remote, client transition surface, polling loop, timer, delayed task, failure, reset, replay, respawn, repositioning, or presentation path. |

The existing 59 deterministic TCK-0001 through TCK-0003 cases remain unchanged and must continue to pass. Static analysis proves strict types and canonical Roblox requires; Lune proves qualification filtering and orchestration through fakes, not real `Touched` physics, Character assembly, Humanoid behavior, replication, or console output.

### Frozen-scenario coverage

| Scenario | TCK-0004 contribution | Still blocked after this slice |
| --- | --- | --- |
| FP-02 | Completes the scoped server-confirmed objective-entry path: the first valid owner entry submits matching-generation success immediately and later contacts cannot replace it. | Result timing/presentation and automatic replay remain later slices. |
| FP-06 | Adds no client result request or transition path; qualification derives only from server-owned objective and Character state. | Later presentation must remain read-only. |
| FP-07 | Per-handle/generation observation deduplication plus the merged lifecycle reject duplicate, stale, future, and invalid-phase success attempts without mutation. | Later failure/reset observers must preserve the same generation discipline. |
| FP-08 | Owns and removes Character/objective listeners per player without changing another player's lifecycle. | Later timer, failure, reset, and feedback listeners require their own cleanup. |
| FP-09 | A late joiner receives one independent objective observer and can succeed without changing an existing player. | The authoritative timer remains absent. |

FP-01 remains incomplete because no timer starts. FP-03 through FP-05 and FP-10 remain incomplete because this slice adds no failure observation, result/reset interval, respawn, objective repositioning, timer restart, or consecutive replay. TCK-0004 does not claim the complete first playable.

### Required Studio checkpoint after implementation and review

Use the exact clean implementation/review commit only after the complete `Checks.ps1` gate passes and independent review has no unresolved blocker. Record the place, Rojo/Studio connection, exact player counts and join order, server/client warnings and errors, observed identities/state, and every limitation.

Single-player scenario:

1. Build and synchronize the root project; confirm `ObjectiveSuccessAdapter` maps exactly once under `ServerScriptService.Server.GameLoop`, all merged modules still map once, no saved Workspace geometry exists, and no new remote or client script appears.
2. Start one player and record the current Character, living Humanoid, owned objective identity/slot/owner/position, session lifecycle attributes, and server/client output before contact.
3. Walk the current living Character into its own objective using ordinary movement. Confirm the server immediately publishes `RESULT`, the same generation, `SUCCESS`, and nil failure reason; record the objective and Character contact positions and confirm the objective identity/slot/owner/position do not change.
4. Continue moving across the objective and reload the Character after success. Confirm repeated body-part/contact signals and the replacement Character cannot create another transition, generation change, objective replacement, or repository warning/error.
5. Confirm no timer, failure, result interval, automatic reset, replay, respawn orchestration, objective repositioning, UI/result presentation, or TCK-0004 remote appears.

Two-player scenario:

1. Begin with Player 1 active and assigned, then add Player 2 late. Record both objective identities, associations, and `ACTIVE` generation-one states; confirm the late join changes no Player 1 value.
2. Move Player 1 through Player 2's objective and confirm neither player changes. Then move Player 1 into Player 1's objective and confirm only Player 1 immediately becomes `RESULT`/`SUCCESS` while Player 2 remains unchanged.
3. Move Player 2 through Player 1's objective and confirm neither state changes from the prior observation. Then move Player 2 into Player 2's objective and confirm only Player 2 becomes `RESULT`/`SUCCESS` with its generation unchanged.
4. Remove Player 2 and wait for server-side `Players` removal. Confirm Player 2's objective and observer are gone, Player 1's objective and successful state remain unchanged, and no late callback, duplicate transition, or cleanup error appears.
5. Confirm both clients replicated only the server-published lifecycle attributes and server-created objectives. Record explicit server and per-client warning/error counts and distinguish direct physics/replication evidence from static/Lune-only stale-context and shutdown evidence.

This checkpoint supports only the TCK-0004 contributions listed above. Dead/missing-Humanoid filtering, retained callback rejection, stale handle/generation races, and idempotent full shutdown may remain deterministic adapter evidence unless a truthful read-only Studio observation is available without adding hooks or persistent objects.

### Risks, controls, and rejected alternatives

- **Client authority leakage:** a client contact report or result request could decide success. Control: server `Touched` observation only, current server-owned controller lookups, and no remotes/client changes.
- **Noisy Roblox touch signals:** multiple Character parts can fire nearly together. Control: record one attempted opaque handle/generation before submission and reject every repeat for that pair.
- **Cross-player qualification:** another Character can physically enter a visible objective. Control: require the touched Part to descend from the objective owner's current Character; test both cross-objective directions.
- **Dead or stale Character:** a corpse or replaced Character can retain touching Parts. Control: require the current Character identity and a current Humanoid with positive Health on every callback.
- **Stale objective/session callback:** leave, rejoin, replacement, or shutdown can retain a callable closure. Control: invalidate per-player observation records, compare current objective identity, read current handle/state at touch time, delegate final session/generation validation, and test retained signals.
- **Late-join binding order:** the observer starts after both provider controllers and uses idempotent Player/Character setup; a Character-added retry handles an objective unavailable during the initial join callback without a delayed task.
- **Scope creep into loop completion:** immediate success can invite timers, feedback, or replay. Control: keep result scheduling, failure, reset/replay, respawn, repositioning, and presentation explicitly deferred to Slices 5 and 6.

Rejected larger alternatives:

- A client `RemoteEvent` reporting objective entry is rejected because it creates an unnecessary forged-result surface.
- `RunService` polling, continuous `GetPartsInPart`, dwell qualification, region frameworks, tags/CollectionService architecture, and a generalized physics observer are rejected because one owned objective `Touched` connection per player is sufficient for this graybox boundary.
- Modifying `RoundLifecycle`, `PlayerRoundRegistry`, either merged provider adapter, or their tests is rejected because their existing server-only seams already provide objective identity, current session/state, and validated event submission.
- Combining timeout/death/void failure, result duration, reset/replay, respawn, objective movement, or client feedback is rejected because it would cross the smallest independently verifiable authority boundary.

Risk is medium because this slice translates real Roblox physics/Character observations into a server-authoritative terminal lifecycle mutation and owns per-player callbacks. The builder receives two complete-gate attempts. Any second failed complete gate stops implementation and requires human direction.

### Rollback, exit evidence, and approval gate

Rollback is a normal revert of the future TCK-0004 implementation commit. Removing the additional bootstrap start and the new adapter/spec restores the merged TCK-0003 runtime. The slice owns no saved place edits, persistence, economy, published assets, migrations, dependencies, configuration, or irreversible data.

Implementation exit requires all 14 planned adapter cases, the unchanged 59-case suite, one authorized complete green `Checks.ps1` attempt, an independent review with no unresolved blocker, and the scoped single-player/two-player human Studio evidence above. Ticket advancement remains sequential: `PLAN_APPROVED → BUILDING → STATIC_PASS → CODE_REVIEW_PASS → STUDIO_PASS → HUMAN_APPROVED → MERGED`. `OBSERVING` and `CLOSED` remain undefined and are not inferred.

The exact next decision is: the owner must approve this TCK-0004 behavior, three-file implementation boundary, medium-risk/two-attempt budget, deterministic evidence matrix, Studio checkpoint, and explicit deferrals before the ticket may become `PLAN_APPROVED` or implementation may begin.

## Slice 5 — Failure and reliable replay adapter

**Ticket:** `TCK-0005` — Server-owned failure and reliable replay adapter

**Plan status:** Proposed. The owner must explicitly approve this detailed slice before the ticket may advance from `ACCEPTANCE_TESTS_FROZEN` to `PLAN_APPROVED`, the implementation branch may be created, Studio may be started, or a builder attempt may be consumed.

### Exact behavioral boundary

TCK-0005 closes the server-owned round loop around the merged lifecycle, objective, and success adapters:

- Use one server `Heartbeat` observation and `Workspace:GetServerTimeNow()` to maintain independent per-player deadlines. The proposed graybox constants are a `20`-second active round, `2`-second result interval, `1`-second minimum reset interval, and a void boundary at world `Y = -20`.
- Disable automatic Roblox character loading for the server lifetime owned by the adapter. Load an initial Character when needed and use `Player:LoadCharacterAsync()` exactly once during each accepted reset so default respawn timing cannot race the authoritative result/reset sequence.
- For a current `ACTIVE` session/generation with no accepted result, submit exactly one server-owned `FAIL` observation for the first observed timeout, current-Humanoid death, or current-Character pivot below the void boundary. Use `TIMEOUT`, `DEATH`, or `VOID` respectively.
- Keep the merged lifecycle and registry as final authority. Success from TCK-0004 and all three failure sources compete only through `applyServerEvent`; the first accepted terminal event remains immutable and every later, duplicate, stale, wrong-session, or invalid-phase event is rejected without publication.
- Observe an accepted `RESULT` from either success or failure on the next server heartbeat, retain it for the complete result interval, then submit one matching-generation `BEGIN_RESET`.
- On accepted reset, disconnect the prior Character/Humanoid observation, reposition that player's existing objective Instance to a valid canonical slot different from that player's immediately previous slot, and request one server-owned Character reload. Preserve the objective Instance identity and owner association so the merged success observer remains valid.
- After both the minimum reset interval has elapsed and the replacement current Character exists, submit matching-generation `FINISH_RESET` followed by exactly one `START`. The new `ACTIVE` state has a strictly greater generation, no result or failure reason, and one fresh active deadline.
- Publish one server-written `GrayboxPhaseEndsAt` Player attribute using the same server-time basis: active timeout while `ACTIVE`, result end while `RESULT`, reset end while `RESETTING`, and `nil` after removal or shutdown. This is read-only timing substrate for Slice 6, not client feedback or authority.
- Preserve per-player isolation. One player's terminal event, deadline, Character replacement, objective movement, replay, removal, or delayed callback cannot change another player's lifecycle, objective, Character, deadline, or attributes.
- Remove every owned per-player Character/Humanoid listener and replay record on disconnect, invalidate retained asynchronous callbacks before clearing the timing attribute, and make repeated removal and full shutdown deterministic no-ops.

This is the smallest coherent Slice 5 boundary. Failure without reset would leave a completed round stuck; reset without controlled Character loading would race Roblox's default respawn; replay without objective reassignment would violate FP-05 and FP-10; and result scheduling must observe the already-merged success path as well as new failure paths. Client presentation remains a separate Slice 6 concern.

### Timing, terminal-event, and reset rules

- The adapter starts after the merged round, safe-spawn/objective, and objective-success controllers. It connects `PlayerAdded`, `PlayerRemoving`, and one `RunService.Heartbeat` before enumerating current players. Provider lookups are retried on later heartbeats so callback ordering cannot create a second lifecycle or leave a late joiner unobserved.
- Each player record is keyed by Player and tracks the current opaque session handle, generation, phase/deadline, current Character, current Humanoid/death connection, terminal-attempt token, reset token, and Character-load completion token.
- A record arms one active deadline only for a current handle and `ACTIVE` generation. A repeated join signal, Character signal, or heartbeat for the same handle/generation reuses the deadline rather than extending it.
- A current Humanoid's `Died` signal is the `DEATH` observation. Character replacement disconnects the old Humanoid before binding the replacement; a retained old signal is inert.
- A heartbeat checks the current Character pivot against `Y = -20` before checking the active deadline. A below-boundary Character therefore submits `VOID`; otherwise `now >= activeDeadline` submits `TIMEOUT`. A Humanoid signal already accepted as `DEATH` wins through the lifecycle. No later source may replace the accepted reason.
- Before any failure submission, the adapter records the attempted handle/generation. It does not retry a rejected terminal submission for that pair. A genuinely later generation is independently eligible.
- The first heartbeat that sees `RESULT` records `resultEndsAt = now + 2` once and publishes that deadline. At `now >= resultEndsAt`, it records the reset attempt before submitting `BEGIN_RESET`.
- An accepted `BEGIN_RESET` clears terminal lifecycle data through the existing model, publishes `resetEndsAt = now + 1`, moves the existing objective once, and starts one guarded asynchronous `LoadCharacterAsync` request.
- A failed objective move or Character load does not falsely start the next round. The player remains in `RESETTING`, the failure is reported to server output, and owner intervention is required rather than replaying with stale state. The adapter does not add an unbounded retry loop.
- At or after `resetEndsAt`, the adapter requires the same current session/reset token and a replacement current Character before applying `FINISH_RESET`. Only an accepted finish is followed by `START`; only an accepted start arms the new deadline. A rejection stops that sequence without a speculative retry or generation increment.
- On stop, the adapter disconnects global and per-player connections, invalidates all tokens, clears only its timing attributes, and restores the prior `Players.CharacterAutoLoads` value. It does not stop or destroy the provider controllers, whose ownership remains in Bootstrap.

### Deterministic objective reassignment

Extend the engine-free `ObjectivePlacement` registry with a replay-only `reassign(playerKey, preferredIndex)` operation:

1. Validate a live registry, an existing player, and an integer preferred index from 1 through 8.
2. Exclude the player's immediately previous slot.
3. Scan cyclically from the requested preference and choose the first unoccupied different slot when one exists.
4. If all seven different slots are occupied, choose the first different slot in that same deterministic order even though another player's separately owned objective uses that position.
5. Replace only the addressed player's assignment with a new frozen value and preserve every other assignment identity.

Initial assignment remains unchanged: the first eight players receive distinct slots and a ninth player receives no assignment. The full-capacity replay fallback is necessary because the approved arena has exactly eight canonical slots for up to eight independently replaying players; keeping all slots globally unique while moving only one player's objective to a different slot is impossible at full occupancy. The fallback may overlap separately owned objective Parts, but it never moves or reassigns another player's target. Slice 6 remains responsible for owner-specific objective presentation.

Extend `SafeSpawnObjectiveAdapter` with one server-only `repositionObjective(player)` method. It asks the registry to reassign starting at the slot after the player's current slot, moves the same objective Instance to the returned coordinates at `Y = 0.75`, updates its name and `GrayboxObjectiveSlot`, preserves `GrayboxObjectiveOwnerUserId`, and returns the new frozen assignment. Unknown, removed, unassigned, stopped, or rejected reposition requests produce no Instance or registry mutation.

### Exact implementation and workflow files

Builder implementation is limited to these paths:

| File | Planned responsibility |
| --- | --- |
| `src/shared/GameLoop/ObjectivePlacement.luau` | Add deterministic previous-slot-excluding reassignment, full-capacity fallback, occupancy accounting, isolation, and cleanup. |
| `src/server/GameLoop/SafeSpawnObjectiveAdapter.luau` | Expose one server-only in-place objective reposition operation while preserving Instance identity and ownership. |
| `src/server/GameLoop/FailureReplayAdapter.luau` | Own authoritative timing, timeout/death/void observations, result/reset scheduling, controlled Character reload, automatic replay, timing publication, token validation, and cleanup. |
| `src/server/Bootstrap.server.luau` | Start and retain exactly one failure/replay controller after the three merged provider controllers. |
| `tests/GameLoop/ObjectivePlacement.spec.luau` | Extend the pure placement suite for reassignment, previous-slot exclusion, capacity fallback, and occupancy cleanup. |
| `tests/GameLoop/SafeSpawnObjectiveAdapter.spec.luau` | Extend the narrow-fake adapter suite for in-place repositioning, metadata, rejection, and isolation. |
| `tests/GameLoop/FailureReplayAdapter.spec.luau` | Add deterministic clock/heartbeat, Character/Humanoid, lifecycle, objective, async-load, isolation, stale-callback, and shutdown specifications. |

Workflow-only records may additionally change `docs/tickets/TCK-0005.json`, the future TCK-0005 builder-attempt record, independent review record, and Studio checkpoint record at their respective gates. This planning update changes only this plan and the new ticket.

`RoundLifecycle.luau`, `PlayerRoundRegistry.luau`, `PlayerRoundAdapter.luau`, `ObjectiveSuccessAdapter.luau`, their merged specifications, all client files, prototype controllers, frozen scenarios, approved product decisions, `default.project.json`, dependencies, configuration, and project mappings are prohibited from changing. No Workspace Instance or script is saved manually in Studio.

### Deterministic Lune test matrix

Objective placement extension:

| ID | Test |
| --- | --- |
| OPL-R01 | Reassignment rejects an invalid preference, unknown player, and destroyed registry without changing any assignment or occupancy. |
| OPL-R02 | A single player receives a new frozen assignment at a valid different slot; the prior frozen value remains unchanged. |
| OPL-R03 | Reassignment scans cyclically to the first free different slot and preserves every other player's assignment identity. |
| OPL-R04 | With all eight slots occupied, reassignment deterministically selects a different occupied slot without moving another player; the old slot becomes available. |
| OPL-R05 | Consecutive reassignments never reuse that player's immediately previous slot, and removal releases only the addressed player's current occupancy. |
| OPL-R06 | Initial assignment, ninth-player rejection, repeated removal, and destroy behavior remain unchanged after reassignment support. |

Safe-spawn/objective adapter extension:

| ID | Test |
| --- | --- |
| SOA-R01 | `repositionObjective` moves the same objective identity to the new assignment coordinates and updates only its name and slot metadata. |
| SOA-R02 | Repositioning preserves owner metadata, objective size/properties, parent, and every other player's assignment and Instance identity. |
| SOA-R03 | Repeated repositions exclude the immediately previous slot and use the registry's deterministic full-capacity fallback. |
| SOA-R04 | Unknown, removed, unassigned, stopped, and registry-rejected requests return no assignment and perform no Instance write. |
| SOA-R05 | The controller exposes only `getAssignment`, `getObjective`, `repositionObjective`, and `stop`; it adds no lifecycle, remote, timer, Character, or presentation authority. |

Failure/replay adapter:

| ID | Test |
| --- | --- |
| FRA-01 | Startup disables `CharacterAutoLoads`, connects player signals and one heartbeat before enumeration, initializes an existing player once, and does not alter provider state. |
| FRA-02 | A current active handle/generation receives exactly one 20-second deadline and `GrayboxPhaseEndsAt`; repeated signals/heartbeats do not extend it. |
| FRA-03 | A missing initial Character causes one guarded server Character load; current Character binding is idempotent and stale load completions are rejected. |
| FRA-04 | At the exact active deadline, one matching-generation `FAIL/TIMEOUT` is submitted; early and repeated heartbeats do not submit another event. |
| FRA-05 | The current Humanoid's first `Died` signal submits one matching-generation `FAIL/DEATH`; duplicate, old-Humanoid, and replaced-Character signals are inert. |
| FRA-06 | A current Character below `Y = -20` submits one matching-generation `FAIL/VOID`; missing, unrelated, stale, and above-boundary Characters do not. |
| FRA-07 | Void is checked before timeout on the same heartbeat, while an already accepted death or success remains immutable; all later failure sources are no-ops. |
| FRA-08 | Missing/wrong handles, malformed state, non-`ACTIVE` phase, stale/future generation races, and rejected terminal submissions do not publish, retry, or affect another player. |
| FRA-09 | The first observed accepted `RESULT`, whether success or any failure reason, receives one two-second result deadline without changing its immutable result. |
| FRA-10 | The result deadline records and submits exactly one matching-generation `BEGIN_RESET`; duplicate heartbeats and a retained old deadline cannot begin reset again. |
| FRA-11 | Accepted reset disconnects prior Character/Humanoid observation, repositions the same objective once to a different slot, starts one Character load, and publishes one-second reset timing. |
| FRA-12 | Reset cannot finish before both its deadline and a replacement current Character; a failed objective move or load never falsely starts replay. |
| FRA-13 | A ready reset applies `FINISH_RESET` then `START` exactly once, producing a clean greater generation and one new 20-second active deadline. |
| FRA-14 | Consecutive success-then-failure and failure-then-success replays carry no result, failure reason, terminal token, reset token, Character callback, or prior deadline forward. |
| FRA-15 | Character replacement during active/reset disconnects old death observation and cannot duplicate terminal submission, Character load, reset completion, or round start. |
| FRA-16 | Two players maintain independent clocks, terminal outcomes, objectives, Character loads, reset progress, generations, and timing attributes. |
| FRA-17 | A late joiner receives one independent initial Character load/deadline without changing an existing player's state, objective, or timer. |
| FRA-18 | Removing a player in `ACTIVE`, `RESULT`, or `RESETTING` invalidates records before disconnect/attribute cleanup; retained signals, heartbeat work, and load completion are inert. |
| FRA-19 | `stop()` disconnects all owned signals, clears timing attributes, restores the prior autoload setting, is idempotent, and makes all retained callbacks inert. |
| FRA-20 | The controller exposes only `stop`; construction creates no remote, client transition path, UI, polling coroutine, persistence, economy, publishing, or multi-place surface. |

The existing 73 deterministic cases remain present. Static analysis must prove strict types and canonical Roblox requires. Lune proves deterministic orchestration through narrow fakes; it does not claim real scheduler cadence, physics, `Humanoid.Died`, Character loading, spawn placement, replication, or console behavior.

### Frozen-scenario coverage

| Scenario | TCK-0005 contribution | Still blocked after this slice |
| --- | --- | --- |
| FP-01 | Adds one authoritative active timer and controlled initial Character loading on the merged guarded spawn/objective foundation. | Primitive countdown presentation remains Slice 6. |
| FP-02 | Detects the merged success result promptly, preserves it for the result interval, and replays without allowing later failure to replace it. | Primitive result presentation remains Slice 6. |
| FP-03 | Completes server-owned timeout failure and first-result immutability. | Primitive countdown/result presentation remains Slice 6. |
| FP-04 | Completes current-Character death and configured void-boundary failure with duplicate/stale rejection. | Primitive result presentation remains Slice 6. |
| FP-05 | Completes result/reset timing, prior-state clearing, guarded respawn, different valid objective placement, fresh timer, and exact-once greater-generation replay. | Primitive result/reset countdown presentation remains Slice 6. |
| FP-06 | Adds no client outcome, timer, reset, generation, Character-load, or objective-movement request path. | Later presentation must remain read-only. |
| FP-07 | Every new observation and deferred action is session/generation/token scoped and delegates final transition validation to the merged lifecycle. | No server behavior remains blocked. |
| FP-08 | Cleans failure, timer, Character, and replay ownership per player without changing another player. | Slice 6 must clean its own client presentation listeners. |
| FP-09 | Adds an independent initial timer and controlled Character load for a late joiner without changing existing rounds. | Primitive feedback and owner-specific objective presentation remain Slice 6. |
| FP-10 | Completes clean consecutive success/failure replay with new generation, no carried result or stale timer, and no immediately repeated objective slot. | Primitive consecutive-round feedback remains Slice 6. |

TCK-0005 completes the server/runtime portions of FP-03, FP-04, FP-05, FP-08, and FP-10, but it does not claim the complete player-facing first playable before Slice 6 feedback and owner judgment.

### Required Studio checkpoint after implementation and review

Use one exact clean implementation/review commit only after the complete `Checks.ps1` gate passes and independent review has no unresolved blocker. Record the place, Rojo/Studio connection, server/client player counts and join order, configured constants, relevant Player attributes, Character/objective identities and positions, every server/client warning or error, and all remaining limitations.

Single-player failure and replay evidence:

1. Build and synchronize the root project. Confirm `FailureReplayAdapter` maps exactly once, all merged modules still map once, one heartbeat source is active, `CharacterAutoLoads` is server-controlled, no saved Workspace content changed, and no remote or new client script exists.
2. For FP-03, start an active round, record generation/objective/deadline, avoid the objective and void, and observe the exact timeout boundary. Confirm one immutable `RESULT`/`FAILURE`/`TIMEOUT`, unchanged generation, no duplicate terminal transition, and no late success/death replacement.
3. Observe the complete result and reset sequence. Confirm the result persists for two seconds; `RESETTING` clears terminal data; the same owned objective moves to a valid different slot; exactly one replacement Character appears at the guarded start; and exactly one clean greater-generation `ACTIVE` round begins with a fresh deadline.
4. For FP-04, complete one active round by Character death and another by falling below `Y = -20`. For each, confirm the correct immutable `DEATH` or `VOID` reason, duplicate/late signals do not transition again, and automatic replay completes as above.
5. For FP-10, perform a success round followed by a failure round, then a failure round followed by a success round. After every reset, record generation, result/failure fields, deadline, Character identity/spawn, objective identity/slot/position, and confirm no carried result, duplicate bootstrap, stale timer, or immediately reused slot.
6. During success and failure result intervals, continue contact/movement and attempt a normal character reset where available. Confirm first-result immutability and that only the adapter's accepted reset sequence creates the next round.

Two-player isolation and disconnect evidence:

1. Start Player 1, add Player 2 late, and record independent generations, deadlines, Characters, objectives, and attributes. Let one player timeout while the other remains active; confirm only the addressed player enters result/reset/replay.
2. Cause Player 1 death while Player 2 reaches success. Confirm each retains its own first result/reason and both reset independently without moving the other player's objective or Character.
3. For FP-08, remove a player once during `ACTIVE` and in a separate run during `RESULT` or `RESETTING`. Confirm that player's objective/provider cleanup and TCK-0005 timing/listener/load cleanup complete without a late transition, replay, warning, or stuck record; the remaining player's lifecycle and timer do not change.
4. Exercise the eight-player capacity edge or a deterministic server-side Studio inspection when practical. Confirm a replay always changes the addressed player's immediately previous slot; if every other slot is occupied, only that player's objective uses the documented shared-position fallback and no other objective moves.
5. Stop play mode and record explicit server and per-client warning/error counts. Distinguish direct Studio evidence from Lune-only stale-token, rejected-race, load-failure, shutdown, and full-capacity assertions.

The checkpoint must record separate results for FP-03, FP-04, FP-05, FP-08, and FP-10. Passing deterministic tests is not a substitute for observing real timer cadence, death, void height, `LoadCharacterAsync`, guarded spawn, objective movement, replication, multiplayer isolation, and console output.

### Risks, controls, and rejected alternatives

- **Terminal races:** success, death, void, and timeout can occur close together. Control: record one handle/generation attempt before submission and let the lifecycle accept only the first result.
- **Stale deferred work:** heartbeat, Humanoid, Character, or async load callbacks can outlive a generation or player. Control: validate Player record identity, session handle, generation, phase, and reset/load token at every callback boundary.
- **Default respawn races:** Roblox automatic respawn could replace a Character during the result interval. Control: own and restore `CharacterAutoLoads`, and request Character loading only for initial spawn when absent or accepted reset.
- **Replay partial failure:** starting a round after objective movement or Character load failed would carry stale world state. Control: remain `RESETTING`, report the failure, and never submit finish/start without all required reset conditions.
- **Objective-listener breakage:** replacing the objective would strand TCK-0004's retained touch connection. Control: move the same Instance and update assignment/metadata in place.
- **Full-capacity placement:** eight occupied slots leave no unique different destination. Control: deterministic different-slot overlap for only the replaying player's separately owned objective; no other assignment or Instance moves.
- **Timer drift or duplication:** per-player delayed tasks can accumulate. Control: one server heartbeat, server-time deadlines, one record per player, and tokenized exact-once phase actions.
- **Partial attribute replication:** lifecycle and timing attributes may be observed between writes. This affects only later presentation; Slice 6 must tolerate transient refreshes and never treat attributes as authority.
- **Scope pressure into presentation:** timing attributes can invite UI work. Control: no client file changes, labels, countdown rendering, owner filtering, input changes, or playability claim in this slice.

Rejected larger or weaker alternatives:

- Client-reported timeout, death, void, reset completion, Character readiness, or objective movement is rejected because outcomes and replay remain server-authoritative.
- Independent `task.delay` chains per phase are rejected because canceled/replaced callbacks are harder to audit than one heartbeat and explicit tokens.
- Roblox default respawn timing is rejected because it can race the immutable result interval and cannot prove exact-once reset/replay.
- Destroying and recreating an objective is rejected because it would require widening TCK-0004 to rebind touch observation.
- Moving another player's objective to preserve global slot uniqueness is rejected because it violates independent lifecycle ownership.
- Adding slots, random placement, a scheduler framework, service container, generalized signal layer, retry service, remote, or state-machine replacement is rejected as unnecessary for the frozen boundary.

Risk is medium because this slice owns authoritative terminal observations, time, Character reload, objective movement, and deferred lifecycle transitions. The builder receives two complete-gate attempts. Planning validation and CI do not consume an attempt. Any second failed builder complete gate stops implementation and requires human direction; scope must not expand to compensate.

### Explicit deferrals

- All Slice 6 client countdown, success/failure, result interval, reset countdown, objective-owner filtering/labels, and final default-movement presentation.
- Final UI, art, animation, audio, obstacles, tuning beyond the four approved prototype constants, analytics, and playtest instrumentation.
- Any client-to-server gameplay remote or client authority over outcomes, generation, timing, Character loading, reset, or objective placement.
- Changes to the pure lifecycle/registry, merged success qualification, frozen acceptance tests, approved product decisions, dependencies, configuration, project mapping, or architecture.
- Persistence, progression, economy, monetization, publishing, production release, migrations, multiple places, frameworks, unattended Studio automation, evidence manifests, and Phase 2 work.
- Slice 6, the first-playable stopping gate, `OBSERVING`, and `CLOSED`; none begins or is inferred from TCK-0005 planning or implementation.

### Rollback, exit evidence, and approval gate

Rollback is a normal revert of the future TCK-0005 implementation commit. Removing its bootstrap start and new adapter/spec, then reverting the narrow placement and safe-spawn extensions/specs, restores the merged TCK-0004 runtime. Adapter shutdown restores the prior Character-autoload setting and clears runtime-only timing attributes. The slice owns no saved place edits, persistence, economy, published assets, migrations, dependencies, configuration, or irreversible data.

Implementation exit requires all 31 planned new/extended cases, the unchanged 73 existing cases, one authorized complete green `Checks.ps1` builder attempt, an independent review with no unresolved blocker, and the scoped human Studio evidence above for FP-03, FP-04, FP-05, FP-08, and FP-10. Ticket advancement remains sequential: `PLAN_APPROVED → BUILDING → STATIC_PASS → CODE_REVIEW_PASS → STUDIO_PASS → HUMAN_APPROVED → MERGED`. `OBSERVING` and `CLOSED` remain undefined and are not inferred.

The exact next decision is: the owner must approve this TCK-0005 behavior; `20`/`2`/`1`-second timing and `Y = -20` void constants; seven-file implementation boundary; deterministic full-capacity slot fallback; medium-risk/two-attempt budget; 31-case matrix; Studio checkpoint; rollback; and explicit deferrals before the ticket may become `PLAN_APPROVED`, implementation may begin, or a builder attempt may be consumed.

## Slice 6 — Primitive client feedback

**Ticket:** `TCK-0006` — Primitive client round feedback

**Plan status:** Proposed. The owner must explicitly approve this detailed slice before the
ticket may advance from `ACCEPTANCE_TESTS_FROZEN` to `PLAN_APPROVED`, an implementation
branch may be created, Studio may be started, or a builder attempt may be consumed.

### Exact behavioral boundary

TCK-0006 presents the already-merged server-owned loop without adding another gameplay
system:

- Read only the local Player's replicated `GrayboxRoundPhase`,
  `GrayboxRoundGeneration`, `GrayboxRoundResult`, `GrayboxRoundFailureReason`, and
  `GrayboxPhaseEndsAt` attributes. Read `Workspace:GetServerTimeNow()` only to render
  the remaining time against the server-published deadline.
- Create one primitive, text-only `ScreenGui` under the local `PlayerGui`. It persists
  across Character replacement and shows the active countdown, immutable result and
  result interval, reset countdown, and next clean active round.
- During `ACTIVE`, show the round generation, an instruction to reach the visible
  glowing objective, and `ceil(GrayboxPhaseEndsAt - serverNow)` clamped to `0..20`.
- During `RESULT`, show unambiguous `SUCCESS` or `FAILURE` text. Failure additionally
  maps `TIMEOUT`, `DEATH`, and `VOID` to plain-language reasons. Continue showing the
  result while rendering the next-round interval clamped to `0..2`.
- During `RESETTING`, replace terminal feedback with `RESETTING` and a next-round
  countdown clamped to `0..1`. A following `ACTIVE` generation replaces all prior
  result/reset text rather than layering another temporary message.
- Treat `WAITING`, missing phase/generation/result data, invalid types, unknown enum
  values, and contradictory multi-attribute snapshots as `PREPARING ROUND...`. A valid
  replicated `FAILURE` whose reason has not arrived yet may show generic `FAILURE`;
  otherwise never invent a result, deadline, generation, or objective association from
  a partial snapshot.
- Discover the replicated `Workspace.GrayboxArena.Objectives` hierarchy even when it
  arrives after client bootstrap. Hide unresolved and non-owned objective Parts on
  that client with `LocalTransparencyModifier`; show an objective only when exactly one
  current Part has a valid `GrayboxObjectiveOwnerUserId` equal to
  `LocalPlayer.UserId`. While zero or multiple owned candidates are present, hide all
  candidates and show `OBJECTIVE SYNCING...` rather than presenting an ambiguous
  target.
- Re-evaluate ownership when objectives or their owner attributes replicate, are
  removed, or are replaced. In-place objective movement from TCK-0005 needs no new
  binding and remains visible only to its owner.
- Leave `InputController`, ordinary Roblox keyboard/gamepad/touch movement, the default
  PlayerModule, camera behavior, Humanoid movement, and jump behavior unchanged. This
  slice introduces no `UserInputService`, `ContextActionService`, movement controller,
  custom character controller, or input remote.

This is the smallest coherent presentation boundary. The merged server already owns
phase, generation, result, timing, Character loading, objective identity and placement,
and replay. The client needs only one pure mapper plus one thin Roblox presentation
controller. It does not need a remote, server edit, new movement layer, phase scheduler,
or state machine.

### Replicated presentation contract

The engine-free presentation mapper accepts one freshly read snapshot plus the current
server-time estimate and returns a frozen view model. It has no clock, Roblox object,
listener, callback, or mutation of its own.

| Replicated snapshot | Primitive presentation | Countdown rule |
| --- | --- | --- |
| Coherent `ACTIVE`, generation `g`, exactly one owned objective | `ROUND g` / `REACH YOUR GLOWING ZONE` | Ceiling of the deadline delta, clamped to `0..20` |
| Coherent `ACTIVE` without exactly one owned objective | `ROUND g` / `OBJECTIVE SYNCING...` | Same active countdown when the deadline is valid |
| `RESULT` with `SUCCESS` | `SUCCESS` / `NEXT ROUND IN n` | Deadline delta clamped to `0..2` |
| `RESULT` with `FAILURE/TIMEOUT` | `FAILURE — TIMEOUT` / `NEXT ROUND IN n` | Deadline delta clamped to `0..2` |
| `RESULT` with `FAILURE/DEATH` | `FAILURE — DEATH` / `NEXT ROUND IN n` | Deadline delta clamped to `0..2` |
| `RESULT` with `FAILURE/VOID` | `FAILURE — FELL` / `NEXT ROUND IN n` | Deadline delta clamped to `0..2` |
| `RESULT` with replicated `FAILURE` but a temporarily missing reason | Generic `FAILURE` / `NEXT ROUND IN n` | Deadline delta clamped to `0..2` |
| Coherent `RESETTING` | `RESETTING` / `ROUND STARTS IN n` | Deadline delta clamped to `0..1` |
| Missing, malformed, unknown, or cross-phase values | `PREPARING ROUND...` | No fabricated countdown |

The mapper accepts only nonnegative integer generations, with a positive generation
required for `ACTIVE`, `RESULT`, or `RESETTING`; finite numeric deadlines and current
times; approved phase/result/reason strings; and combinations permitted by the frozen
lifecycle. An absent, expired, or implausible deadline never changes phase or causes an
outcome; it yields either zero or no countdown according to the validated mapping.
Phase-specific clamps prevent a stale active deadline from rendering a long result/reset
interval while the later timing attribute is still replicating.

Every relevant attribute-change signal triggers a deferred full reread, and the render
step refreshes only time-dependent text from another full snapshot. Multiple signals
from one server publication may therefore cause harmless repeated renders, but cannot
append feedback, start a local timer chain, or mutate authoritative state. The client
never preserves a terminal view across a server-published phase/generation change.

### Client authority, bootstrap, and cleanup

- `DebugHudController.start()` gains one optional narrow dependency seam and returns a
  frozen controller exposing only `stop()`. Production defaults to `Players.LocalPlayer`,
  `Workspace`, `RunService`, Roblox Instances, and the pure mapper.
- A module-local active-controller guard makes repeated `start()` calls return the same
  controller without creating another `ScreenGui`, frame listener, attribute listener,
  objective listener, or render loop. After `stop()`, one later `start()` may create one
  fresh controller.
- The existing `Bootstrap.client.luau` remains the single mapped bootstrap and continues
  to call the debug controller once. The existing no-op `InputController` remains
  unchanged; it does not become a movement system.
- The controller writes no Player attribute, never calls a remote, never reports a
  result, and never requests a lifecycle transition. A displayed countdown reaching
  zero only renders zero/preparing text until the server publishes the next phase.
- The controller owns every LocalPlayer attribute, render-step, Workspace/arena/folder,
  objective child, and objective-owner-attribute connection it creates. Unbinding an
  objective disconnects its listener and restores the pre-controller
  `LocalTransparencyModifier` when the Part still exists.
- The controller intentionally owns no Character listener, Character reference,
  Humanoid reference, input binding, or Character-local GUI. `ScreenGui.ResetOnSpawn`
  is false, so Character replacement cannot duplicate presentation and there is no
  stale Character-owned feedback to clean up.
- `stop()` first marks the controller inactive, then disconnects all owned listeners,
  restores all surviving objective Parts' prior local transparency, destroys the owned
  primitive GUI, clears cached view/objective state, releases the singleton guard, and
  is idempotent. Retained fake or engine callbacks after stop are inert.

### Exact implementation and workflow files

Builder implementation is limited to these paths:

| File | Planned responsibility |
| --- | --- |
| `src/client/Prototype/PrimitiveFeedbackModel.luau` | Engine-free snapshot validation, phase/result/reason text mapping, phase-specific countdown calculation, objective-ready mapping, and frozen view models. |
| `src/client/Prototype/DebugHudController.luau` | One primitive ScreenGui, replicated-attribute observation, server-time rendering, owner-only objective visibility, late hierarchy binding, duplicate-start guard, and cleanup. |
| `tests/Prototype/PrimitiveFeedbackModel.spec.luau` | Deterministic mapping, countdown, partial-snapshot, transition, and owner-association specifications. |
| `tests/PrototypeControllers.spec.luau` | Extend the narrow-fake client-controller suite for bootstrap idempotence, listener/objective cleanup, isolation, and no-authority behavior. |

Workflow records may additionally change `docs/tickets/TCK-0006.json`, the future
TCK-0006 builder-attempt record, independent review record, and Studio checkpoint
record at their respective gates. This planning update changes only this plan and the
new ticket.

`Bootstrap.client.luau`, `InputController.luau`, all server/shared gameplay modules,
all merged gameplay specifications, frozen scenarios, approved product decisions,
`default.project.json`, dependencies, configuration, and project mappings are
prohibited from changing. No Workspace or GUI Instance is saved manually in Studio.

### Deterministic Lune test matrix

Pure presentation mapping:

| ID | Test |
| --- | --- |
| PFM-01 | `WAITING`, missing phase, unknown phase, malformed generation, and cross-phase result data produce only the preparing view and no invented countdown. |
| PFM-02 | A coherent active snapshot maps the exact round/instruction text and ceilings a finite deadline delta deterministically. |
| PFM-03 | Active time is clamped to `0..20`; an expired deadline never triggers a local result or transition. |
| PFM-04 | Active presentation reports objective syncing unless exactly one valid owner association is ready. |
| PFM-05 | Success maps to unambiguous success text, no failure reason, and a `0..2` next-round countdown. |
| PFM-06 | Each approved failure reason maps to distinct plain-language failure text without changing the immutable replicated result. |
| PFM-07 | A replicated failure with a transiently absent reason remains generic failure; malformed or contradictory result combinations fall back safely. |
| PFM-08 | Resetting clears terminal text and maps only the `0..1` reset/next-round countdown. |
| PFM-09 | Missing, nonnumeric, NaN, infinite, expired, and implausibly distant deadlines cannot render an out-of-range countdown or mutate the phase. |
| PFM-10 | Active → success/failure result → resetting → greater-generation active sequences carry no prior result, reason, or countdown text forward. |
| PFM-11 | Repeated identical snapshots and times return equal deterministic frozen view models without accumulating temporary messages. |
| PFM-12 | Objective ownership is ready only for exactly one candidate with a valid owner ID equal to the local user; unresolved, foreign, malformed, and duplicate-owned candidates are not presented as the target. |

Thin Roblox presentation controller using narrow fakes:

| ID | Test |
| --- | --- |
| DHC-01 | First start creates exactly one GUI, performs one full snapshot read/render, and connects exactly the approved attribute, frame, and hierarchy signals. |
| DHC-02 | Repeated start returns the active controller and creates no duplicate GUI, listener, objective binding, or render loop. |
| DHC-03 | Attribute bursts defer a full reread; repeated callbacks may rerender but cannot append a second result/reset message or retain stale generation text. |
| DHC-04 | Render ticks update only mapped time text, and reaching zero performs no SetAttribute, remote call, lifecycle request, Character load, objective write, or local phase transition. |
| DHC-05 | Existing arena/objective hierarchy binds once; one locally owned objective is shown while foreign and unresolved objectives are locally hidden. |
| DHC-06 | Late arena, folder, objective, and owner-attribute replication converges to the same owner-specific visibility without a bootstrap retry or duplicate binding. |
| DHC-07 | Objective removal/replacement disconnects the old owner listener, restores surviving local transparency, and cannot let a retained callback alter the replacement. |
| DHC-08 | In-place objective position/slot changes preserve the same owner binding and create no new listener, GUI, or temporary feedback object. |
| DHC-09 | Zero or multiple owner-matching candidates hide all candidates and render syncing; returning to exactly one candidate restores one clear association. |
| DHC-10 | Character replacement is not subscribed to or retained and cannot create another GUI, render loop, objective binding, or movement/input system. |
| DHC-11 | Stop disconnects every owned signal, restores every surviving objective's prior local transparency, destroys the GUI, clears state, and is idempotent. |
| DHC-12 | Retained attribute, frame, hierarchy, and objective callbacks after stop are inert; a later restart creates one clean controller without old feedback. |
| DHC-13 | Separate simulated client contexts classify the same replicated objective set by their own local UserId and never share view or objective state. |
| DHC-14 | The production and fake dependency surfaces contain no remote, Player attribute writer, outcome callback, input service, Humanoid movement, camera, or server-controller path. |

The existing 104 deterministic cases remain present. Static analysis can prove strict
types and canonical Roblox requires. Lune can prove the mapper and controller
orchestration through fakes; it cannot validate actual ScreenGui rendering, text
visibility, color/contrast, physical objective visibility, replication ordering,
PlayerGui behavior, comprehension, default-control playability, or multiplayer
perception. Those claims require scoped human Studio evidence.

### Frozen-scenario coverage and required Studio evidence

Use one exact clean implementation/review commit only after the complete deterministic
gate passes and independent review has no unresolved blocker. Record the commit, place,
Rojo/Studio connection, mapped client-script count, server/client player counts and join
order, relevant attributes, visible text/objective identity on each client, all
server/per-client warnings and errors, and every limitation. The checkpoint must
distinguish direct observation from deterministic-only cleanup/partial-replication
evidence.

| Scenario | Exact TCK-0006 Studio observation |
| --- | --- |
| FP-01 | Start one player. Confirm exactly one primitive HUD appears, shows generation-one active objective/countdown feedback promptly, exactly one owner objective is visible, no second bootstrap/HUD/timer appears, and ordinary Roblox movement/camera/jump reach the arena without a custom movement system. |
| FP-02 | Walk the current living Character into the visible owned objective with normal controls. Confirm the same HUD changes promptly to clear `SUCCESS`, retains it through the server result interval, and later contacts do not append or replace the feedback. |
| FP-03 | Avoid the objective through the authoritative deadline. Confirm active seconds visibly decrease, zero causes no client-authored transition, and the later server result is clearly shown as timeout failure with the result-interval countdown. |
| FP-04 | In separate rounds, die and fall below the configured void boundary. Confirm clear death and fall failure text, one result interval per round, and no duplicate feedback from repeated/stale Character signals. |
| FP-05 | Observe success and failure through result, reset, and automatic replay. Confirm `SUCCESS`/`FAILURE` remains visible during result, changes to a distinct reset countdown, then clears for exactly one greater-generation active countdown with the same player's newly positioned visible objective. |
| FP-06 | Inspect the mapped client/server tree and runtime network surface: no result/timer/reset/generation remote or client attribute writer exists. Let a client countdown reach zero and confirm it only waits for replicated server state; presentation never changes authoritative attributes or another client. |
| FP-07 | Continue touching/moving during result/reset and observe normal multi-attribute updates. Confirm no duplicate/stale terminal message or older-generation countdown survives. Retained-callback and forced partial-order permutations remain deterministic evidence, not a Studio rendering claim. |
| FP-08 | In separate runs, remove the late player once during active and once during result/reset. Confirm the remaining client's HUD, objective association, countdown, and result do not change, the removed client produces no late presentation error, and deterministic stop tests cover listener/transparency cleanup that cannot be directly observed after disconnect. |
| FP-09 | Start a local server with Player 1 only and wait until Player 1 is visibly active. Then start Player 2 late. On each client, record local UserId, generation, deadline, HUD text, and visible objective owner/slot. Confirm Player 2 immediately gets exactly one independent HUD/countdown and sees only Player 2's objective; Player 1 retains its prior HUD/countdown/result and sees only Player 1's objective. Resolve one player while the other remains active and confirm the two presentations advance independently. |
| FP-10 | Complete one success then one failure and, in a separate run, one failure then one success. After every automatic reset, confirm prior result/reason/reset text disappears, one greater-generation active countdown starts, exactly one HUD remains, the owner-visible objective is the new server position, and no stale countdown or duplicate bootstrap is visible. |

Character-reset and duplicate-bootstrap evidence is additionally required: reset or
replace the local Character during active and after a result, then confirm the same
single `ResetOnSpawn = false` HUD continues, exactly one owner objective remains
visible, and no extra connection-driven message, GUI, timer, input override, or client
warning appears. Stop play mode and record explicit server and per-client warning/error
counts, including zero.

This checkpoint is scoped to presentation of FP-01 through FP-10 on top of merged
server evidence. It does not reclassify headless results as rendering evidence, prove
fun, satisfy external playtesting, publish the place, or pass the first-playable
stopping gate.

### Risks, controls, and failure handling

- **Partial attribute replication:** phase, generation, result, reason, and deadline
  can arrive separately. Control: defer a full reread, validate complete combinations,
  use phase-specific countdown clamps, and fall back to preparing/generic failure
  instead of guessing.
- **Client authority leakage:** a local deadline or objective view could become an
  outcome path. Control: presentation has no writer, remote, server controller, or
  transition callback; zero is display-only.
- **Wrong-player objective exposure:** all server Parts replicate and full-capacity
  positions may overlap. Control: fail closed while owner metadata is unresolved or
  ambiguous, classify by local UserId, and change only local transparency.
- **Late hierarchy/join ordering:** the LocalScript, Player attributes, arena, folder,
  and objective may replicate in different orders. Control: bind existing state first,
  observe later hierarchy/attribute changes idempotently, and render syncing until
  coherent.
- **Duplicate bootstrap or feedback:** repeated starts/signals could create stacked
  GUI and timers. Control: one module singleton, one named GUI, stateless view
  replacement, exact listener ownership, and Studio exact-count evidence.
- **Character/reset leakage:** Character-local GUI or listeners could duplicate on
  replay. Control: use only persistent PlayerGui state and own no Character reference
  or connection.
- **Cleanup leakage:** local transparency or retained callbacks could survive stop.
  Control: store prior values, invalidate first, disconnect all, restore surviving
  Parts, destroy owned GUI, and test retained callbacks.
- **Presentation failure:** malformed replication or a missing hierarchy remains a
  non-authoritative preparing/syncing view. GUI construction failure reports one client
  warning, cleans partial resources, and does not retry unboundedly or affect the
  server. The implementation does not hide server errors or turn a presentation
  failure into gameplay state.
- **Visual/comprehension uncertainty:** deterministic strings and fakes cannot prove
  readability or that players recognize their target. Control: require direct
  one-player, consecutive-replay, two-player, and late-join Studio judgment before
  `STUDIO_PASS`.

Risk is medium because this slice crosses replicated Roblox attributes, PlayerGui,
per-client objective visibility, late join, and cleanup boundaries even though it owns
no outcome. The builder receives two complete-gate attempts. Planning validation and CI
consume no attempt. Any second failed builder complete gate stops implementation with
the failure, diagnostics, attempted approaches, and owner decision needed; scope does
not expand to compensate.

### Human decisions and explicit deferrals

The owner must now approve the exact placeholder text/mapping, owner-only visibility
policy, four-file implementation boundary, medium-risk/two-attempt budget, deterministic
matrix, Studio evidence, rollback, and deferrals before `PLAN_APPROVED` or implementation.
After implementation/review, only the owner may judge actual visibility, clarity,
objective association, ordinary-control playability, multiplayer/late-join
comprehension, consecutive replay cleanliness, and whether the first-playable stopping
gate passes.

Explicitly deferred:

- Final UI layout, art direction, typography, responsive polish, accessibility polish
  beyond this primitive readable checkpoint, icons, models, particles, animation,
  audio, music, and haptics.
- Persistence, saved progression, economy, currency, rewards, monetization, analytics,
  publishing, production release, migrations, permissions, moderation, external
  playtesting, and live observation.
- Obstacles, hazards beyond the existing void, sprint/dash, custom movement, input
  bindings, camera changes, additional mechanics, content, maps, places, matchmaking,
  and teleportation.
- Server lifecycle/timing/objective changes, remotes, client outcome requests,
  dependencies, frameworks, generalized UI/state/networking abstractions,
  configuration, project mapping, and frozen acceptance-test changes.
- Unattended Studio automation, evidence manifests, Studio locks/queues, concurrent
  worktrees, `OBSERVING`, `CLOSED`, and the first-playable stopping-gate decision. None
  is started or inferred by planning, CI, implementation, or even a future scoped
  Studio pass.

TCK-0002's historical `attempts_used: 7` against `attempt_budget: 2` remains a separate,
truthful workflow record. TCK-0006 does not edit that ticket, inherit its exception
chain, receive additional scope or attempts because of it, or use it to justify a new
framework or authority boundary.

### Rollback, exit evidence, and approval gate

Rollback is a normal revert of the future TCK-0006 implementation commit. Removing the
pure mapper/spec, reverting `DebugHudController` and its extended spec, and allowing the
existing placeholder controller to resume restores the merged TCK-0005 runtime. Stop
cleanup removes runtime-only GUI/listeners and restores local objective transparency.
The slice owns no saved place edits, server state, persistence, economy, published
assets, migrations, dependencies, configuration, input changes, or irreversible data.

Implementation exit requires all planned mapper/controller cases, the unchanged 104
existing cases, one authorized complete green `Checks.ps1` builder attempt, an
independent review with no unresolved blocker, and the scoped human Studio evidence
above for FP-01 through FP-10, especially FP-09 late joining. Ticket advancement remains
sequential: `PLAN_APPROVED → BUILDING → STATIC_PASS → CODE_REVIEW_PASS →
STUDIO_PASS → HUMAN_APPROVED → MERGED`. No implementation, attempt, Studio run,
merge, publishing action, `OBSERVING`/`CLOSED` state, or stopping-gate decision is
authorized or inferred by this plan.

The exact next decision is owner approval or requested revision of this TCK-0006 plan.
Until that explicit decision, the ticket remains `ACCEPTANCE_TESTS_FROZEN` with zero of
two builder attempts used.

## First-playable stopping gate

After the Studio-dependent slices pass their frozen scenarios, the owner must judge comprehension, reliable closure, and whether the loop merits another round. External playtesting, publishing, persistence, economy, permissions, and release work remain out of scope.
