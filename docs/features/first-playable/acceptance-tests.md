# First playable acceptance scenarios

**Status:** Draft; NOT FROZEN until the owner resolves `open-questions.md` and approves this file.

## FP-01 — Safe spawn and automatic start

**Given** an eligible player enters the session with no active character round

**When** the first round is prepared

**Then** the server spawns the character at the guarded start, selects a valid safe-zone position, and starts one authoritative timer without duplicate round initialization.

## FP-02 — Safe-zone success

**Given** an active round and a living player who has not already received a result

**When** the server confirms the approved safe-zone qualification rule

**Then** the first accepted terminal result is success and later terminal events for that round cannot replace it.

## FP-03 — Timeout failure

**Given** an active round with no accepted terminal result

**When** the authoritative round timer expires before safe-zone qualification

**Then** the first accepted terminal result is failure due to timeout.

## FP-04 — Death or void failure

**Given** an active round with no accepted terminal result

**When** the server observes character death or a fall below the configured void boundary

**Then** the first accepted terminal result is failure and duplicate death/fall signals do not create another result transition.

## FP-05 — Reset and automatic replay

**Given** a completed round showing its immutable result

**When** the result interval and reset sequence finish

**Then** prior-round state is cleared, the character returns to the start, the safe zone uses a different valid position, the timer resets, and exactly one next round starts with a greater generation.

## FP-06 — Invalid or forged result request

**Given** any client and any lifecycle state

**When** the client attempts to declare success, failure, timeout, reset, or a round generation

**Then** the server rejects or ignores the request, records no authoritative mutation, and derives outcomes only from server-observed state.

## FP-07 — Duplicate and stale lifecycle events

**Given** a lifecycle event already accepted for a round generation

**When** the same event is repeated or an event arrives for an older generation

**Then** the model rejects it without changing state, result, or generation.

## FP-08 — Disconnect cleanup

**Given** a player participating in an active or completed round

**When** that player disconnects

**Then** server adapters remove player/character listeners and state without duplicate transitions or a stuck lifecycle; any effect on other players follows the approved multiplayer result model.

## FP-09 — Late join

**Given** a round is already active when another eligible player joins

**When** the server initializes the late joiner

**Then** their spawn and round participation follow the approved late-join policy without changing an existing result or starting a duplicate round.

## FP-10 — Consecutive replay stability

**Given** the player completes one success round and one failure round in either order

**When** each automatic reset completes

**Then** both following rounds start cleanly with no carried result, duplicate bootstrap, stale timer, or reused immediately previous safe-zone position.
