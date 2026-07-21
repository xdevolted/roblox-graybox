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
    throw "Git whitespace validation failed for unstaged changes with exit code $LASTEXITCODE."
}

& git diff --cached --check
if ($LASTEXITCODE -ne 0) {
    throw "Git whitespace validation failed for staged changes with exit code $LASTEXITCODE."
}

$trackedWhitespace = @(& git grep -n -I -E "[[:blank:]]+$" -- .)
$trackedWhitespaceExit = $LASTEXITCODE
if ($trackedWhitespaceExit -eq 0) {
    $trackedWhitespace | Write-Output
    throw "Tracked files contain trailing whitespace."
}
if ($trackedWhitespaceExit -ne 1) {
    throw "Tracked-file whitespace scan failed with exit code $trackedWhitespaceExit."
}

& (Join-Path $PSScriptRoot "Build.ps1")
