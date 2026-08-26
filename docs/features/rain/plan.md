# Cosmetic rain slice plan

## Status and contract

**Plan status:** Approved by the owner on 2026-08-25.

The frozen scenarios in `acceptance-tests.md` are the behavioral contract. Rain is continuous, client-local presentation only. It follows the local view, survives character and round transitions without duplication, cleans up deterministically, and never participates in authoritative gameplay.

No engine-free gameplay rule or server slice is needed because rain has no shared state, outcome, timing phase, or client request. The smallest complete behavior is one isolated client-presentation slice.

## Slice 1 — Client-local cosmetic rain

### Behavior

- Start exactly one rain controller from the existing client bootstrap.
- Create one invisible, nonphysical emitter volume in `Workspace` and one `ParticleEmitter` owned by that controller.
- Render continuous, cool-blue/white, fast downward particles from a box volume centered 28 studs above the current local camera position.
- Move the volume on `RenderStepped` so the rain remains near the local view while the player crosses the 96-by-96 platform.
- If `Workspace.CurrentCamera` or a finite camera position is temporarily unavailable, skip that update without moving to an invalid position, creating another effect, or warning every frame. Resume on the next valid update.
- Treat repeated `start()` as idempotent and return the active controller.
- On `stop()`, invalidate the controller first, disconnect its one render listener, destroy its owned effect, and clear the singleton. Repeated stop is a no-op; retained callbacks are inert; a later start creates one fresh effect.
- Do not subscribe to `Character`, round attributes, safe-zone objects, or gameplay lifecycle. Character respawn and round replay therefore do not recreate or stack rain.
- If initial effect construction fails, report one client warning, create no render listener, and retain a stoppable singleton guard so bootstrap cannot retry or warn unboundedly.

### Default Roblox presentation

The production effect factory creates these runtime-only objects; no object is saved manually in Studio:

| Object/property | Planned value |
| --- | --- |
| `Part.Name` | `GrayboxRainVolume` |
| `Part.Size` | `Vector3.new(64, 1, 64)` |
| Physical properties | `Anchored = true`, `Transparency = 1`, `CanCollide = false`, `CanTouch = false`, `CanQuery = false`, `CastShadow = false` |
| `ParticleEmitter.Name` | `GrayboxRainEmitter` |
| Texture | Roblox-bundled `rbxasset://textures/particles/sparkles_main.dds` |
| Shape | Box volume, outward emission |
| Direction/spread | Bottom, at most 5 degrees on each horizontal axis |
| Rate | 650 particles per second |
| Speed | 55–70 studs per second |
| Lifetime | 1.1–1.4 seconds |
| Size | Constant 0.09 studs |
| Color | Cool pale blue-white |
| Transparency | 0.15 at birth fading to 0.55 at death |
| Lighting | `LightInfluence = 0`, modest `LightEmission` so rain remains visible without changing world lighting |

These values are conservative graybox defaults, not final art. The emitter volume spans two-thirds of the platform width and follows the camera, while particle travel covers the 28-stud vertical offset. Human Studio observation, not headless tests, decides whether the result reads as rain, keeps the objective/platform/HUD legible, and performs acceptably.

### Controller seam

Add `RainController.start(dependencies?)`. Production defaults use `Workspace`, `RunService.RenderStepped`, the current camera, Roblox Instances, and `warn`. Tests may inject only:

- the world parent;
- a RenderStepped-like signal;
- an effect factory returning `setPosition(position)` and `destroy()`;
- a target-position reader;
- a finite-position predicate; and
- a warning reporter.

The seam exists only to test lifecycle and authority isolation without Roblox engine objects. It must not become a framework, service container, generalized effects system, weather state machine, or networking abstraction.

### Exact implementation boundary

| File | Planned responsibility |
| --- | --- |
| `src/client/Prototype/RainController.luau` | Singleton lifecycle, camera-relative positioning, default Part/ParticleEmitter construction, guarded missing-view behavior, warning, and cleanup. |
| `src/client/Bootstrap.client.luau` | Require the rain controller and call `start()` once beside existing client presentation startup. |
| `tests/Prototype/RainController.spec.luau` | Engine-free deterministic controller tests with narrow fakes. |

No existing controller, server/shared gameplay module, frozen scenario, dependency, configuration, project map, or build artifact is planned to change.

### Deterministic test matrix

