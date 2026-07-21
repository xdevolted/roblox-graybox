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

- Behavior: observe only a living player's entry into that player's assigned objective, capture the current round session handle and generation from the merged round controller, and submit exactly one server-owned `SUCCEED` event immediately after qualification.
- Boundaries: no client request, dwell duration, timer, failure source, reset, respawn, or UI. Own and clean all touch/overlap connections and reject another player's objective, stale character, stale session, stale generation, and duplicate entry.
- Tests: deterministic qualification filtering and adapter orchestration through narrow fakes; Studio verifies real character parts, physics queries/touches, immediate success, multiplayer isolation, and cleanup.
- Risk: medium. Attempt budget: two.
- Exit: static/review pass, then human Studio evidence for the remaining TCK-0003-blocked portions of FP-02 and relevant FP-06/FP-07/FP-08 isolation.

## Slice 5 — Failure and reliable replay adapter

- Behavior: server-owned timeout, death, and void observations; brief result/reset periods; safe respawn; per-player objective repositioning to a valid slot different from that player's immediately previous slot; automatic replay; cleanup on disconnect/respawn.
- Tests: deterministic timers through injected observations, first-result wins, previous-slot exclusion, cleanup, repeated signals, and independent-player isolation.
- Risk: medium. Attempt budget: two.
- Exit: static/review pass, then human Studio evidence for FP-03 through FP-05, FP-08, and FP-10.

## Slice 6 — Primitive client feedback

- Behavior: present replicated countdown, owner-specific objective visibility/association, success/failure, result interval, and reset countdown without client outcome authority.
- Tests: pure presentation mapping where useful; no claim that headless tests validate rendering or playability.
- Risk: medium because it crosses replication and presentation boundaries. Attempt budget: two.
- Exit: static/review pass, then human Studio evidence for visibility, duplicate bootstrap prevention, and late-join behavior in FP-09.

## First-playable stopping gate

After the Studio-dependent slices pass their frozen scenarios, the owner must judge comprehension, reliable closure, and whether the loop merits another round. External playtesting, publishing, persistence, economy, permissions, and release work remain out of scope.
