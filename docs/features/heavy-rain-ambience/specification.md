# Heavy rain ambience specification

**Status:** Approved by the owner on 2026-08-25 with audio asset `1516791621`; acceptance scenarios frozen.

## Player-facing behavior

The existing continuous cosmetic rainfall becomes visibly heavier through two overlapping local rain layers. Together they create clearly denser coverage than the current single-emitter presentation while the player crosses the floating platform. A continuous rain ambience loop begins with the local weather presentation and remains audible across character death, respawn, round result, reset, and replay.

The visual and audio presentation remains cosmetic only. It does not damage players, change movement, obscure required gameplay cues, affect objectives or outcomes, or mutate server-authoritative state. A failure to load or play the audio must not prevent visual rain or gameplay from continuing.

## States and events

| State | Entry | Event | Result |
| --- | --- | --- | --- |
| `STOPPED` | Heavy-rain presentation has not started or was cleaned up | `START` | Create two visual rain layers and one local looping sound, then enter `RUNNING` |
| `RUNNING` | One complete local ambience presentation is active | Character respawn or round transition | Keep the same layers and sound without duplication or restart |
| `RUNNING` | One complete local ambience presentation is active | Repeated `START` | Return the active controller without duplicating particles, sound, or listeners |
| `RUNNING` | Presentation shuts down | `STOP` | Stop/destroy the sound, destroy both visual layers, disconnect owned listeners, and enter `STOPPED` |
| `STOPPED` | No ambience presentation is active | Repeated `STOP` | No-op |

Both visual layers remain camera-relative. The sound is local, nonspatial ambience at a conservative fixed volume and does not follow or attach to a Character.

## Authority and validation

- The server remains authoritative over all gameplay and round outcomes.
- The client may render, position, play, stop, and clean up its own cosmetic rain presentation.
- There is no weather remote, client result request, Player attribute writer, damage path, movement path, reward path, or round-transition path.
- Camera-relative positions must be finite before either visual layer moves.
- The configured sound ID must be a nonempty `rbxassetid://<positive integer>` value approved for use in this experience. Missing, malformed, inaccessible, or failed audio must fail locally without an error loop, duplicate retries, or visual/gameplay mutation.
- Repeated start/stop, respawn, reset, replay, and late join must preserve exactly one local ambience controller per client.

## Reset, replay, and lifecycle guarantees

- Exactly two owned rain emitters and one owned rain sound exist per running client.
- Respawn and automatic replay do not recreate or stack emitters, sounds, or render listeners.
- A late joiner starts one isolated local ambience presentation without changing existing players or shared state.
- Stop invalidates callbacks first, disconnects listeners, stops the sound, and destroys all owned runtime objects.
- Retained callbacks after stop are inert; restart creates one clean complete presentation.

## Non-goals

- Thunder, lightning, randomized storms, dry periods, weather synchronization, weather controls, or volume settings UI.
- Rain damage, slipping, flooding, wet materials, puddles, surface splashes, shelter detection, camera shake, or gameplay visibility rules.
- Music changes, dynamic audio mixing/ducking, spatial occlusion, indoor filtering, multiple sound loops, or final audio mastering.
- Server/shared gameplay changes, remotes, dependencies, frameworks, persistence, economy, monetization, publishing, another place, or unattended Studio automation.

## Constraints

- Reuse the existing client rain controller and Roblox-native presentation objects; do not add a generalized weather or audio framework.
- The safe zone, platform edges, HUD, countdown, and results must remain readable under the heavier effect.
- Deterministic tests cover counts, lifecycle, audio failure isolation, authority isolation, and cleanup. Studio observation must establish perceived heaviness, audio playback/volume, readability, warnings/errors, and performance at low and high quality settings.
