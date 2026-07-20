$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Initialize-ToolPath.ps1")

& stylua src tests
if ($LASTEXITCODE -ne 0) {
    throw "StyLua formatting failed with exit code $LASTEXITCODE."
}
