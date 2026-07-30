# TCK-0006 Studio checkpoint - passed with recorded Studio/plugin limitations

## Scope and exact state

- Date: 2026-07-30.
- Pull request: `#19`.
- Checkpoint entry state: `CODE_REVIEW_PASS`; the completed record supports the
  durable ticket transition to `STUDIO_PASS`.
- Exact workflow head: `829c21dcddab55e90f0e576d8d2c6a307d6298fb`.
- Resumed owner-assisted checkpoint head:
  `b8416af1c12d7b78f45827be60bff104f1765c7a`; this commit changed only the
  partial checkpoint record and retained the exact reviewed runtime source.
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
- Result: pass with recorded Studio/plugin infrastructure limitations. The
  single-player presentation checkpoint, required FP-09 late join and independent
  presentation, and separate FP-08 active/result removal observations all passed.
- Ticket consequence: this record supports `CODE_REVIEW_PASS -> STUDIO_PASS` only.
  It does not support `HUMAN_APPROVED`, merge, publishing, or a first-playable
  stopping-gate decision.

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

## Owner-assisted late-join and isolation evidence

The owner started one local server and Player 1, waited for visible active play, and
then started Player 2 late without restarting the server or Player 1. All three runtime
processes shared play-test session
`DC1EF9E5-B5BD-42CF-A457-D5CAD5CFF2A6`:

- server PID `33088`, created at `04:25:49`;
- Player 1 client PID `1504`, created at `04:26:14`;
- Player 2 client PID `29900`, created at `04:26:30`.

Player 2 therefore joined the already-running server approximately 16 seconds after
Player 1. Studio runtime command execution through the connected MCP remained
unavailable for these server/client processes, so the owner used read-only Command Bar
snapshots in each exact runtime process. No source, Instance, attribute, or place was
edited by the evidence scripts.

At `04:28:05`, the server directly observed:

- Player 1 (`UserId = -1`) active at generation `5`, deadline
  `1785410889.919637`;
- Player 2 (`UserId = -2`) resetting at generation `4`, deadline
  `1785410886.096154`;
- Player 1's `Objective_2`, slot `2`, at `(0, 0.75, -30)`;
- Player 2's `Objective_3`, slot `3`, at `(30, 0.75, -30)`.

At `04:28:25`, Player 1 directly observed exactly one persistent HUD with
`ROUND 6 / REACH YOUR GLOWING ZONE / TIME 8`, active generation `6`, deadline
`1785410913.008739`, default `WalkSpeed = 16`, default `JumpPower = 50`, and
`CameraType = Custom`. Player 1 saw owned `Objective_4` with local transparency `0`
and Player 2's `Objective_3` with local transparency `1`.

At `04:28:39`, Player 2 directly observed exactly one persistent HUD with
`ROUND 6 / REACH YOUR GLOWING ZONE / TIME 10`, active generation `6`, deadline
`1785410929.135075`, default `WalkSpeed = 16`, default `JumpPower = 50`, and
`CameraType = Custom`. Player 2 saw owned `Objective_5` with local transparency `0`
and Player 1's `Objective_6` with local transparency `1`.

The different deadlines and independently advancing generations show that late joining
did not copy or synchronize the two authoritative lifecycles. Each client independently
classified the same replicated objective set by its own local UserId and retained
exactly one owner-visible objective.

For the opposing-state observation, one watcher was armed in the server and one in each
client. The server watcher intentionally targeted Player 1; it was not expected to
produce a second server line for Player 2. At `04:41:56`, Player 1 entered its own
objective with normal controls. All three runtimes captured the same authoritative
instant:

- Player 1 was generation `44`, `RESULT/SUCCESS`, deadline
  `1785411718.538608`;
- Player 2 remained generation `46`, `ACTIVE`, deadline
  `1785411727.510027`;
- Player 1's client retained one HUD showing `SUCCESS / NEXT ROUND IN 2`;
- Player 2's client retained one HUD showing
  `ROUND 46 / REACH YOUR GLOWING ZONE / TIME 11`.

The owner explicitly confirmed that each HUD was readable and singular, each client
saw only its own objective, and normal movement, jump, and camera behavior worked on
both clients. This is direct FP-09 late-join, owner-association, default-control,
duplicate-bootstrap, and independent-presentation evidence.

At `04:30`-`04:31`, explicit server and per-client log-history captures each contained
the same one warning and four errors:

