$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Initialize-ToolPath.ps1")

$typesPath = Join-Path $projectRoot "build\types\globalTypes.d.luau"
$sourcemapPath = Join-Path $projectRoot "build\sourcemap.json"

if (-not (Test-Path -LiteralPath $typesPath -PathType Leaf)) {
    throw "Roblox type definitions are missing. Run '.\scripts\Setup.ps1' before checks."
}

& (Join-Path $PSScriptRoot "Format-Check.ps1")
& (Join-Path $PSScriptRoot "Lint.ps1")
& (Join-Path $PSScriptRoot "Sourcemap.ps1")

& luau-lsp analyze --platform=roblox --definitions "@roblox=$typesPath" --sourcemap $sourcemapPath src
if ($LASTEXITCODE -ne 0) {
    throw "Luau analysis failed with exit code $LASTEXITCODE."
}

& (Join-Path $PSScriptRoot "Test.ps1")

& git diff --check
if ($LASTEXITCODE -ne 0) {
    throw "Git whitespace validation failed with exit code $LASTEXITCODE."
}

& (Join-Path $PSScriptRoot "Build.ps1")
