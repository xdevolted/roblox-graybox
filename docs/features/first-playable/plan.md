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

## Slice 3 — Safe spawn and objective

- Behavior: construct the guarded gray platform/start and server-owned glowing zone, place it at a valid position different from the immediately previous round, and accept immediate success only from server-confirmed entry.
- Boundaries: thin server Roblox adapter; ordinary character movement only.
- Tests: engine-free placement selection and qualification rules where possible; Studio checks for geometry, touch/overlap behavior, and replication.
- Risk: medium. Attempt budget: two.
- Exit: static/review pass, then human Studio evidence for FP-01, FP-02, and relevant FP-06/FP-07 behavior.

## Slice 4 — Failure and reliable replay adapter

- Behavior: server-owned timeout, death, and void observations; brief result/reset periods; safe respawn; automatic replay; cleanup on disconnect/respawn.
- Tests: deterministic timers through injected observations, first-result wins, cleanup, repeated signals, and independent-player isolation.
- Risk: medium. Attempt budget: two.
- Exit: static/review pass, then human Studio evidence for FP-03 through FP-05, FP-08, and FP-10.

## Slice 5 — Primitive client feedback

- Behavior: present replicated countdown, success/failure, result interval, and reset countdown without client outcome authority.
- Tests: pure presentation mapping where useful; no claim that headless tests validate rendering or playability.
- Risk: medium because it crosses replication boundaries. Attempt budget: two.
- Exit: static/review pass, then human Studio evidence for visibility, duplicate bootstrap prevention, and late join behavior in FP-09.

## First-playable stopping gate

After the Studio-dependent slices pass their frozen scenarios, the owner must judge comprehension, reliable closure, and whether the loop merits another round. External playtesting, publishing, persistence, economy, permissions, and release work remain out of scope.
