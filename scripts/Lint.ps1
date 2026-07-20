$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Initialize-ToolPath.ps1")

& selene src tests
if ($LASTEXITCODE -ne 0) {
    throw "Selene lint failed with exit code $LASTEXITCODE."
}
