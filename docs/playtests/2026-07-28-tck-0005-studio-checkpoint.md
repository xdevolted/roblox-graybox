# TCK-0005 Studio checkpoint - multiplayer blocked

## Scope and exact state

- Ticket: `TCK-0005` at `CODE_REVIEW_PASS`.
- Exact implementation/review commit tested: `fcd80e0bff803535ab1524e0f42dbc84b9319bd7`.
- Pull request: `#16`, open and cleanly mergeable before the checkpoint.
- Exact-head CI: push run `30415942351` and pull-request run `30415944484` both passed.
- Studio place: local `build/RobloxGraybox.rbxlx`, displayed as `RobloxGraybox`.
- Place identity: `PlaceId = 0`; no published place or universe exists.
- Primary Studio process: PID `12228`.
- Studio MCP: connected to the primary Edit, Server, and Client DataModels as each became available.
- Rojo: connected root project through listener PID `11604` at `127.0.0.1:34872`.
- Repository state: clean and synchronized before Studio; no source, test, configuration, acceptance, or saved-place change was made during the checkpoint.

This is an incomplete checkpoint. It records passing single-player observations and a Roblox Studio infrastructure blocker that prevented the required two-player FP-08/isolation evidence. It does not support `STUDIO_PASS`.

## Edit-mode preflight

- Studio began in Edit mode.
- Edit-mode `Workspace` contained only `Terrain` and `Camera`; no arena or checkpoint object was saved in the place.
- `ServerScriptService.Server.GameLoop.FailureReplayAdapter` mapped exactly once. The mapped source contained the reviewed authoritative post-`START` generation readback and per-player protected heartbeat update from correction commit `b30f4f6d6ec31ba41697080822cb94d0e180c034`.
- The merged Bootstrap, player-round, safe-spawn/objective, objective-success, placement, and lifecycle modules remained at their expected single mapped paths.
- No `RemoteEvent`, `RemoteFunction`, or `UnreliableRemoteEvent` existed.
- The only mapped LocalScript remained the pre-existing `StarterPlayer.StarterPlayerScripts.Client.Bootstrap`; TCK-0005 added no client script.

## Single-player runtime

- Mode: primary Studio Play session with one Server and one Client DataModel.
- Player: `TheUnleshedBeast`, UserId `115613823`.
- Runtime `Players.CharacterAutoLoads` was `false`.
- The initial observed player state was `ACTIVE`, generation `1`, with a server-time `GrayboxPhaseEndsAt`, a current Character at the guarded start, and one owned objective.
- The server-created arena and objective existed only at runtime. The final client snapshot replicated clean `ACTIVE` generation `10`, the current Character, `GrayboxPhaseEndsAt`, and owned `Objective_1` at slot `1`, position `(-30, 0.75, -30)`.

### FP-03 - timeout failure

**PASS for the single-player runtime contribution.**

- The player remained away from the objective and above the void boundary until the authoritative deadline.
- Generation `2` entered immutable `RESULT` with `GrayboxRoundResult = FAILURE` and `GrayboxRoundFailureReason = TIMEOUT`.
- The same objective Instance remained owned by the player, moved from slot `1` to different valid slot `2`, and retained identity through reset.
- A replacement Character appeared during `RESETTING`.
- Exactly one clean `ACTIVE` generation `3` followed with no result or failure reason and a fresh server-time deadline.

### FP-04 - death and void failure

**PASS for the single-player runtime contribution.**

- Current-Humanoid death in `ACTIVE` generation `3` produced immutable `RESULT/FAILURE/DEATH`.
- The result deadline was approximately two seconds after observation. Reset moved the same objective from slot `2` to slot `3`, loaded one replacement Character, and began clean `ACTIVE` generation `4` after the one-second reset deadline.
- Moving the current Character pivot from above the boundary to `Y = -25` in `ACTIVE` generation `4` produced immutable `RESULT/FAILURE/VOID`.
- Reset moved the same objective from slot `3` to slot `4`, loaded a replacement Character, and began clean `ACTIVE` generation `5`.
- No later source replaced either accepted failure reason.

### FP-05 - reset and automatic replay

**PASS for the single-player runtime contribution.**

- Direct transition snapshots across timeout, death, void, and success showed the immutable result interval, cleared terminal attributes in `RESETTING`, one different-slot objective movement, one replacement Character, the minimum reset interval, and one greater-generation `ACTIVE` replay.
- The objective Instance identity remained stable across every observed reset.
- Character identity changed once per completed reset.
- Slots advanced deterministically without immediately reusing the prior slot.
- Fresh active deadlines were approximately twenty seconds after the accepted replay start.
- A transient first snapshot after a terminal transition could still show the prior timing attribute before the adapter's next publication write. This is the already-approved non-authoritative attribute refresh limitation; the following heartbeat published the result deadline, and no authoritative state was affected.

