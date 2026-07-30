# TCK-0006 Studio checkpoint - incomplete pending owner-assisted multiplayer

## Scope and exact state

- Date: 2026-07-30.
- Pull request: `#19`.
- Ticket entry and current state: `CODE_REVIEW_PASS`.
- Exact workflow head: `829c21dcddab55e90f0e576d8d2c6a307d6298fb`.
- Exact reviewed runtime/test commit:
  `b2481b316891bac0de021ac2fe0f3681d50ae87c`.
- Studio place:
  `build/RobloxGraybox.rbxlx`, local file with `PlaceId = 0`.
- Exact place artifact last-write time:
  `2026-07-30T09:31:03.9704945Z`.
- Primary exact-place Studio process: PID `33576`.
- Studio MCP connection:
  `f1f12b01-3d72-499b-8bfe-c36150c536d5`.
- Rojo: version `7.6.1`, listener PID `3292` on `127.0.0.1:34872`;
  wrapper PID `16356`.
- Result: incomplete. The single-player presentation checkpoint ran and passed the
  observations recorded below. Required two-client FP-08/FP-09 evidence and
  owner-visible readability/normal-control judgment remain pending.
- Ticket consequence: none yet. This partial record does not support `STUDIO_PASS`.

The worktree, tracking branch, and PR head were clean and synchronized before Studio.
PR #19 was open, non-draft, based on `main`, and cleanly mergeable. Exact-head
pull-request CI run `30531242679` and push CI run `30531239254` passed. CodeRabbit
reported no actionable finding on the corrected runtime, and the ticket truthfully
recorded the owner-authorized exceptional attempt count as `3/2`.

## Edit-mode mapping

The first connected Studio window was rejected as stale because it still contained the
203-byte placeholder controller and no `PrimitiveFeedbackModel`. No evidence below
comes from that window.

The exact built place was opened in a new Studio process and selected explicitly. Its
edit-mode `Workspace` contained only `Terrain` and `Camera`. No arena, checkpoint
object, or other saved runtime state existed.

Exactly four client source containers were mapped:

1. `StarterPlayerScripts.Client.Bootstrap` (`LocalScript`)
2. `StarterPlayerScripts.Client.Prototype.DebugHudController` (`ModuleScript`)
3. `StarterPlayerScripts.Client.Prototype.InputController` (`ModuleScript`)
4. `StarterPlayerScripts.Client.Prototype.PrimitiveFeedbackModel` (`ModuleScript`)

Direct source inspection in Studio confirmed the reviewed controller's visible-output
cache and owner-attribute binding and the mapper's named active/result/reset windows.

## Single-player direct observations

The local player was `TheUnleshedBeast`, UserId `115613823`.

### Initial active presentation and default controls

- One `GrayboxDebugHud` and one `RoundStatus` TextLabel existed.
- The label was visible with absolute size `520 x 112` and active-tone color
  approximately `(1, 0.9412, 0.4706)`.
- The initial captured text was:
  `ROUND 1 / REACH YOUR GLOWING ZONE / TIME 3`.
- The player was `ACTIVE`, generation `1`, with a finite server-time deadline.
- Exactly one objective existed for the local UserId. It was `Objective_8`, slot `8`,
  position `(30, 0.75, 30)`, with `LocalTransparencyModifier = 0`.
- The current Character had a Humanoid with default `WalkSpeed = 16` and
  `JumpPower = 50`.
- `Workspace.CurrentCamera.CameraType` was `Custom` with a Humanoid subject.
- No custom movement, input, or camera system was present.

These observations establish the mapped default-control configuration and one clear
owner association. They do not substitute for the owner's visual readability,
comprehension, or hands-on playability judgment.

### Success, result interval, reset, and replay

The current Character was moved onto its server-owned objective as a checkpoint action.
The client recorder observed:

- generation `3`, objective slot `2`, one HUD, active countdown;
- `SUCCESS / NEXT ROUND IN 2`, then `1`, then `0`;
- a distinct `RESETTING / ROUND STARTS IN 1`;
- the same player's objective moved from slot `2` to slot `3`;
- exactly one clean generation `4` active view with `TIME 20`;
- the prior success/reset text disappeared and the HUD count remained one.

Later contacts did not replace the accepted generation-three result.

### Timeout, result interval, reset, and replay

The authoritative generation-four deadline was allowed to expire without objective
contact. The client recorder observed:

- active `TIME 3`, `2`, and `1`;
- server-replicated `FAILURE - TIMEOUT / NEXT ROUND IN 2`, then `1`, then `0`;
- a distinct reset countdown;
- the objective moved from slot `3` to slot `4`;
- exactly one clean generation `5` active view with `TIME 20`;
- no carried timeout/result/reset text and one HUD throughout.

No client attribute writer, outcome remote, or local transition action was used. The
server runtime contained no non-default RemoteEvent or RemoteFunction; only Roblox's
default chat remotes were present.

### Death and void reasons

In separate active generations, the server:

- set the current Humanoid health to zero; the client showed
  `FAILURE - DEATH / NEXT ROUND IN 2`, then `1`;
- moved the current Character below the configured void boundary; the client showed
  `FAILURE - FELL / NEXT ROUND IN 2`, then `1`, while the replicated reason was
  `VOID`.

Each run retained one HUD and one immutable result interval.

### Character replacement and persistent HUD

