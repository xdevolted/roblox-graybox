# First playable specification

**Status:** Approved; acceptance scenarios frozen by the owner on 2026-07-20.

## Player-facing behavior

The player spawns on a small floating gray platform inside an identifiable guarded start. A glowing safe zone appears at a valid position elsewhere on the platform and the server begins the round timer. The player moves with normal Roblox character controls. Reaching the server-recognized safe-zone condition wins; timeout, death, or falling into the void fails. A short result display is followed by automatic respawn, a new valid safe-zone position different from the previous round, a reset timer, and another round.

The first graybox supports one to eight players, primitive countdown/result/reset feedback, and repeatable session-only rounds. Every player owns an independent round lifecycle. Success occurs immediately after the server confirms safe-zone entry. A late joiner starts an independent round immediately without changing any existing player's state.

## Proposed lifecycle

| State | Entry | Allowed terminal event | Exit |
| --- | --- | --- | --- |
| `WAITING` | No active round; initial or post-reset state | None | `START` begins `ACTIVE` |
| `ACTIVE` | Timer and round generation are active | `SUCCEED` or `FAIL` | First accepted terminal event begins `RESULT` |
| `RESULT` | Immutable success/failure result is available for feedback | Duplicate terminal events are ignored | `BEGIN_RESET` begins `RESETTING` |
| `RESETTING` | Prior-round state is cleared and next generation is prepared | None | `FINISH_RESET` returns to `WAITING` |

`START` from the next `WAITING` state begins replay with a strictly greater round generation. Invalid transitions return a rejection and leave state unchanged. The model does not measure wall-clock time or inspect Roblox objects; adapters translate authoritative observations into lifecycle events.

## Authority and validation

- Server: lifecycle state, monotonically increasing round generation, accepted terminal result, time expiration, death/fall observation, safe-zone qualification, valid zone selection, respawn, and reset.
- Client: ordinary character input and presentation of replicated state only.
- There is no client API for declaring success, failure, timeout, reset, or round generation. Any such unexpected request must be rejected without mutation.
- Adapter inputs must validate event type, current state/context, player/round ownership, matching generation, and duplicate frequency.

## Reset and replay invariants

- Exactly one terminal result is accepted per round generation.
- Reset clears the prior result before another round starts.
- A new round has a strictly greater generation and no carried terminal result.
- The next safe-zone position is valid and differs from the immediately previous position.
- Connections, character references, and temporary feedback from the previous round are cleaned up by their Roblox adapters.

## Proposed slice sequence

1. `TCK-0001`: pure deterministic round lifecycle and exhaustive Lune specifications.
2. Thin server-authoritative round adapter and replicated read-only round state.
3. Server-owned safe-zone placement and qualification plus one validated outcome path.
4. Server-owned timeout/death/void failure paths and reliable respawn/reset.
5. Primitive client countdown/result/reset feedback and default movement integration.
6. Multiplayer hardening for independent player lifecycles, including join/leave cleanup and isolation.

## Non-goals

- Persistence, saved progression, economy, monetization, analytics, publishing, or production release.
- Final UI, art, animation, audio, models, or content pipelines.
- Obstacles beyond the simple guarded platform, matchmaking, teleportation, multiple maps, or another place.
- Unattended Studio automation, evidence manifests, Studio locks/queues, concurrent worktrees, or Open Cloud.
- A service framework, ECS, roblox-ts, pesde, or a third-party test framework.
