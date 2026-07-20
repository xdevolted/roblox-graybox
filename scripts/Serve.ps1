$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Initialize-ToolPath.ps1")

$projectPath = Join-Path $projectRoot "default.project.json"
& rojo serve $projectPath
if ($LASTEXITCODE -ne 0) {
    throw "Rojo serve failed with exit code $LASTEXITCODE."
}
