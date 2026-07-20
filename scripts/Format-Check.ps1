$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Initialize-ToolPath.ps1")

& stylua --check src tests places
if ($LASTEXITCODE -ne 0) {
    throw "StyLua format check failed with exit code $LASTEXITCODE."
}
