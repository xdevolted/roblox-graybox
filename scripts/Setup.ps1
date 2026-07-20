$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Initialize-ToolPath.ps1")

$trustedTools = @(
    "rojo-rbx/rojo",
    "UpliftGames/wally",
    "JohnnyMorganz/StyLua",
    "Kampfkarren/selene",
    "JohnnyMorganz/luau-lsp",
    "lune-org/lune"
)

& rokit trust $trustedTools
if ($LASTEXITCODE -ne 0) {
    throw "Rokit could not record the explicit tool trust list."
}

& rokit install
if ($LASTEXITCODE -ne 0) {
    throw "Rokit tool installation failed with exit code $LASTEXITCODE."
}

# Rokit may create its bin directory during installation, after the initial PATH setup.
. (Join-Path $PSScriptRoot "Initialize-ToolPath.ps1")

& wally install
if ($LASTEXITCODE -ne 0) {
    throw "Wally package installation failed with exit code $LASTEXITCODE."
}

$typesDirectory = Join-Path (Join-Path $projectRoot "build") "types"
$typesPath = Join-Path $typesDirectory "globalTypes.d.luau"
$downloadPath = "$typesPath.download"
$typesUrl = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.68.0/scripts/globalTypes.d.luau"
$expectedHash = "66c27c8ee220ee480d6794089c8a721956d34fe3bddc877cbf603f4bea6d4c75"

New-Item -ItemType Directory -Force -Path $typesDirectory | Out-Null

$hasValidTypes = $false
if (Test-Path -LiteralPath $typesPath -PathType Leaf) {
    $actualHash = (Get-FileHash -LiteralPath $typesPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $hasValidTypes = $actualHash -eq $expectedHash
}

if (-not $hasValidTypes) {
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $typesUrl -OutFile $downloadPath
        $downloadHash = (Get-FileHash -LiteralPath $downloadPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($downloadHash -ne $expectedHash) {
            throw "Roblox type definition hash mismatch. Expected $expectedHash but received $downloadHash."
        }

        Move-Item -Force -LiteralPath $downloadPath -Destination $typesPath
    }
    finally {
        if (Test-Path -LiteralPath $downloadPath) {
            Remove-Item -Force -LiteralPath $downloadPath
        }
    }
}

Write-Output "Setup complete. Roblox definitions: $typesPath"