- warning: `Plugin loaded`;
- two errors: `Unable to load plugin icon. Image may have an invalid or unknown
  format.`;
- error: `Unable to load plugin icon: rbxassetid://132203619`;
- error: `Unable to load plugin icon: rbxassetid://7014624400`.

Every message is Studio/plugin infrastructure output. No message names Graybox source,
the feedback mapper/controller, GUI construction, attribute observation, objective
binding, bootstrap, Character handling, cleanup, or gameplay authority.

### First active-removal observation — cleanup passed, preservation inconclusive

At `04:48:18` and `04:48:20`, the server and Player 1 client respectively armed an
active-removal watcher. The pre-removal snapshots showed:

- Player 1 active at generation `61`, deadline `1785412108.3585`, with exactly one HUD
  showing `ROUND 61 / REACH YOUR GLOWING ZONE / TIME 8` and owned `Objective_6`,
  slot `6`, locally visible;
- Player 2 active at generation `64`, deadline `1785412105.506884`, with owned
  `Objective_2`, slot `2`, locally hidden from Player 1.

Player 2 disconnected at `04:48:31`. Both server and Player 1 then observed Player 2
and Player 2's objective absent. Player 1 still had exactly one HUD and exactly one
locally visible owned objective, with no cleanup error or duplicate presentation.

This is direct supporting evidence for removed-player and objective cleanup, but it is
not counted as the required surviving-player preservation pass. Player 1's recorded
deadline expired during the approximately 13-second interval between arming and
disconnect, so Player 1 naturally completed reset/replay at the same time: the
post-removal state was clean active generation `62`, deadline `1785412131.406501`,
with `Objective_7`, slot `7`, and one HUD showing a normal fresh `TIME 20`. Because
that legitimate lifecycle transition changed the generation, deadline, HUD text, and
objective position during the observation window, this run cannot isolate removal as
the cause of no change. It is neither treated as a product failure nor promoted to an
FP-08 pass; an event-time observation is required.

### FP-08 removal during `ACTIVE` — pass

An event-time watcher was then armed in the same server and Player 1 client. A new late
client joined as Player 3 (`UserId = -3`). At `04:52:01`, Player 3 was intentionally
disconnected while directly recorded as `ACTIVE`, generation `2`, deadline
`1785412327.133032`.

Immediately before and after removal, both server and Player 1 recorded Player 1 with
the exact same values:

- `ACTIVE`, generation `71`, deadline `1785412338.898204`, and no result;
- owned `Objective_8`, slot `8`;
- on Player 1, objective local transparency `0`, exactly one HUD, and unchanged text
  `ROUND 71 / REACH YOUR GLOWING ZONE / TIME 17`.

The server's pre-removal snapshot also contained Player 3's owned `Objective_5`, slot
`5`; its post-removal snapshot contained only Player 1 and Player 1's objective. The
client snapshot after replication likewise contained only the locally visible Player 1
objective. The server snapshots were approximately `0.012` seconds apart and the
client snapshots approximately `0.001` seconds apart, eliminating the earlier
deadline-overlap ambiguity. No Player 1 phase, generation, deadline, result, objective,
HUD, or countdown value changed. This is the required direct active-removal
preservation and removed-objective cleanup pass.

### FP-08 removal during `RESULT` — pass

In a separate local server session, Player 2 (`UserId = -2`) was intentionally removed
through a scoped server checkpoint kick while directly recorded as `RESULT/FAILURE`
with reason `TIMEOUT`, generation `14`, and deadline `1785413147.013699`.

The matching server event-time snapshots, recovered from the exact runtime's local
Studio log, showed Player 1 unchanged immediately before and after removal:

- `RESULT/FAILURE/TIMEOUT`, generation `14`, deadline `1785413146.679801`;
- owned `Objective_4`, slot `4`;
- the pre-removal objective set additionally contained Player 2's `Objective_5`,
  slot `5`, while the post-removal set contained only Player 1's objective.

Player 1's client independently captured the exact same phase, generation, result,
reason, deadline, objective identity, slot, local transparency `0`, HUD count `1`, and
text `FAILURE - TIMEOUT / NEXT ROUND IN 1` before and after removal. Its snapshots
were approximately `0.001` seconds apart; the server snapshots were approximately
`0.015` seconds apart.

