$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Initialize-ToolPath.ps1")

rojo sourcemap default.project.json --output sourcemap.json

