# Heavy rain ambience slice plan

## Status and dependency gate

**Plan status:** Approved by the owner on 2026-08-25.

The frozen HRA-01 through HRA-08 scenarios are the behavioral contract. The slice depends on TCK-0007's current camera-following rain controller. TCK-0007 must complete independent review, corrected Studio validation, human approval, and merge to `main` before this slice receives a ticket or implementation branch. Implementation then begins on `feature/tck-0008-heavy-rain-ambience` from that authoritative merged `main`; it may not be added as a third TCK-0007 attempt.

No engine-free gameplay, server, networking, or multiplayer-state slice is needed. Heavy rain and audio are client-local presentation only.

## Slice 1 — Two-layer rain and local ambience

### Behavior

- Keep one singleton rain controller and one `RenderStepped` connection per client.
- Replace the controller's single combined visual-effect factory seam with an indexed rain-layer factory called exactly twice during successful startup.
- Each production layer owns one invisible nonphysical box-volume Part and one downward ParticleEmitter. Both layers use the TCK-0007 visible-streak defaults, a rate of 400 particles per second, and different fixed camera-relative horizontal/vertical offsets so their emission volumes overlap without occupying the same origin.
- Apply each finite camera-relative update to both layers. Missing, malformed, NaN, or infinite view positions move neither layer and do not create retries or warnings.
- After both layers construct successfully, create one nonspatial `Sound` under `SoundService` with `SoundId = "rbxassetid://1516791621"`, `Looped = true`, `Volume = 0.35`, and start playback once.
- If either visual layer fails to construct, invalidate startup, destroy every layer already created, create no sound or render listener, report one warning, and retain the existing stoppable singleton failure guard.
- If sound construction or `Play()` fails, destroy any partial sound, report one warning, and continue running both visual layers and the render listener. Do not retry audio automatically.
- Repeated `start()` returns the active controller without another layer, sound, playback call, listener, or warning.
- Character replacement and replicated round changes remain outside the dependency surface, so respawn/replay neither restarts sound nor stacks presentation.
- `stop()` invalidates first, disconnects the one render listener, stops/destroys the sound if present, destroys both layers, and clears the singleton. Repeated stop is harmless; retained callbacks are inert; restart creates exactly one clean presentation.

### Production objects and ownership

| Object | Count | Ownership and defaults |
| --- | ---: | --- |
| Invisible rain-volume Part | 2 | Client runtime only; anchored, transparent, nonphysical, nonqueryable, no shadow; each layer uses a distinct stable name and offset. |
| ParticleEmitter | 2 | One per volume; 400 rate, zero initial speed, global downward acceleration, visible camera-upright streak appearance, and existing lifetime/color/fade defaults. |
| Sound | 1 | Client runtime only under `SoundService`; name `GrayboxRainAmbience`, asset `1516791621`, looped, volume `0.35`, nonspatial, played once. |
| Render connection | 1 | Owned by the singleton controller; positions both visual layers only. |

The sound asset is the owner-approved Roblox Creator Store `Rain Effect` by `@Roblox`. No model, script, package, or Creator Store dependency is inserted; only the approved audio content ID is assigned to a locally created `Sound`.

### Controller seams

`RainController.start(dependencies?)` keeps only narrow fakeable presentation dependencies:

- world parent;
- sound parent;
- RenderStepped-like signal;
- indexed layer factory returning `setPosition(position)` and `destroy()`;
- sound factory returning `destroy()` after successful one-time playback;
- target-position reader;
- finite-position predicate; and
- warning reporter.

Production defaults resolve `Workspace`, `SoundService`, `RunService.RenderStepped`, current-camera position, Roblox Instances, and `warn`. No Player, Character, Humanoid, remote, server controller, round attribute, Lighting mutation, result, reward, or input dependency is allowed. These seams must not become a weather framework, generalized effects manager, generalized audio manager, or service container.

### Exact implementation boundary

| File | Planned responsibility |
| --- | --- |
| `src/client/Prototype/RainController.luau` | Own exactly two visual layers and one optional successfully created sound; construct, position, isolate audio failure, and clean up deterministically. |
| `tests/Prototype/RainController.spec.luau` | Revise the fake environment and deterministic matrix for two-layer counts, partial construction rollback, one-time sound, audio failure isolation, cleanup, and authority isolation. |

`Bootstrap.client.luau` already starts the controller and is prohibited from changing. No server/shared gameplay code, existing acceptance scenario, configuration, dependency, project mapping, build artifact, or other controller may change. Workflow records may add TCK-0008, its builder-attempt record, independent review, and Studio checkpoint only at their respective gates.

### Deterministic test matrix