| ID | Test |
| --- | --- |
| RC-01 | First start creates exactly one effect, performs one immediate valid position update, and connects exactly one render listener. |
| RC-02 | Repeated start returns the active controller without another effect, update, listener, or warning. |
| RC-03 | Successive render callbacks apply each new valid target position to the same effect. |
| RC-04 | Missing, malformed, NaN, or infinite target positions are skipped without mutation, duplication, gameplay calls, or repeated warnings; a later valid position resumes updates. |
| RC-05 | Character replacement and simulated round-state changes create no connection, effect, restart, or gameplay mutation because the controller owns no such dependency. |
| RC-06 | Stop invalidates first, disconnects the single listener, destroys the effect exactly once, and is idempotent. |
| RC-07 | A retained render callback after stop is inert, and a later start creates exactly one clean controller/effect/listener. |
| RC-08 | Effect-construction failure reports once, creates no render listener, repeated start does not retry, and stop permits one later clean retry. |
| RC-09 | Two separately isolated simulated client module contexts each own one local effect and share no state or positioning. |
| RC-10 | The production/injected dependency surface contains no Player writer, remote, server controller, health, Humanoid, objective, reward, timer, result, or round-transition path. |

The existing deterministic suite must remain green. Lune proves controller behavior through fakes; it cannot prove actual particles, camera rendering, texture appearance, frame-rate cost, visibility, or readability.

### Frozen-scenario coverage and Studio evidence

After the complete static gate passes and independent review has no unresolved blocker, the owner runs Studio from one exact commit and records server/client warnings and errors plus these observations:

| Scenario | Required observation |
| --- | --- |
| RAIN-01 | Join once and confirm recognizable rain appears automatically with one `GrayboxRainVolume` and one `GrayboxRainEmitter`. |
| RAIN-02 | Cross between distant platform points and confirm rain remains around the view instead of staying at spawn. |
| RAIN-03 | Inspect the mapped runtime/network surface and verify rain owns no remote or Player attribute writer; observe that health, movement, timer, objective, result, and replay remain server-owned and unchanged. |
| RAIN-04 | Die/fall, respawn, and complete automatic replay; confirm the same single rain presentation remains and no duplicate emitter or render-driven warning appears. |
| RAIN-05 | During active, success, failure, result, and reset phases, confirm the safe zone, platform edges, HUD text, and results remain readable and behaviorally unchanged. |
| RAIN-06 | Start one client, then join with a second client; confirm each sees local rain, each client has exactly one local presentation, and neither player's round lifecycle changes because of the other. |
| RAIN-07 | Deterministic tests prove explicit stop/restart and retained-callback cleanup; stopping play mode must show no cleanup warnings or errors. |
| RAIN-08 | Replace/reset the current camera in Studio if practical and confirm rain resumes without duplicates or an error loop; malformed/NaN/infinite permutations remain deterministic-only evidence. |

Record whether the chosen density reads as rain, obscures any cue, or causes noticeable frame-rate degradation. Visual quality and performance remain human judgments and cannot be promoted from static evidence.

### Authority and exclusions

- Client-only presentation is authorized to create, position, render, and destroy its own local runtime objects.
- It may not write Player attributes, invoke remotes, change Lighting, move the camera or character, touch Humanoid state, inspect/declare objective contact, or derive any result.
- No rain gameplay, damage, slip, flood, shelter, lightning, thunder, audio, splash, puddle, wet material, post-processing, random weather, server synchronization, admin control, persistence, economy, monetization, analytics, publishing, second place, framework, dependency, or unattended Studio work is included.

### Risk and attempt budget

Risk is **medium** because the slice adds a frame-driven Roblox client lifecycle adapter with runtime Instance cleanup and visual/performance behavior that headless tests cannot prove. It is not authority-sensitive and touches neither persistence nor economy.

The builder receives **two complete-gate attempts**. A failed attempt includes an implementation followed by `Checks.ps1` that does not pass. After a second failed attempt, implementation stops with the exact failures, diagnostics, approaches tried, and owner decision needed; scope does not expand to compensate.

### Exit, review, and rollback

Implementation exit requires:

1. RC-01 through RC-10 and the unchanged existing deterministic suite pass.
2. The full `Checks.ps1` pre-Studio gate passes within the two-attempt budget.
3. An independent reviewer re-derives RAIN-01 through RAIN-08 and reports no unresolved blocker.
4. The owner completes the scoped Studio observations from the exact reviewed commit and approves rain readability and performance.

Rollback is a normal revert of the future implementation commit. Removing `RainController`, its test, and its one bootstrap call restores the current client with no saved Studio objects, server state, persistent data, dependency, configuration, or migration to clean up.

The owner approved this plan on 2026-08-25. Implementation may begin once the required `feature/<slice>` Git branch can be created from authoritative `main`.
