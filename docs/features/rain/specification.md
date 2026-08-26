# Cosmetic rain specification

**Status:** Approved by the owner on 2026-08-25; acceptance scenarios frozen.

## Player-facing behavior

Rain falls continuously throughout the playable session and is visibly recognizable while the player moves around the floating platform. The effect surrounds the local player's view closely enough that crossing the arena does not leave the rainfall behind. It begins automatically for a joining player and continues across character death, respawn, round result, reset, and replay without stacking duplicate effects.

Rain is presentation only. It does not damage players, change movement or visibility rules, affect the safe zone, influence round outcomes, create currency or rewards, or alter any server-authoritative gameplay state. The existing countdown, objective, success/failure, and replay behavior remain unchanged.

## States and events

| State | Entry | Event | Result |
| --- | --- | --- | --- |
| `STOPPED` | Client presentation has not started or has been cleaned up | `START` | Create one local rain presentation and enter `RUNNING` |
| `RUNNING` | One local rain presentation is active | Character respawn or round transition | Keep the same presentation running without duplication |
| `RUNNING` | One local rain presentation is active | Repeated `START` | Return the existing presentation without duplication |
| `RUNNING` | Client presentation shuts down | `STOP` | Remove owned rain objects/connections and enter `STOPPED` |
| `STOPPED` | No local rain presentation exists | Repeated `STOP` | No-op |

The rain presentation may reposition its local emitter volume to remain near the current view. Repositioning changes presentation only and cannot submit gameplay events.

## Authority and validation

- The server remains authoritative over all existing round state and outcomes.
- The client may create, position, render, and clean up its own cosmetic rain effect.
- Rain exposes no RemoteEvent or RemoteFunction and makes no request for damage, rewards, score, currency, inventory, cooldowns, objective completion, round completion, or reset.
- The client does not write authoritative Player attributes or infer a gameplay result from rain state.
- Any local update input used to position the rain must be finite and derived from the current local camera or character context. Missing camera/character state must fail safely without creating duplicate effects or mutating gameplay.

## Reset, replay, and lifecycle guarantees

- Exactly one rain controller and one owned rain presentation exist per client while running.
- Character replacement and automatic round replay do not create another controller or another rain presentation.
- A late joiner starts one local rain presentation without changing any existing player's presentation or gameplay state.
- Cleanup disconnects owned listeners and destroys owned temporary presentation objects.
- Retained callbacks after cleanup are inert, and a later restart creates one clean presentation.

## Non-goals

- Rain damage, slippery movement, flooding, lightning hazards, altered jump physics, or any other gameplay mechanic.
- Server-synchronized weather phases, random storms, weather voting, admin controls, or persistence.
- Puddles, wet-surface materials, shelter/occlusion detection, indoor filtering, splashes, mist simulation, or final visual art direction.
- Thunder, rain audio, music changes, camera shake, post-processing that obscures the objective, or changes to the existing debug HUD.
- New dependencies, frameworks, remotes, server gameplay modules, economy, monetization, another place, publishing, or unattended Studio automation.

## Constraints

- Use Roblox-native presentation primitives already available to the client; no dependency or project-map change is needed.
- Keep the effect legible but subordinate to the safe zone, platform edges, countdown, and result feedback.
- The deterministic boundary covers controller idempotence, lifecycle cleanup, and authority isolation. Actual density, visibility, motion, and performance require human Studio observation.
