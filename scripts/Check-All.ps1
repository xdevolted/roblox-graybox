$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "Format-Check.ps1")
& (Join-Path $PSScriptRoot "Lint.ps1")
& (Join-Path $PSScriptRoot "Build.ps1")
& (Join-Path $PSScriptRoot "Sourcemap.ps1")

