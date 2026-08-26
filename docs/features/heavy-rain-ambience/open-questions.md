# Heavy rain ambience product decisions

All material heavy-rain ambience decisions were resolved and approved by the owner on 2026-08-25. No product decisions block planning.

## 1. Visual intensity

Use exactly two local rain emitters, each capped at 400 particles per second, with slightly staggered camera-relative volumes. This doubles the desktop particle budget while preserving one controller and one render listener. Studio quality settings may reduce the rendered count on lower-end clients.

## 2. Rain sound asset

Use Roblox Creator Store audio `Rain Effect` by `@Roblox`, asset `1516791621` (`rbxassetid://1516791621`), length 59 seconds.

## 3. Audio behavior

Play one continuous, nonspatial local rain loop at volume `0.35`. It starts once with the client presentation, does not restart on respawn/replay, and has no thunder, music ducking, distance falloff, or player volume control in this slice.

## 4. Failure behavior

If audio construction or playback fails, report at most one client warning and keep visual rain/gameplay running. Do not retry automatically during the session.
