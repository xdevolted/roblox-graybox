# TCK-0002 Studio checkpoint - passed

- Human-observed multiplayer tested commit: `0fdd8ccfc5d6fcfe6c3fcc4cabab99f864c69025`
- Earlier connected one-player tested commit: `9932e57d309861e8b8eed949362396921f2deabb`
- Branch: `feature/tck-0002-server-round-adapter`
- Pull request: `#7`
- Studio place: `RobloxGraybox.rbxlx`
- Studio MCP connection: `16c65c57-988c-4fd4-98df-bd31f6460d22`
- Rojo connection: the existing single server was listening on `127.0.0.1:34872`
- Player count observed through the earlier connected Play session: one
- Human-observed local multiplayer player count: one initially, then two after the late join
- Pre-check evidence: the worktree was clean, the ticket was at `CODE_REVIEW_PASS`, the complete post-review `Checks.ps1` gate passed with 40 tests passed and 0 failed, and both refreshed PR CI runs were green for the exact tested commit.

## Passed observations

- The root project was built and synchronized. `PlayerRoundRegistry` mapped exactly once at `ReplicatedStorage.Shared.GameLoop.PlayerRoundRegistry`, and `PlayerRoundAdapter` mapped exactly once at `ServerScriptService.Server.GameLoop.PlayerRoundAdapter`.
- In a one-player Play session, the real `Player` had `GrayboxRoundPhase = ACTIVE`, `GrayboxRoundGeneration = 1`, and no `GrayboxRoundResult` or `GrayboxRoundFailureReason` attribute value.
- Reloading the same player's character replaced the character while all four round attributes remained unchanged at `ACTIVE`, generation `1`, nil result, and nil failure reason. Character creation did not increment the generation.
- A client-local edit changed that client's displayed `GrayboxRoundPhase` to `FORGED_CLIENT`; the server continued to observe `ACTIVE`, generation `1`. Client-local attribute mutation did not become server lifecycle authority.
- The DataModel contained 14 `RemoteEvent`/`RemoteFunction` instances, all under Roblox's `ReplicatedStorage.DefaultChatSystemChatEvents`. No TCK-0002 result remote, lifecycle remote, or client transition path was present.
- An unsaved server-side smoke check required the mapped registry and passed duplicate initialization, wrong-handle rejection, stale and future generation rejection without publication, accepted terminal success, clean reset/replay to `ACTIVE` generation `2`, player isolation, removal, unknown-player rejection, replacement-session creation, and old-handle rejection. The smoke check returned `PASS publications=10 replayGeneration=2 oldHandle=SESSION_MISMATCH playerB=ACTIVE/1`.
- No Studio Instance or script was created or saved by the checkpoint. The one-player session was stopped and the primary Studio returned to Edit mode.

## Earlier multiplayer observation limitation

- The connected MCP `start_stop_play` surface creates a single Play client. Calling `StudioTestService:AddPlayers(1)` from that session correctly reported that it was not a running Studio test session.
- `StudioTestService:ExecuteMultiplayerTestAsync(1, "TCK-0002-late-join-cleanup")` launched a separate local test server and client, but the built-in MCP connection could not attach to their Server or Client DataModels. Consequently, the checkpoint could not truthfully observe a late second player's independent `ACTIVE` generation `1` attributes or remove one player and observe that the remaining player's attributes stayed unchanged.
- The exact temporary `-studiotestservicemode` server and client processes launched by this attempt were identified by parent/process command lines and stopped. The primary `RobloxGraybox.rbxlx` Studio process remained open and connected.

## Completed human-observed local multiplayer evidence

- The human confirmed the local multiplayer Studio checkpoint on exact commit `0fdd8ccfc5d6fcfe6c3fcc4cabab99f864c69025` using a Studio local multiplayer session and `StudioTestService` for the disconnect step.
- Player one was already active with `GrayboxRoundPhase = ACTIVE`, `GrayboxRoundGeneration = 1`, `GrayboxRoundResult = nil`, and `GrayboxRoundFailureReason = nil` before the late join.
- Late player two independently initialized with `GrayboxRoundPhase = ACTIVE`, `GrayboxRoundGeneration = 1`, `GrayboxRoundResult = nil`, and `GrayboxRoundFailureReason = nil`. Player one's four values remained unchanged.
- Calling `StudioTestService:LeaveTest()` closed player two's Studio client window immediately. The local test server nevertheless retained player two in `Players:GetPlayers()`, and player two remained visible to player one, for more than two minutes. An inspection during that interval correctly still reported player two because server-side removal had not completed.
- Once player two actually left the server and disappeared from `Players:GetPlayers()`, the after-disconnect inspection reported only player one. Player one's lifecycle remained unchanged at `ACTIVE`, generation `1`, nil result, and nil failure reason.
- No duplicate transition, cleanup error, late callback, test failure, or unexpected state change was observed. The delayed server-side removal after the client window closed is recorded as Studio test-harness teardown behavior, not as evidence that player removal had completed early.

## Console warnings and errors

- The connected one-player server and client emitted their normal `[RobloxGraybox] Server bootstrap ready` and `[RobloxGraybox] Client bootstrap ready` messages.
- No warning or error caused by TCK-0002 was observed in the connected one-player session.
- Studio output contained two identical `Unable to assign property Text. string expected, got nil` errors from `cloud_13818914890.Plugin.StudioWidgets.LabeledTextInput` / `cloud_13818914890.Plugin.main`. They were plugin errors, not emitted by repository source.
- Server/client console output from the separate multiplayer test processes was not accessible through MCP and is therefore not claimed clean.
- In the completed human-observed multiplayer checkpoint, the TCK-0002 server warning count was zero and server error count was zero. Each client had zero TCK-0002 warnings and zero TCK-0002 errors.

## Result

The scoped TCK-0002 Studio checkpoint passed on exact commit `0fdd8ccfc5d6fcfe6c3fcc4cabab99f864c69025`. The earlier one-player observations plus the completed human-observed late-join and disconnect-isolation evidence support advancement only to `STUDIO_PASS`. They do not claim `HUMAN_APPROVED`, merge authority, geometry, safe-zone qualification, timers, death/void observation, respawn orchestration, client feedback, or a complete first playable.
