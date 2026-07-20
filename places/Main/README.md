# Main place

`main.project.json` is the canonical Rojo configuration for the Main place. It preserves legacy
script emission for Studio compatibility and serves on `localhost:34872`.

Place-specific code belongs in this directory:

- `src/client` maps to `StarterPlayerScripts.MainClient`.
- `src/server` maps to `ServerScriptService.MainServer`.
- `src/shared` maps to `ReplicatedStorage.MainShared`.
- `tests` maps to `ServerStorage.MainTests`.

Code shared with other places remains in the repository-root `src`; shared tests remain in root
`tests`. Do not create a nested Git repository or record game/place IDs here.

From the repository root, use:

```powershell
.\scripts\Serve-Place.ps1 -Place Main
.\scripts\Build.ps1 -Place Main
.\scripts\Sourcemap.ps1 -Place Main
.\scripts\Checks.ps1
```
