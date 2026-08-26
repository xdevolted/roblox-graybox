# Heavy rain ambience acceptance scenarios

**Status:** FROZEN by the owner on 2026-08-25 with audio asset `1516791621`. Implementations and reviews must not weaken these scenarios.

## HRA-01 — Heavy rain starts automatically

**Given** a player joins and local client presentation initializes

**When** the playable arena becomes visible

**Then** exactly two local rain layers are active and their combined rainfall is visibly denser than the prior single-layer presentation.

## HRA-02 — Rain ambience plays once

**Given** a valid approved rain-audio asset is configured

**When** the local heavy-rain presentation starts

**Then** exactly one nonspatial rain sound plays continuously at the approved volume without requiring player input.

## HRA-03 — Respawn and replay do not stack ambience

**Given** exactly two rain layers and one rain sound are active

**When** the character dies or falls, respawns, and an automatic round replay begins

**Then** the same local ambience presentation continues without another emitter, sound, render listener, audible overlap, or sound restart.

## HRA-04 — Gameplay remains readable and authoritative

**Given** heavy rain and its sound are active during any round phase

**When** the player locates the safe zone, moves, reads the HUD, or receives a result

**Then** required cues remain readable, existing behavior is unchanged, and the ambience makes no gameplay request or authoritative mutation.

## HRA-05 — Audio failure is isolated

**Given** the configured audio is missing, malformed, inaccessible, or fails to play

**When** the heavy-rain presentation starts

**Then** visual rain and gameplay continue, one local warning may be reported, and no unbounded retry, duplicate sound, or gameplay mutation occurs.

## HRA-06 — Late join is isolated

**Given** existing players already have independent rounds and local ambience

**When** another player joins late

**Then** the late joiner starts exactly two local rain layers and one local sound without changing any existing player's presentation or round lifecycle.

## HRA-07 — Cleanup and restart

**Given** the heavy-rain presentation is running

**When** its controller stops and later starts again

**Then** stop destroys both rain layers, stops/destroys the sound, disconnects the listener, and makes retained callbacks inert; restart creates exactly one clean complete presentation.

## HRA-08 — Readability and performance

**Given** heavy rain is active at both low and high Studio quality settings

**When** the player crosses the platform and completes consecutive rounds

**Then** rain remains visibly heavy, audio remains comfortable, gameplay cues remain readable, and no unacceptable frame-rate degradation or client warning/error appears.
