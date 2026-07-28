# TCK-0004 Studio checkpoint - passed

- Tested branch: `feature/tck-0004-objective-success-observer`
- Tested branch-head and review commit: `ec6a1f6b232a3ac1404666f123c09fdcdffbc29e`
- Builder implementation commit: `c5c213785bc7830ce4d6a5c6983f0fcabcb21ce3`
- Pull request: `#13`
- Date: 2026-07-28
- Studio place: `build/RobloxGraybox.rbxlx`
- Primary Studio process and MCP connection: PID `26188`, connection `81772fac-22bd-492e-9505-3943e3a1186c`
- Rojo: version `7.6.1`, listening on `127.0.0.1:34872` from the repository's unchanged `default.project.json`
- Result: passed
- Ticket consequence: this record supports `CODE_REVIEW_PASS -> STUDIO_PASS` only. It does not imply `HUMAN_APPROVED`, merge authority, publishing authority, or later-ticket authority.

## Exact-head preflight and mapping

- Local HEAD, the tracking branch, and the PR review head all equaled `ec6a1f6b232a3ac1404666f123c09fdcdffbc29e`. Local and remote `main` both remained `41c2740d6844a56326b5378e014bf3d958af69ac`.
- The worktree was clean. TCK-0004 was `CODE_REVIEW_PASS`, medium risk, with one of two builder attempts used.
- PR #13 was open, cleanly mergeable, limited to the approved implementation/review scope, and both exact-head CI paths were green. The unchanged reruns of push run `30363374518` and PR run `30363387843` succeeded after the initial GitHub tool-download 403.
- The independent review at the tested head reported zero BLOCKER, MAJOR, MINOR, and NIT findings.
- Studio began in Edit mode. Edit-mode `Workspace` contained only `Camera` and `Terrain`; no runtime arena or harness object was saved in the place.
- `ObjectiveSuccessAdapter` mapped exactly once at `ServerScriptService.Server.GameLoop.ObjectiveSuccessAdapter`.
- Direct source inspection showed Bootstrap retaining `PlayerRoundAdapter`, then `SafeSpawnObjectiveAdapter`, then `ObjectiveSuccessAdapter`. No client lifecycle authority or TCK-0004 remote was present.
- The full local gate was not rerun during Studio testing, no implementation file was edited, and no additional builder attempt was consumed.

## One-player checkpoint - passed

### Baseline

- The primary Studio Play session contained one player, `TheUnleshedBeast`, UserId `115613823`.
- The server created exactly one objective: `Workspace.GrayboxArena.Objectives.Objective_8`, same-session debug identity `0_495715`, slot `8`, owner `115613823`, position `(30, 0.75, 30)`, and size `(10, 0.5, 10)`.
- The objective was anchored, non-collidable, queryable, and touch-capable.
- Before contact, the player was `ACTIVE`, generation `1`, with nil result and nil failure reason.

### Owner contact and duplicate resistance

- Ordinary client character navigation moved the living current character onto `Objective_8`. The server-observed root position was approximately `(29.754, 4.649, 29.802)`, inside the objective's horizontal footprint.
- The server immediately observed `GrayboxRoundPhase = RESULT`, generation `1`, `GrayboxRoundResult = SUCCESS`, and nil failure reason.
- Navigation then moved the same character away and back onto the same objective. The state remained `RESULT`/`SUCCESS` at generation `1`; the objective count, identity, slot, owner, and position were unchanged.
- A server-triggered `LoadCharacter()` replaced the character. The completed generation and success result remained unchanged, and the same objective identity and placement remained active.
- The stable completed state is direct Studio evidence that repeated/stale contacts caused no visible second transition or mutation. Exact single-dispatch accounting and stale-generation rejection remain deterministic adapter-test evidence.

### Output and authority

- Server and client each printed the repository bootstrap-ready message and no repository warning or error.
- The only warning in each repository-facing output was the unrelated `Plugin loaded` Studio/plugin warning.
- Server inspection found 14 remotes, all under `ReplicatedStorage.DefaultChatSystemChatEvents`. TCK-0004 added no remote.
- Stopping Play returned Studio to Edit mode with only `Camera` and `Terrain` in `Workspace`.

## Two-player late-join checkpoint - passed

### Environment and evidence method

