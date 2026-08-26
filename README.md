# Roblox Graybox

A local-first, single-place foundation for proving a server-authoritative Roblox gameplay loop before investing in production systems. Git and the filesystem are authoritative; Rojo synchronizes scripts into Studio.

## Prerequisites

- Roblox Studio with the Rojo plugin and built-in MCP server
- Git
- Rokit 1.2.0
- PowerShell 5.1 or newer

## First use

```powershell
.\scripts\Setup.ps1
.\scripts\Checks.ps1
.\scripts\Serve.ps1
```

Open a baseplate in Studio and connect the Rojo plugin to `localhost:34872`. Studio authentication, MCP connection, playtesting, and publishing remain human-controlled.

## Commands

| Command | Purpose |
| --- | --- |
| `.\scripts\Setup.ps1` | Install pinned tools/packages and prepare pinned Roblox analyzer definitions |
| `.\scripts\Serve.ps1` | Serve `default.project.json` on port 34872 |
| `.\scripts\Build.ps1` | Build `build\RobloxGraybox.rbxlx` |
| `.\scripts\Sourcemap.ps1` | Generate `build\sourcemap.json` |
| `.\scripts\Test.ps1` | Run deterministic engine-free Lune specifications |
| `.\scripts\Checks.ps1` | Run formatting, lint, strict analysis, tests, whitespace validation, and build |
| `.\scripts\Format.ps1` | Format Luau source and tests |

## Roblox Studio AXI smoke test

The reusable `roblox-studio-axi` package is consumed through its linked executable. Build the local place, enable Studio's built-in MCP server, then validate or run the project-owned smoke test:

```powershell
.\scripts\Build.ps1
roblox-studio-axi test validate tests/playtests/baseline/smoke.yaml
roblox-studio-axi test run tests/playtests/baseline/smoke.yaml
roblox-studio-axi test validate tests/playtests/features/player-round-adapter.yaml
roblox-studio-axi test run tests/playtests/features/player-round-adapter.yaml
```

Project identity and safety policy live in `.axi/config.toml`; the shared AXI contains no graybox-specific logic. Evidence is written under the ignored `.artifacts/playtests/` directory. The smoke test verifies only generic startup health, player readiness, a viewport capture, no new immediate console errors, and cleanup. The feature playtest derives its initial replicated attribute expectations from `tests/GameLoop/PlayerRoundAdapter.spec.luau`. These automated checks do not replace the frozen gameplay acceptance scenarios or human fun/comprehension evaluation.

## Layout

- `src/shared`: engine-free rules and types where practical.
- `src/server`: authoritative server adapters and bootstrap.
- `src/client`: input and temporary client feedback.
- `tests`: repo-owned Lune runner and `*.spec.luau` suites.
- `docs/features`: approved behavior, frozen scenarios, plans, and open questions.
- `docs/tickets`: durable workflow state.
- `.codex/skills`: repo-local specification, planning, implementation, checking, and review procedures.
- `build`: ignored generated places, sourcemaps, and downloaded type definitions.

The root `default.project.json` is the only Rojo project. Introduce a multi-place layout only when a second real place is required, and share proven common code through explicit packages.

## Studio-authored content and place safety

The current graybox arena is constructed at runtime, and Rojo maps only the scripts under `src/`. Do not rely on an unsaved or unpublished Studio-only instance as durable project state. Before adding a hand-built map, terrain, lighting, UI hierarchy, or other authored content, choose and document its source of truth: a Rojo-mapped filesystem asset, a versioned Roblox package/asset with explicit ownership and recovery, or an intentionally authoritative place.

When this project targets a stable Roblox place, add its ID to `servePlaceIds` in `default.project.json` so Rojo refuses to synchronize into the wrong place. Keep production publishing human-controlled.

## Feature flow

1. Convert the idea into a specification and acceptance scenarios; resolve material questions and freeze the scenarios.
2. Plan small behavioral slices, starting with engine-free rules and tests.
3. Implement one slice on `feature/<short-name>` and run `Checks.ps1`.
4. Run an independent review; the builder fixes valid findings within the risk budget.
5. Test the exact clean commit in Studio, then have the human judge comprehension and fun.
6. Merge to `main` only when deterministic gates pass and blockers are resolved.

See `docs/WORKFLOW.md` for ticket states, evidence, playtest protocol, and later-stage triggers.
