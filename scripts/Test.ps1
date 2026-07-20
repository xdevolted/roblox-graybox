$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Initialize-ToolPath.ps1")

& lune run (Join-Path $projectRoot "tests\run.luau")
if ($LASTEXITCODE -ne 0) {
    throw "Lune tests failed with exit code $LASTEXITCODE."
}
