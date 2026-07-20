$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Initialize-ToolPath.ps1")

$buildDirectory = Join-Path $projectRoot "build"
New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null
rojo build default.project.json --output (Join-Path $buildDirectory "RobloxGraybox.rbxlx")

