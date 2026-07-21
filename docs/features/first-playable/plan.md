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

- Behavior: own one lifecycle per player, start one independent round on join, expose read-only state, and translate only server observations into model events.
- Boundaries: `src/server/` adapter plus focused shared adapter seams and tests; no client result remote.
- Tests: ownership/isolation, join/leave cleanup, duplicate initialization, stale generation, and result immutability.
- Risk: medium authority/lifecycle work. Attempt budget: two.
- Exit: static gate and independent review pass, followed by an exact human Studio checklist. No `STUDIO_PASS` without observed evidence.

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
