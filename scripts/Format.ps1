$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Initialize-ToolPath.ps1")

& stylua src tests places
if ($LASTEXITCODE -ne 0) {
    throw "StyLua formatting failed with exit code $LASTEXITCODE."
}
