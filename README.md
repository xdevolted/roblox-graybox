# Roblox Graybox

A local-first, multi-place-ready foundation for a server-authoritative Roblox gameplay prototype.
This repository represents one game/experience. The filesystem and Git repository are the source
of truth, and Rojo synchronizes each place with Roblox Studio.

## Prerequisites

- Roblox Studio
- Git
- Rokit
- PowerShell 5.1 or newer

GitHub CLI is installed for future remote setup, but authentication is not required for local work.

## First use

```powershell
rokit install
.\scripts\Install-Packages.ps1
.\scripts\Checks.ps1
.\scripts\Serve.ps1
```

Open a baseplate in Roblox Studio, open the Rojo plugin, and connect to `localhost:34872` while the
Main serve command is running. Studio authentication and plugin connection are manual steps.

## Place commands

`Main` is the initial place. Commands that accept `-Place` resolve the canonical project at
`places\<PlaceName>\<placename>.project.json` and write generated files beneath
`build\<PlaceName>`.

| Command | Purpose |
| --- | --- |
| `.\scripts\Serve-Place.ps1 -Place Main` | Start the Main Rojo development server |
| `.\scripts\Serve.ps1` | Compatibility wrapper that serves Main |
| `.\scripts\Build.ps1 -Place Main` | Build `build\Main\Main.rbxlx` |
| `.\scripts\Sourcemap.ps1 -Place Main` | Generate `build\Main\sourcemap.json` |
| `.\scripts\Checks.ps1` | Format-check and lint source, then discover, build, and sourcemap every place |
| `.\scripts\Check-All.ps1` | Compatibility wrapper for `Checks.ps1` |
| `.\scripts\Format.ps1` | Format shared and place-specific Luau files |
| `.\scripts\Format-Check.ps1` | Check formatting without changing files |
| `.\scripts\Lint.ps1` | Run Selene across shared and place-specific source |
| `.\scripts\Install-Packages.ps1` | Install Wally packages |

## Layout and authority boundaries

- `src/client`, `src/server`, and `src/shared` contain code shared across this game's places.
- `tests` contains tests shared across places.
- `places/<PlaceName>/src` and `places/<PlaceName>/tests` contain place-specific code and tests.
- `places/Main/main.project.json` is the canonical Main Rojo configuration.
- Root and place-specific server code maps only to `ServerScriptService`.
- Root and place-specific client code maps only to `StarterPlayerScripts`.
- Root and place-specific shared code maps to `ReplicatedStorage`.
- Tests and generated Wally development packages map to `ServerStorage`, not replicated storage.
- Add explicit `Packages` or `ServerPackages` mappings only when runtime or server dependencies are
  introduced; this baseline intentionally contains only the TestEZ development dependency.

Add another place by creating its source and test directories plus exactly one lowercase-named Rojo
project file under `places/<PlaceName>`. Do not create a nested Git repository or add Roblox game or
place IDs to scaffold a local place.

## Branch flow

`main` is stable. `staging` is the integration branch and the initial working branch. Create feature
branches from `staging`, then merge completed slices back into `staging`.
