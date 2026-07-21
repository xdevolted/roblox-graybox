# TCK-0003 Studio checkpoint - passed

- Tested branch: `feature/tck-0003-safe-spawn-objective`
- Tested branch-head commit: `d11b4b82a7691bbbfec0069f97323d2aa1148d6a`
- Corrected implementation commit: `de47e3e2297eca05040d82a095d1a91144d36a6b`
- Pull request: `#10`
- Date: 2026-07-21
- Studio place: `RobloxGraybox.rbxlx`
- Primary Studio MCP connection: `1c223cc1-f7e7-456a-a4cb-1d3f6ea4615c`
- Rojo connection: the existing server listened on `127.0.0.1:34872` from the repository's unchanged `default.project.json`.
- Result: passed. The connected single-player checkpoint passed first; the initially blocked two-player checkpoint was then completed through owner-assisted manual observation of one Server and two late-joined Client DataModels.
- Ticket consequence: this complete record supports advancing TCK-0003 from `CODE_REVIEW_PASS` to `STUDIO_PASS` only. It does not imply `HUMAN_APPROVED` or merge authority.

## Pre-check and mapping evidence

- Local, tracking, and live remote implementation heads all equaled the tested branch-head commit. Local `main` and `origin/main` both remained `991a4af21356f79ca237aa906e13978bd87c1da9`.
- The worktree was clean, TCK-0003 was `CODE_REVIEW_PASS` with medium risk and two of two attempts used, PR #10 was open and cleanly mergeable with the approved eight-file scope, and both exact-head CI paths were green.
- The independent re-review applied to corrected implementation commit `de47e3e2297eca05040d82a095d1a91144d36a6b` and reported zero BLOCKER, MAJOR, MINOR, and NIT findings.
- Studio began in Edit mode. Edit-mode `Workspace` contained only `Terrain` and `Camera`; no arena geometry was saved in the place.
- Rojo mapped `ServerScriptService.Server.Bootstrap`, `ServerScriptService.Server.GameLoop.SafeSpawnObjectiveAdapter`, and `ReplicatedStorage.Shared.GameLoop.ObjectivePlacement` exactly once. Direct Studio inspection showed the mapped Bootstrap source starting both retained controllers and the mapped module sources containing the reviewed adapter and eight-slot placement implementation.
- No local complete gate was rerun, no builder attempt was consumed, and no source, test, configuration, dependency, workflow, plan, acceptance, review, or runtime implementation file was edited.

## Single-player checkpoint - passed

### Environment

- Mode: primary Studio Play session.
- Runtime DataModels: one Server and one Client in the primary Studio process.
- Rojo and MCP remained connected throughout the session.
- Player: UserId `115613823`.

### Arena hierarchy and properties

The Server DataModel directly contained exactly one `Workspace.GrayboxArena` Folder with six children:

- `Platform`: Part; size `(96, 1, 96)`; position `(0, 0, 0)`; anchored, collidable, queryable, and touch-capable; SmoothPlastic gray.
- `GuardedSpawn`: neutral enabled SpawnLocation; size `(16, 1, 16)`; position `(0, 1, 0)`; anchored and collidable; `AllowTeamChangeOnTouch = false`.
- `StartBackWall`: Part; size `(20, 4, 1)`; position `(0, 2.5, -10)`; anchored and collidable.
- `StartLeftWall`: Part; size `(1, 4, 20)`; position `(-10, 2.5, 0)`; anchored and collidable.
- `StartRightWall`: Part; size `(1, 4, 20)`; position `(10, 2.5, 0)`; anchored and collidable.
- `Objectives`: Folder containing exactly one objective.

No duplicate arena, platform, spawn, wall, objectives container, or objective appeared.

### Spawn, objective, movement, and lifecycle observations

