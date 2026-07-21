# Core loop

1. **Prepare:** Spawn the player at the guarded start, choose a valid safe-zone position different from the previous round, and reset session-only round data.
2. **Act:** Begin the round timer. The player uses normal character movement to reach the glowing safe zone while avoiding the void.
3. **Resolve:** The server declares success after the approved safe-zone qualification rule, or failure on timeout, death, or falling into the void. Duplicate or late terminal events cannot change the first result.
4. **Feedback:** Replicate the countdown and a clear success/failure result for primitive client/debug presentation.
5. **Reset:** After a brief result interval, clean up the prior round, respawn at the start, reposition the safe zone, reset the timer, and automatically replay from step 1.

The server owns every state transition and outcome. Headless rules model lifecycle events without Roblox objects; later adapters observe Roblox movement, character, time, and zone state.
