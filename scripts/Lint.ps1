$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Initialize-ToolPath.ps1")

selene src tests