- The character's initial HumanoidRootPart position was approximately `(-4.559, 5.646, 5.028)`, above and inside the guarded spawn footprint rather than over the void or at an unrelated spawn.
- Ordinary character navigation left the guarded start through its positive-Z opening. The observed root position after leaving was approximately `(-0.139, 4.649, 17.605)`.
- The server-created objective was `Workspace.GrayboxArena.Objectives.Objective_8`, debug identity `487981`, with size `(10, 0.5, 10)`, position `(30, 0.75, 30)`, Neon material, anchored, non-collidable, queryable, and touch-capable.
- Its server-written attributes were `GrayboxObjectiveOwnerUserId = 115613823` and `GrayboxObjectiveSlot = 8`. The Client DataModel independently showed the same objective hierarchy, position, owner, and slot metadata.
- Before objective contact, the Player attributes were `GrayboxRoundPhase = ACTIVE`, `GrayboxRoundGeneration = 1`, `GrayboxRoundResult = nil`, and `GrayboxRoundFailureReason = nil`.
- The character walked onto/through the objective; its root position was approximately `(29.459, 4.649, 29.777)`. After contact, all four round values were unchanged, the objective count remained one, the objective identity remained `487981`, and its position remained `(30, 0.75, 30)`. No success, timer, result, reset, replay, or objective movement occurred.
- A server-triggered test character reload replaced the character. The new root position was approximately `(0.890, 4.654, -4.294)`, again above and inside the guarded spawn footprint. The objective count, identity, position, and all four round values remained unchanged.
- Server inspection found 14 remotes, all under Roblox's `ReplicatedStorage.DefaultChatSystemChatEvents`. There was no TCK-0003 lifecycle, result, objective-control, or placement remote.
- The live bootstrap-retained controller is local to Bootstrap and was not invoked from the checkpoint. Studio directly observed the server-owned objective association through hierarchy and truthful owner/slot metadata. The exact read-only `getAssignment`/`getObjective`/`stop` controller surface remains static-analysis and Lune evidence rather than a claimed direct Studio invocation.

### Single-player output

- Server LogService: repository bootstrap output present; zero errors; zero repository warnings. One `Plugin loaded` warning was present and was not emitted by repository source.
- Client LogService: repository bootstrap output present; zero errors; zero repository warnings. One `Plugin loaded` warning was present and was not emitted by repository source.
- Before Play, the primary Studio output also contained ViewSelector/model and plugin-icon loading diagnostics. They were Studio/plugin diagnostics, not server/client repository output.
- Stopping Play returned the primary Studio to Edit mode and left the worktree clean.

## Two-player checkpoint - blocked before observable assertions

### Launch evidence

- From the primary Edit DataModel, `StudioTestService:ExecuteMultiplayerTestAsync(2, "TCK-0003-late-join-cleanup")` launched one local test server and two local test clients as an MCP-attachment probe. Because both clients started together, this launch did not itself exercise or satisfy the required late-join sequence.
- Server process: PID `24476`, `-studiotestservicemode`, `-numTestServerPlayersUponStartup 2`, session GUID `0A819466-7D3F-42F4-A68A-C38FA2947AD0`.
- Client processes: PIDs `26836` and `27292`, the same StudioTestService session GUID.
- The process command lines used `build/RobloxGraybox.rbxlx` from this repository and confirmed one server plus two clients.

### Environment limitation

- `list_roblox_studios` continued to expose only the primary Edit Studio connection. The spawned test Server and both Client DataModels were absent from the MCP connection list and could not be selected or inspected.
- Consequently, no direct multiplayer claim is made for arena/objective counts, player slots, objective Instance identities, late-join isolation, cross-client replication, objective contact, per-client output, player removal, slot release, or remaining-player state.
- The multiplayer processes were validated by exact PID, parent relationship, `-studiotestservicemode`, and session GUID, then stopped. The primary Studio remained open in Edit mode and the approved Rojo server remained listening on port `34872`.
- The primary Studio reported `[TCK-0003] Multiplayer test ended: nil` after the temporary processes were stopped. That result is not treated as a gameplay pass or failure; it records termination of an unobservable test session.

## Automated-only evidence and deferred behavior

- Ninth-player `NO_AVAILABLE_SLOT`, exact cyclic assignment behavior, duplicate-signal rejection, isolated cleanup, controller shutdown, and read-only seam behavior remain deterministic Lune/static evidence. They were not claimed as Studio observations.
- The following remain intentionally absent and were not treated as failures: touch or occupancy qualification, lifecycle `SUCCEED`, timers, timeout/death/void failures, automatic reset, replay, objective repositioning, result-display timing, broad respawn orchestration, client presentation, objective-control remotes, client-authoritative placement/outcomes, persistence, economy/monetization, analytics, publishing, and multi-place expansion.

## Required owner-operated completion

The checklist below was recorded while the multiplayer checkpoint was incomplete. It is preserved as the exact requirement that the later owner-assisted completion satisfied.

Using the exact reviewed TCK-0003 source and the repository's normal local-server workflow:

1. Start one local test server with Player 1 only. Confirm exactly one arena/spawn foundation and one objective.
2. Record Player 1's slot, objective position, Instance identity, association metadata, and four round attributes.
3. Add Player 2 late through the server-side StudioTestService/local-server control, then confirm Player 2 receives a different objective and deterministic slot while every recorded Player 1 value and identity remains unchanged.
4. Confirm both clients replicate the arena and both objectives with truthful owner/slot metadata, and record server plus per-client warning/error counts.
5. Move each player onto an objective and confirm both remain `ACTIVE`, generation `1`, nil result, and nil failure reason with unchanged objective identities and positions.
6. Remove Player 2 and wait until the server's `Players:GetPlayers()` actually confirms removal. Then confirm only Player 2's objective/assignment/association is gone while Player 1's objective, slot, identity, association, and round state remain unchanged.
7. Confirm no duplicate objective, geometry recreation/destruction, transition, cleanup error, retained callback, TCK-0003 remote, timer, failure, reset, replay, repositioning, or client result presentation appears.
8. Stop the local multiplayer session and confirm no persistent Studio edit or source-controlled change remains.