Before replacement, the HUD had `ResetOnSpawn = false` and exactly one instance existed.
The server replaced the Character during active play and again after an accepted
result. Direct client identity checks confirmed:

- the exact same HUD Instance survived;
- the HUD count stayed one;
- `ResetOnSpawn` remained false;
- a current Character existed afterward;
- replay produced clean active generation text rather than a duplicate message.

### Consecutive result ordering and replay cleanliness

The earlier generation-three success followed by generation-four timeout provided the
success-then-failure ordering.

A controlled failure-then-success sequence then observed:

- generation `15`, objective slot `6`, active countdown through `3`, `2`, `1`;
- immutable `FAILURE - TIMEOUT / NEXT ROUND IN 2`, then `1`;
- reset with objective slot `6 -> 7`;
- exactly one generation `16` active `TIME 20`;
- immediate server-confirmed success for generation `16`;
- `SUCCESS / NEXT ROUND IN 2`, `1`, and `0`;
- reset with objective slot `7 -> 8`;
- exactly one clean generation `17` active `TIME 20`, then `19`, `18`;
- one HUD throughout and no prior result, reason, reset, countdown, or bootstrap text.

This also directly showed a resetting countdown reaching `0` without a client-authored
transition; only the later server-replicated generation changed the view.

### Duplicate and stale activity

Fifty repeated checkpoint contacts were issued while one result/reset sequence was in
progress. The accepted generation remained immutable. The contact loop extended one
iteration into the next genuinely active generation and therefore produced a valid new
success there; it did not replace or append to the older generation's result. This
stress run is recorded as supporting evidence, not as the sole FP-07 observation.
Deterministic retained-callback and partial-attribute permutation coverage remains
headless evidence and is not reclassified as Studio rendering evidence.

## Console and shutdown evidence

Immediately before stopping:

- client: one HUD, one locally visible owned objective, `0` errors;
- server: one player, no non-default remotes, `0` errors;
- client and server each reported one warning with exact text `Plugin loaded`;
- no warning or error referred to Graybox source, mapping, bootstrap, UI construction,
  objective binding, lifecycle, cleanup, or retained callbacks.

The `Plugin loaded` warning is Studio/plugin infrastructure output, not a Graybox
runtime warning. Play mode stopped normally. Studio returned to Edit mode, and the
repository worktree remained clean. No test recorder, Instance, source edit, saved-place
change, publication, or external asset survived the run.

## Frozen-scenario status

| Scenario | Current checkpoint status |
| --- | --- |
| FP-01 | Partial pass: one HUD, active countdown, one owned objective, default Humanoid/camera settings observed. Owner must still judge prompt visibility, comprehension, and hands-on normal-control reachability. |
| FP-02 | Pass for runtime presentation: server-confirmed contact produced one clear immutable success result. Owner visual judgment remains pending. |
| FP-03 | Pass for runtime presentation: countdown decreased and only server replication produced timeout/result/reset/replay. Owner visual judgment remains pending. |
| FP-04 | Pass for runtime presentation: separate death and void reasons produced clear distinct text with one result interval. |
| FP-05 | Pass for runtime presentation: result, reset, new objective position, and greater-generation replay remained clean. |
| FP-06 | Pass for direct runtime surface: no non-default outcome/timer/reset/generation remote existed and the client used no authoritative writer. |
| FP-07 | Pass with evidence boundary: no older result was replaced or retained; forced partial-order and retained-callback behavior remains deterministic-only evidence. |
| FP-08 | Pending: requires two clients and removal once during active and once during result/reset while observing the remaining client. |
| FP-09 | Pending and mandatory: requires Player 1 active before Player 2 joins the same running local server, with per-client HUD/objective/deadline evidence. |
| FP-10 | Pass for runtime presentation in both result orderings, with clean greater-generation replay, objective movement, and one HUD. Owner visual judgment remains pending. |

## Required owner-assisted completion

Use the exact reviewed source and the normal Studio **Server & Clients** workflow:

1. In the exact-place Studio process, start one local Server with Player 1 only.
2. Wait until Player 1 visibly shows one active HUD and one owner objective.
3. Record Player 1's local UserId, phase, generation, deadline, HUD text, objective
   owner, slot, position, and local visibility.
4. Add Player 2 to the already-running server. Do not restart the server or Player 1.
5. On both clients, record the same fields and confirm each sees only its own objective,
   has exactly one HUD, and keeps an independent countdown.
6. Resolve one player's round while the other remains active. Confirm the other
   client's phase, result, HUD, deadline, and objective association do not change.
7. Remove Player 2 once during an active round and record Player 1 preservation.
8. In a separate run, remove Player 2 during result/reset and again record Player 1
   preservation plus the removed client's absence of late presentation errors.
9. On each client, reset/replace the Character during active and after a result; confirm
   the same single persistent HUD and one owner-visible objective remain.
10. With normal controls only, confirm movement, camera, and jump reach the objective;
    judge whether the objective and active/result/reset text are visible and
    understandable without prompting.
11. Stop the session and record explicit Server, Client 1, and Client 2 warning/error
    counts and every infrastructure limitation.

Only after those observations pass truthfully may this record be completed and
TCK-0006 advance from `CODE_REVIEW_PASS` to `STUDIO_PASS`. No human approval, merge,
publishing, production release, external playtesting, or first-playable stopping-gate
decision is implied.