- From the primary Edit DataModel, `StudioTestService:ExecuteMultiplayerTestAsync(1, ...)` started one local test server with Player1 only. `StudioTestService:AddPlayers(1)` then added Player2 to the already-running server.
- The final passing session used play-test GUID `A7857381-69B7-4157-80F1-4062FA609C78`. The server command line declared exactly one startup player; the Player1 client began at `13:48:33`, and the late Player2 client began at `13:48:37`.
- A transient, unsaved server-only checkpoint script recorded server JSON snapshots and assertions. It used server-side character `PivotTo` only to deterministically create physical overlap for the multiplayer contact matrix; the production adapter still observed the normal server `Touched` signal. The one-player checkpoint above separately exercised ordinary walking.
- Player2 removal used a deliberate local-test `Kick`, then server assertions waited for the actual player-count reduction and objective cleanup.
- The harness was not written to the repository or saved into the place. It was destroyed after the session.

### Player1 baseline and Player2 late join

- Player1 (`-1`) began alone, `ACTIVE`, generation `1`, with nil result and nil failure reason.
- Player1 owned exactly `Objective_2`, slot `2`, position `(0, 0.75, -30)`.
- After the late join, Player2 (`-2`) was independently `ACTIVE`, generation `1`, with nil result and nil failure reason.
- Player2 owned exactly `Objective_3`, slot `3`, position `(30, 0.75, -30)`.
- Player1's objective name, slot, owner, position, lifecycle generation, phase, result, and failure reason were unchanged by the late join.

### Cross-owner rejection and independent success

- Player1 was physically placed on Player2's `Objective_3`. Both players remained `ACTIVE`, generation `1`, with nil results and nil failure reasons.
- Player1 was then physically placed on its own `Objective_2`. Player1 immediately became `RESULT`/`SUCCESS` at generation `1` with nil failure reason; Player2 remained `ACTIVE`.
- Player2 was physically placed on Player1's `Objective_2`. Player1 remained `RESULT`/`SUCCESS`; Player2 remained `ACTIVE` with nil result and nil failure reason.
- Player2 was then physically placed on its own `Objective_3`. Both players were independently `RESULT`/`SUCCESS` at generation `1`, with nil failure reasons.
- Objective count, names, slots, owners, positions, and per-player isolation remained unchanged throughout the contact matrix.

### Removal cleanup and retained owner

- Player2 was disconnected from the local test. The server directly observed one remaining player and one remaining objective.
- Player2's objective was removed.
- Player1 retained `Objective_2`, slot `2`, owner `-1`, position `(0, 0.75, -30)`, and `RESULT`/`SUCCESS` at generation `1`.
- The final server remote inventory contained exactly the 14 default chat remotes and no TCK-0004 or harness remote.
- The harness printed `[TCK-0004-HARNESS] PASS`, and the launcher returned `TCK-0004 PASS`.

### Output classification

- Repository server/client startup completed normally, with zero repository warnings or errors.
- Studio emitted known non-repository StyleRule, plugin-icon, asset-loading, and `Plugin loaded` diagnostics. Player2's client also displayed the intentional checkpoint kick message. None originated from repository gameplay source.
- Preliminary unsaved harness iterations were discarded before the passing run because of harness-only cross-process signaling, restricted `GetDebugId`, and network-owned movement limitations. Those iterations did not change repository files, did not reveal a product failure, and did not consume a builder attempt.

## Clean shutdown and evidence boundary

- The passing multiplayer server and clients exited, leaving only primary Studio PID `26188` in Edit mode.
- The transient server and client harness scripts and control object were absent after cleanup.
- Edit-mode `Workspace` again contained only `Camera` and `Terrain`.
- Rojo remained connected at `127.0.0.1:34872`.
- Before this evidence record and ticket transition, the Git worktree was clean at the exact reviewed head.
- Direct Studio evidence covers server-observed owner success, foreign-contact rejection, two-player independence, late join, player removal, objective cleanup, unchanged surviving-player state, no new remote, and clean Edit-mode restoration.
- Dead-character, missing-humanoid, stale-character, stale/replaced-objective, inactive-round, missing-handle/state, duplicate-generation dispatch, shutdown idempotence, and exact dispatch counts remain deterministic Lune/static evidence and are not reclassified as Studio observations.
- Timers, timeout/death/void failure sources, result/reset intervals, replay, respawn orchestration, objective repositioning, client presentation, persistence/economy, publishing, multi-place work, and later-ticket behavior remained intentionally absent.

## Final disposition

**PASS.** TCK-0004 may advance from `CODE_REVIEW_PASS` to `STUDIO_PASS` with attempts unchanged at `1/2`. The exact next gate is owner review and explicit approval of this Studio result before `HUMAN_APPROVED`. Do not merge PR #13, publish, create another builder attempt, alter implementation, or begin later work without that authorization.
