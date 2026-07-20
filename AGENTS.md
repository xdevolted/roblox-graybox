# Permanent project rules

- The filesystem and Git repository are the source of truth.
- Use Rojo to synchronize scripts with Roblox Studio.
- This repository represents one Roblox game/experience and may contain multiple places.
- Keep one Git repository at the game root; never create a nested repository under `places`.
- Keep code shared by the game's places in root `src` and shared tests in root `tests`.
- Keep place-specific code and tests under `places/<PlaceName>`.
- Keep each place's canonical Rojo project at `places/<PlaceName>/<placename>.project.json`.
- Do not invent or record game IDs or place IDs.
- Only one agent may write to the active worktree at a time.
- Implement one small behavioral slice at a time.
- Avoid unrelated refactors.
- Shared gameplay state is server authoritative.
- Clients request actions but never decide damage, rewards, score, currency, inventory, cooldown completion, or objective completion.
- Validate client requests for type, range, ownership, context, permission, and frequency.
- Use session-only data during the initial prototype.
- Do not add persistence without explicit approval.
- Do not add a framework without a demonstrated need.
- Keep pure gameplay rules separate from Roblox Instance manipulation.
- Every gameplay feature must support reset and replay.
- Run `scripts/Checks.ps1` before Studio testing so every place is formatted, linted, built, and
  sourcemapped.
- Do not weaken tests to make an implementation pass.
- Agents may not publish production or change account permissions.
- Stop after three unsuccessful attempts at the same stage and report the problem.
