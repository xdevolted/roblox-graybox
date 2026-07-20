# Permanent project rules

- The filesystem and Git repository are the source of truth.
- Use Rojo to synchronize scripts with Roblox Studio.
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
- Run formatting, linting, tests, and a Rojo build before Studio testing.
- Do not weaken tests to make an implementation pass.
- Agents may not publish production or change account permissions.
- Stop after three unsuccessful attempts at the same stage and report the problem.