| ID | Test |
| --- | --- |
| HRC-01 | First start constructs indexed layers 1 and 2, constructs/plays one sound, positions both layers immediately, and connects one render listener. |
| HRC-02 | Repeated start returns the same controller without another layer, sound, play call, position read, listener, or warning. |
| HRC-03 | Each render callback applies the same new valid target to both existing layers without recreating presentation. |
| HRC-04 | Missing, malformed, NaN, and infinite targets move neither layer; a later valid target resumes both with no retry/warning loop. |
| HRC-05 | Layer-1 construction failure creates no sound/listener; layer-2 failure destroys layer 1 before returning the guarded failed controller; each reports once and repeated start does not retry. |
| HRC-06 | Sound construction/playback failure reports once, destroys any partial sound, keeps both rain layers active, positions both, and never retries during updates or repeated start. |
| HRC-07 | Character replacement and simulated active/result/reset/replay state changes add no object, listener, playback, position update, or gameplay mutation. |
| HRC-08 | Stop invalidates first, disconnects once, stops/destroys one successful sound, destroys both layers exactly once, and is idempotent. |
| HRC-09 | Retained callbacks after stop are inert; restart creates exactly two fresh layers, one fresh sound/playback, and one fresh listener. |
| HRC-10 | Two sequentially isolated simulated client contexts share no layer, sound, position, playback, warning, or cleanup state. |
| HRC-11 | The production/injected dependency surface contains no Player writer, remote, server controller, Character, Humanoid, Lighting writer, objective, result, reward, timer, or round-transition path. |

The unchanged existing deterministic suite remains green. Headless tests prove orchestration through fakes; they cannot prove audio availability, audible looping/seams, perceived volume, visible density, particle rendering, client quality throttling, cue readability, or frame rate.

### Frozen-scenario coverage and Studio evidence

After the complete gate and independent review pass, use one exact clean commit and record all client/server warnings and errors plus:

| Scenario | Required observation |
| --- | --- |
| HRA-01 | Join once; confirm exactly two local volume/emitter pairs and visibly denser rain than the merged TCK-0007 single-layer baseline. |
| HRA-02 | Confirm exactly one `GrayboxRainAmbience` plays asset `1516791621`, loops continuously, is nonspatial, and is comfortable at volume `0.35`. |
| HRA-03 | Die/fall, respawn, and replay; confirm the same two layers and one uninterrupted sound remain without audible overlap or restart. |
| HRA-04 | Complete active, success, failure, result, and reset phases; confirm safe zone, edges, HUD, countdown, results, movement, health, and authority remain unchanged/readable. |
| HRA-05 | Deterministic fakes prove malformed/inaccessible audio isolation. If practical, temporarily deny/replace the asset only in a scoped Studio run and confirm visuals/gameplay continue with at most one warning; do not persist that change. |
| HRA-06 | Join a second client late; confirm each client owns two layers and one sound locally and neither player's lifecycle/presentation changes because of the other. |
| HRA-07 | Stop play with zero cleanup errors; explicit stop/restart and retained callbacks remain deterministic evidence. |
| HRA-08 | Repeat movement and consecutive rounds at low and high Editor Quality Level; record density, readability, audio comfort/seams, warnings/errors, and noticeable frame-rate impact. |

### Authority, risk, and exclusions

The slice remains client presentation only and introduces no authority boundary or request validation because there is no request surface. Audio/particles cannot report contacts, derive results, or change game state.

Risk is **medium** because the slice expands a frame-driven Roblox lifecycle adapter, adds partial-construction rollback, and introduces audio availability/performance behavior that headless tests cannot prove. It touches neither authority-sensitive gameplay, persistence, nor economy. The builder receives **two complete-gate attempts**; a second failure stops work with diagnostics and an owner decision instead of scope expansion.

Thunder, lightning, random/synchronized weather, rain gameplay, shelter/occlusion, puddles/splashes, wet materials, camera changes, audio effects/mixing, settings UI, remotes, server/shared changes, dependencies, frameworks, publishing, persistence, economy, monetization, another place, and unattended Studio automation remain excluded.

### Exit and rollback

Implementation exit requires HRC-01 through HRC-11 plus the unchanged suite, one passing full `Checks.ps1` gate within budget, independent review with no unresolved blocker, and owner Studio approval of HRA-01 through HRA-08 from the exact reviewed commit.

Rollback is a normal revert of the future TCK-0008 implementation commit, restoring the merged single-layer rain controller. Stop cleanup owns all local runtime Parts, emitters, sound, and listener; there is no saved Studio object, server state, data, dependency, permission, migration, or irreversible effect.

The owner approved this plan on 2026-08-25. Implementation remains gated on TCK-0007 completing review, corrected Studio validation, human approval, and merge to `main`.
