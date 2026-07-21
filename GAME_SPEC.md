# Game specification

## Working title

Graybox Survival Platform

## Player fantasy

Stay alive on a small floating platform while moving to a clearly marked safe zone before the round timer expires.

## First-graybox experience

- Support one to eight players in one solid gray platform arena.
- Spawn players safely inside a guarded starting area instead of over the void.
- Show one glowing safe zone in a valid position elsewhere on the platform.
- Let Roblox character movement be the primary player action.
- End a round in success when the server confirms the safe-zone condition.
- End a round in failure when time expires, the character dies, or the character falls into the void.
- Show a countdown, success/failure result, and reset countdown using primitive debug feedback.
- After the result interval, respawn at the start, move the safe zone to a different valid position, reset the timer, and begin the next round automatically.
- Keep all state session-only and every outcome server-authoritative.

## Authority

The server owns round state, time expiration, zone qualification, success/failure, safe-zone selection, respawn/reset, and replay. Clients may provide ordinary character input and display replicated feedback; they may not report or decide outcomes. Any client attempt to request a result or state transition is ignored or rejected and cannot change authoritative state.

## Success criteria

- A solo player can complete multiple consecutive rounds without manual intervention.
- Falling, death, and timeout reliably produce failure rather than a stuck round.
- Each replay uses a valid safe-zone position different from the immediately previous round.
- Server/client cleanup prevents duplicate transitions or duplicate round starts.
- Studio observation later confirms spawn, physics, replication, visuals, and multiplayer behavior; headless tests cover only deterministic rules.

## Prototype constraints

- No persistence, economy, monetization, publishing automation, final UI/art, large content systems, second place, or framework.
- Later iterations may add simple obstacles without changing the core move-to-safety loop.
- Multiplayer result ownership and the exact safe-zone qualification rule must be approved before acceptance scenarios are frozen.
