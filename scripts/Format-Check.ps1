$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Initialize-ToolPath.ps1")

stylua --check src tests

