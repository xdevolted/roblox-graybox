# Permanent project rules

## Purpose and ground truth

- This is a single-place graybox Roblox experience whose immediate goal is to prove that one core loop is understandable, fun, and replayable.
- The filesystem and Git are authoritative. Roblox Studio is a runtime and test target only; synchronize with Rojo.
- Use one worktree, one writing agent, one Studio instance, and one Rojo server unless the human explicitly authorizes more.

## Commands

- Initial setup: `.\scripts\Setup.ps1`
- Serve: `.\scripts\Serve.ps1`
- Build: `.\scripts\Build.ps1`
- Sourcemap: `.\scripts\Sourcemap.ps1`
- Tests: `.\scripts\Test.ps1`
- Complete pre-Studio gate: `.\scripts\Checks.ps1`

## Architecture

- Shared gameplay state and outcomes are server-authoritative. Clients request actions; they never decide damage, rewards, score, currency, inventory, cooldown completion, or objective completion.
- Validate client requests for type, range, ownership, context, permission, and frequency.
- Keep engine-free game rules in `src/shared/` so Lune can test them. Keep Instances and Roblox services in server/client adapters.
- Every gameplay system must clean up and support reset and replay.
- Use session-only state during the prototype. Do not add persistence, economy, a framework, or another place without explicit human approval and demonstrated need.
- A real second place triggers a deliberate multi-place migration. Share only code proven common, using explicit packages instead of mapping all server/client code into every place.

## Change discipline

- Work on one small behavioral slice on `feature/<short-name>` from `main`; keep `main` serveable.
- Read the approved specification, frozen acceptance scenarios, and slice plan before implementing.
- Do not weaken acceptance tests to make code pass. Avoid unrelated refactors and speculative abstractions.
- Run `Checks.ps1` before review, Studio testing, or merge. Record the exact commit used for Studio/playtest evidence.
- A reviewer independently re-derives expected behavior before reading the diff, writes findings by severity, never edits reviewed code, and performs at most one initial review plus one re-review.

## Attempt budgets

- Low-risk docs, tests, or isolated pure logic: three builder attempts.
- Medium-risk gameplay authority, remotes, replication, or lifecycle adapters: two attempts.
- High-risk persistence, economy, release security, or migrations: stop after one failed attempt and escalate.
- On budget exhaustion, stop with the failure, attempted approaches, diagnostics, and the human decision needed.

## Always / ask first / never

- Always preserve unrelated user changes, keep secrets out of the repository, and use frozen scenarios as the behavioral contract.
- Ask first before dependency upgrades, new libraries, cross-cutting refactors, persistence, economy, multi-place work, worktrees, or unattended Studio automation.
- Agents never publish production, run data migrations, modify monetization/economy, moderate players, change account permissions, force-push `main`, or rewrite shared history.