### FP-10 - consecutive replay stability

**PASS for the single-player runtime contribution.**

- A client-side Character move to the owned objective caused a success replay before the next server sampler attached, advancing the clean lifecycle from generation `5` to generation `6`.
- A fully sampled success in generation `7` produced immutable `RESULT/SUCCESS`, moved the same objective from slot `6` to slot `7`, loaded a replacement Character, and began clean generation `8`.
- Death in generation `8` then produced `RESULT/FAILURE/DEATH`, moved the objective from slot `7` to slot `8`, and began clean generation `9`. This directly covered success followed by failure.
- Success in generation `9` produced `RESULT/SUCCESS`, moved the objective from slot `8` to slot `1`, and began clean generation `10`. This directly covered failure followed by success.
- Every replay had a greater generation, no carried result or failure reason, no stale deadline, no duplicate bootstrap, and no immediately reused objective slot.

## Runtime output

- Repository output contained only `[RobloxGraybox] Server bootstrap ready` and `[RobloxGraybox] Client bootstrap ready`.
- Each side also displayed the pre-existing unrelated `Plugin loaded` line.
- No repository warning, error, reset failure, duplicate transition, or load failure was observed in the passing single-player session.
- Stopping Play returned the primary Studio process to Edit mode.

## Required multiplayer attempt

The approved checkpoint requires a late second player, independent simultaneous outcomes, disconnect cleanup during `ACTIVE` and `RESULT` or `RESETTING`, and proof that the surviving player's lifecycle, Character, objective, and timer remain unchanged.

Two equivalent human/MCP launch paths were attempted:

1. `StudioTestService:ExecuteMultiplayerTestAsync(1, "TCK-0005-isolation-disconnect")` from the primary Edit DataModel.
2. Studio's normal human-operated **Server & Clients** control with one client.

Both attempted to open a local test server from the unpublished place with `PlaceId = 0` and `UniverseId = 0`. Studio failed before the gameplay DataModel opened with:

> We could not open the place [0]. Failed to get provisional rating for universe 0, with error code 500.

- Owner-reported incident ID: `385201121285637827`.
- Failed Studio child server: PID `20908`, parent PID `12228`, play-test session GUID `7C498EB1-FFB0-40F8-A678-BA2D0D8A0467`.
- The child log recorded `GetPlaceSafetyInfoFailure`, HTTP status `500`, `placeid: 0`, `universeid: 0`, `launchIntent: StartServer`, and `WorkflowResult: Failure`.
- The failed server never reached repository Bootstrap and produced no Graybox gameplay evidence.
- The exact failed child process was verified by parent, command line, test mode, and session GUID, then stopped. The primary Studio and Rojo server remained open.

This is a Roblox Studio/local-place infrastructure failure, not an implementation failure. Repeating the same launch cannot create valid FP-08 evidence.

## Scenario result and remaining decisions

| Scenario | Result | Evidence boundary |
| --- | --- | --- |
| FP-03 | Single-player PASS | Real timeout, immutable reason, reset, replacement, objective movement, and replay observed. |
| FP-04 | Single-player PASS | Real Humanoid death and below-boundary Character observations, immutable reasons, and replay observed. |
| FP-05 | Single-player PASS | Real result/reset timing, Character replacement, stable objective identity, different slot, and greater generation observed. |
| FP-08 | BLOCKED | Required two-player disconnect and surviving-player isolation could not run because Studio rejected the unpublished local test server. |
| FP-10 | Single-player PASS | Success-to-failure and failure-to-success replay orderings were observed through clean generations. |

The exact checkpoint result is **INCOMPLETE - MULTIPLAYER INFRASTRUCTURE BLOCKED**.

- TCK-0005 remains at `CODE_REVIEW_PASS`.
- This record does not authorize `STUDIO_PASS`, `HUMAN_APPROVED`, merge, publishing, Slice 6, or another builder attempt.
- No builder attempt was consumed because no implementation correction or complete builder gate occurred.
- Deterministic Lune coverage for two-player isolation, active/result/reset removal, stale callbacks, load failure, shutdown, and full-capacity fallback remains green but is not reclassified as Studio evidence.
- TCK-0002 and its historical attempts remain unchanged.

The owner must choose one of two later paths:

1. Retry the approved local Server & Clients checkpoint after Roblox restores unpublished-place multiplayer testing.
2. Explicitly authorize the human-only creation of a private test experience, open that cloud place with valid place and universe IDs, synchronize the unchanged filesystem through Rojo, and run only the remaining multiplayer evidence.

Publishing remains deferred and was not authorized or performed by this checkpoint.