Before removal, Player 2 had directly shown one HUD with clear
`FAILURE - TIMEOUT / NEXT ROUND IN 2`. Its explicit warning/error history contained
only the previously classified one plugin-loaded warning and four plugin-icon errors.
The post-kick client log contained only the expected network disconnect plus a Studio
`PlayTestKickDialog` plugin warning. No Graybox, mapper, controller, GUI, attribute,
objective, bootstrap, Character, retained-callback, or cleanup error appeared.

An earlier kick safety check correctly skipped because it was armed at the end of an
already-running result interval; it removed no player and changed no runtime state. A
later replacement-client kick was unnecessary extra evidence and is not used as the
basis for this pass.

## Frozen-scenario status

| Scenario | Current checkpoint status |
| --- | --- |
| FP-01 | Pass for scoped presentation: one readable HUD, active countdown, one owned objective, default Humanoid/camera behavior, and hands-on normal-control reachability were observed. |
| FP-02 | Pass for runtime presentation: normal-control contact produced one clear immutable success result. |
| FP-03 | Pass for runtime presentation: countdown decreased and only server replication produced timeout/result/reset/replay. |
| FP-04 | Pass for runtime presentation: separate death and void reasons produced clear distinct text with one result interval. |
| FP-05 | Pass for runtime presentation: result, reset, new objective position, and greater-generation replay remained clean. |
| FP-06 | Pass for direct runtime surface: no non-default outcome/timer/reset/generation remote existed and the client used no authoritative writer. |
| FP-07 | Pass with evidence boundary: no older result was replaced or retained; forced partial-order and retained-callback behavior remains deterministic-only evidence. |
| FP-08 | Pass: opposing-state independence plus separate event-time removals during active and result preserved the remaining client's exact lifecycle, HUD, countdown/result, and objective association while cleaning the removed player and objective without a Graybox error. |
| FP-09 | Pass: Player 2 joined the already-running server late; both clients showed exactly one independent HUD/countdown and only their own objective, and one result left the other client active and unchanged. |
| FP-10 | Pass for runtime presentation in both result orderings, with clean greater-generation replay, objective movement, one readable HUD, and no stale text. |

## Final multiplayer shutdown and checkpoint conclusion

The final owner-assisted server/client session used play-test session GUID
`ADAA5B0D-ED39-497B-9D9E-59D6EECC08D2`. After the owner stopped testing:

- no `RobloxStudioBeta.exe` process remained for that exact session GUID;
- the server exited normally with return value `0`;
- the surviving client removed all players, closed Script Context, cleared its
  DataModel, and completed normal shutdown;
- the deliberately removed clients recorded the expected network/kick disconnect and
  closed without a Graybox presentation or cleanup error;
- no source, test, configuration, frozen acceptance test, place Instance, saved place,
  publication, or external asset changed.

Explicit runtime `LogService` captures on the server and each client consistently
reported one `Plugin loaded` warning and four plugin-icon loading errors. Shutdown log
tails additionally contained Studio plugin-relay, kick-dialog, graphics, and UI-thread
diagnostics. All were emitted by Studio/plugin infrastructure. No warning or error
named or originated from Graybox Bootstrap, `PrimitiveFeedbackModel`,
`DebugHudController`, GUI construction, replicated attribute handling, objective
binding, Character handling, duplicate bootstrap, listener cleanup, or gameplay
authority.

The exact checkpoint result is **PASS WITH RECORDED STUDIO/PLUGIN INFRASTRUCTURE
LIMITATIONS**.

- FP-01 through FP-10 have the exact scoped Slice 6 presentation evidence recorded
  above, including the mandatory direct FP-09 late join.
- Headless tests remain the evidence for forced partial-attribute permutations,
  retained callbacks, exact listener accounting, and stop idempotence; this Studio
  checkpoint does not reclassify them as rendering evidence.
- Human observation, not headless testing, established HUD/objective visibility,
  readability, comprehension, normal-control playability, two-client perception, and
  late-join presentation.
- No additional builder attempt was consumed. TCK-0006 remains truthfully at
  attempts `3/2` under the explicit owner exception.
- TCK-0002 remains unchanged at its historical attempts `7/2`; it did not expand
  TCK-0006 scope.
- No final UI/art, audio, animation, persistence, economy, publishing, external
  playtesting, production release, additional mechanic, or later workflow state was
  added or inferred.
- The next gate is explicit owner review and approval of this Studio result before
  `HUMAN_APPROVED`. This record does not authorize merge or claim that the
  first-playable stopping gate has passed.
