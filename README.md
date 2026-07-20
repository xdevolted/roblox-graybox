# Roblox Graybox

A small, local-first foundation for a server-authoritative Roblox gameplay prototype. The filesystem
and Git repository are the source of truth; Rojo synchronizes them with Roblox Studio.

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
.\scripts\Check-All.ps1
.\scripts\Serve.ps1
```

Open a baseplate in Roblox Studio, open the Rojo plugin, and connect to `localhost:34872` while the
serve command is running. Studio authentication and plugin connection are manual steps.

## Commands

| Command | Purpose |
| --- | --- |
| `.\scripts\Format.ps1` | Format project Luau files |
| `.\scripts\Format-Check.ps1` | Check formatting without changes |
| `.\scripts\Lint.ps1` | Run Selene |
| `.\scripts\Build.ps1` | Build `build/RobloxGraybox.rbxlx` |
| `.\scripts\Install-Packages.ps1` | Install Wally packages |
| `.\scripts\Sourcemap.ps1` | Generate `sourcemap.json` |
| `.\scripts\Check-All.ps1` | Run formatting, lint, build, and sourcemap checks |
| `.\scripts\Serve.ps1` | Start the Rojo development server |

## Branch flow

`main` is stable. `staging` is the integration branch and the initial working branch. Create feature
branches from `staging`, then merge completed slices back into `staging`.

## Layout and authority boundaries

- `src/server` maps only to `ServerScriptService`.
- `src/client` maps to `StarterPlayerScripts`.
- `src/shared` maps to `ReplicatedStorage`.
- `tests` and generated Wally development packages map to `ServerStorage`, not replicated storage.
- Add explicit `Packages` or `ServerPackages` mappings only when runtime or server dependencies are
  introduced; this baseline intentionally contains only the TestEZ development dependency.
