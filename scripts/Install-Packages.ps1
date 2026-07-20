$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Initialize-ToolPath.ps1")

wally install

foreach ($packageDirectoryName in @("Packages", "ServerPackages", "DevPackages")) {
    $packageDirectory = Join-Path $projectRoot $packageDirectoryName
    New-Item -ItemType Directory -Force -Path $packageDirectory | Out-Null
}

