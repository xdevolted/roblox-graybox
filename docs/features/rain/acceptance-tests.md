# Cosmetic rain acceptance scenarios

**Status:** FROZEN by the owner on 2026-08-25. Implementations and reviews must not weaken these scenarios.

## RAIN-01 — Rain starts automatically

**Given** a player joins the experience and local client presentation initializes

**When** the playable arena becomes visible

**Then** recognizable rain is falling around the player's view without requiring input and exactly one local rain presentation is active.

## RAIN-02 — Rain follows arena movement

**Given** the local rain presentation is active

**When** the player crosses between distant points of the floating platform using normal controls

**Then** rainfall remains visible around the player's view and does not remain stranded at the starting position.

## RAIN-03 — Cosmetic-only authority boundary

**Given** rain is active during any round phase

**When** rain updates, particles contact geometry, or the local presentation is started or stopped

**Then** no server-authoritative round state, result, timer, objective, health, movement, reward, inventory, or player attribute is requested or changed by the rain system.

## RAIN-04 — Respawn and replay do not duplicate rain

**Given** exactly one local rain presentation is active

**When** the character dies or falls, respawns, and an automatic round replay begins

**Then** rain remains available with no visible interruption requirement, no stacked duplicate presentation, and no extra controller or update listener.

## RAIN-05 — Existing gameplay remains readable

**Given** rain is active during an ordinary round

**When** the player locates the safe zone, reads the countdown, crosses platform edges, and receives success or failure feedback

**Then** the rain does not obscure those primitive gameplay cues or change their existing behavior.

## RAIN-06 — Late join is isolated

**Given** one or more players are already running independent rounds

**When** another player joins late

**Then** the late joiner's client starts exactly one local rain presentation and no existing player's presentation or authoritative round lifecycle changes.

## RAIN-07 — Cleanup and restart

**Given** the local rain presentation is running

**When** its controller stops and is later started again

**Then** owned temporary objects and listeners are removed on stop, retained callbacks are inert, repeated stop is harmless, and restart creates exactly one clean rain presentation.

## RAIN-08 — Missing local view state fails safely

**Given** the client temporarily has no current camera or usable character context

**When** the rain presentation receives an update

**Then** it performs no invalid positioning or gameplay mutation, emits no unbounded error loop, and resumes one rain presentation when valid local view state returns.
