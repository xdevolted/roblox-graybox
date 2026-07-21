# First playable open questions

Resolve these owner decisions before freezing `acceptance-tests.md` or implementing gameplay.

## 1. Multiplayer result ownership

When two to eight players share a server, is each player running an independent round, or is there one shared server round?

- Recommended for the first graybox: independent per-player rounds in the same arena. One player's success, death, timeout, disconnect, or reset does not end another player's round. This is easier to understand, supports solo play naturally, and avoids waiting on other players.
- Alternative: one shared round where any player's qualifying event determines or contributes to a group result. This requires explicit winner/failure and reset rules.

## 2. Safe-zone qualification

Does success happen immediately on entering the zone, or only after continuously remaining inside it for a dwell duration?

- Recommended for the first graybox: immediate server-confirmed success on entry. It matches “walk into it to win” and minimizes the first slice.
- Alternative: require a specified continuous dwell duration and define what happens when the player leaves early.

## 3. Late-join policy

For an independent per-player model, should a late joiner start their own round immediately? For a shared-round model, should they spectate/wait or join the current round?

- Recommended with independent rounds: spawn safely and start the late joiner's own round immediately without affecting existing players.
- Shared-round behavior cannot be finalized until question 1 is answered.