Only after those observations pass truthfully may this record be completed and TCK-0003 advance from `CODE_REVIEW_PASS` to `STUDIO_PASS`. No human approval or merge is implied.

## Owner-assisted local multiplayer completion - passed

### Exact environment and late-join sequence

- The completion used the same tested branch head `d11b4b82a7691bbbfec0069f97323d2aa1148d6a` and corrected implementation commit `de47e3e2297eca05040d82a095d1a91144d36a6b` in `RobloxGraybox.rbxlx`.
- The primary Edit Studio remained PID `29968` on MCP connection `1c223cc1-f7e7-456a-a4cb-1d3f6ea4615c`. Rojo remained connected to the unchanged root project through listener PID `2476` at `127.0.0.1:34872`.
- The owner used Studio's normal Server & Clients controls. Server PID `22496` started at 02:19:13 with exactly one startup player under play-test session GUID `1487253C-3693-4439-AE40-1EEEC52BFDDA`; Client 1 PID `30272` started at 02:19:16.
- Client 2 PID `26788` was added at 02:26:21 to that already-running server. The unchanged server PID, original Client 1 PID, common session GUID, and later Client 2 creation time directly establish a late join rather than a simultaneous two-client launch or restarted session.
- MCP still exposed only the primary Edit Studio as an operable DataModel. The owner therefore ran the supplied read-only Command Bar snapshots separately in Server, Client 1, and Client 2 and returned their exact output. No script, hook, remote, Instance, or persistent Studio object was added.

### Stage 1 - Server and Player 1 baseline

- Server `Players:GetPlayers()` contained exactly `Player1`, UserId `-1`.
- Exactly one `Workspace.GrayboxArena` Folder existed. It had exactly six direct children: one `Platform`, one neutral `GuardedSpawn`, `StartBackWall`, `StartLeftWall`, `StartRightWall`, and one `Objectives` Folder. Each expected class/name pair occurred exactly once.
- Exactly one objective existed: `Workspace.GrayboxArena.Objectives.Objective_2`, same-session debug identity `0_337381`, parent `Workspace.GrayboxArena.Objectives`, size `(10, 0.5, 10)`, and position `(0, 0.75, -30)`.
- Its server-written metadata was `GrayboxObjectiveOwnerUserId = -1` and `GrayboxObjectiveSlot = 2`.
- Player 1 was `ACTIVE`, generation `1`, with nil result and nil failure reason.
- Client 1 independently replicated exactly that objective name, hierarchy, slot, owner, and position.
- The initial server and Client 1 histories each contained one unrelated `Plugin loaded` warning and four unrelated plugin-icon loading errors. No message referred to repository source, mapping, bootstrap, objective placement, lifecycle, cleanup, or a retained callback.

### Stage 2 - Player 2 late join and isolation

- After Client 2 joined the existing server, `Players:GetPlayers()` contained `Player1`/`-1` and `Player2`/`-2`, each `ACTIVE`, generation `1`, with nil result and nil failure reason.
- Player 2 received exactly one distinct server-created objective: `Workspace.GrayboxArena.Objectives.Objective_3`, debug identity `0_427152`, slot `3`, owner metadata `-2`, size `(10, 0.5, 10)`, and position `(30, 0.75, -30)`.
- Player 1's objective retained identity `0_337381`, name `Objective_2`, slot `2`, owner `-1`, position `(0, 0.75, -30)`, hierarchy, parent, and all four lifecycle values.
- The arena debug identity was `0_250421`; exactly one arena root and the same six foundation children existed after the join. Exactly two objectives existed, with distinct identities, slots, owners, and positions.
- Client 1 and Client 2 each directly showed both objectives with the same names, hierarchies, slots, owners, and positions as the server. Each client also showed both players independently `ACTIVE`, generation `1`, with nil result and nil failure reason.
- Server, Client 1, and Client 2 histories contained only the same known plugin/plugin-icon diagnostics. No repository warning, mapping error, duplicate initialization, retained callback, or cross-player mutation appeared.
- Client authority was not exercised or invented. The absence of a client mutation surface is supported by the reviewed implementation/static evidence and the observed absence of any TCK-0003 remote; the replicated client snapshots are direct observation only.

### Stage 3 - Objective-contact isolation

- Before contact, the Stage 2 server snapshot recorded both objective identities and both players' unchanged lifecycle states.
- Player 1 then moved by ordinary controls onto `Objective_2`; its server-observed HumanoidRootPart position was approximately `(0.744, 4.649, -28.311)`, inside that objective's horizontal footprint. Player 2 remained near the guarded spawn.
- After Player 1 contact, both players remained `ACTIVE`, generation `1`, with nil result and nil failure reason. Objective identities `0_337381` and `0_427152`, count, slots, owners, and positions were unchanged.
- Player 2 then moved by ordinary controls onto `Objective_3`; its server-observed HumanoidRootPart position was approximately `(29.958, 4.649, -29.229)`, inside that objective's horizontal footprint. Player 1 remained on `Objective_2`, so the two contacts were added sequentially rather than simultaneously.
- After Player 2 contact, both players again remained `ACTIVE`, generation `1`, with nil result and nil failure reason, and both objective identities and descriptors remained unchanged.
- Direct observation therefore found no `SUCCEED`, phase or generation change, result, failure reason, objective movement/replacement/duplication/deletion, cross-player assignment effect, timer, reset, replay, result presentation, or other deferred behavior.
- Client 2's final pre-removal snapshot still showed both players and both objectives unchanged and contained only the known plugin/plugin-icon diagnostics.

### Stage 4 - Player 2 removal and Player 1 preservation

- The owner closed only Client 2 while preserving Server and Client 1. The subsequent Server Command Bar snapshot directly observed `Players:GetPlayers()` at exactly one player, `Player1`; client-window closure alone was not used as proof.
- Player 2's `Objective_3` was absent and the Objectives Folder contained exactly one objective. No duplicate or orphaned Player 2 objective remained.
- Player 1's `Objective_2` retained debug identity `0_337381`, name, hierarchy, parent, slot `2`, owner `-1`, and position `(0, 0.75, -30)`. Player 1 remained `ACTIVE`, generation `1`, with nil result and nil failure reason.
- The arena retained debug identity `0_250421`, exactly one root, and exactly the same six foundation children; it was not duplicated or recreated.
- Client 1 independently replicated exactly one remaining player and exactly `Objective_2` with the unchanged hierarchy, slot, owner, and position.
- Server and Client 1 histories still contained only the known plugin/plugin-icon diagnostics. No cleanup error, retained-callback error, duplicate initialization, repository warning, or mapping failure appeared.
- Server inspection found exactly 14 remotes, all under `ReplicatedStorage.DefaultChatSystemChatEvents`. No TCK-0003 lifecycle, placement, objective-control, result, timer, reset, replay, failure, repositioning, or feedback remote existed.
- Removal of the visible Player 2 objective and owner/slot association metadata was directly observed. The controller-local placement-registry entry and read-only controller lookup cannot be invoked from this checkpoint and remain static/Lune cleanup evidence.

### Stage 5 - Clean shutdown

- The remaining multiplayer session ended normally. Server and both client processes exited, leaving only primary Studio PID `29968` in Edit mode.
- Rojo remained connected at `127.0.0.1:34872` through listener PID `2476`.
- Edit-mode Workspace again contained only `Camera` and `Terrain`; `GrayboxArena` was absent, so no runtime geometry persisted into the place.
- No place was saved or created. Before this record and the authorized ticket update, the worktree still contained only this intentional untracked evidence file at its original SHA-256 `A75257BE9AB11A06216F6880A627D54FFA6B34AD2E3BBFB22F76D286D2DBC934`.

### Direct evidence boundary and final disposition

- Direct Studio evidence covers the owner-operated process/join/removal sequence; arena and objective hierarchy/counts; Player identities; server objective identities; slots, owners, parents, sizes, and positions; both-client replication; contact isolation; server-confirmed Player 2 removal; Player 1 preservation; remotes; process output; and clean shutdown.
- Deterministic cyclic collision resolution beyond these two slots, ninth-player `NO_AVAILABLE_SLOT`, duplicate-signal handling, internal assignment-registry cleanup, controller lookup/stop behavior, and shutdown idempotence remain static/Lune evidence and are not reclassified as Studio observations.
- The intentionally deferred qualification, success, timer, failure, reset, replay, repositioning, feedback, persistence, economy, publishing, and multi-place behavior remained absent.
- **Final result: PASS.** The complete TCK-0003 single-player and owner-assisted local-multiplayer Studio checkpoint supports `CODE_REVIEW_PASS -> STUDIO_PASS`. It does not authorize `HUMAN_APPROVED`, merge PR #10, publishing, another builder attempt, implementation correction, or later-ticket work.
