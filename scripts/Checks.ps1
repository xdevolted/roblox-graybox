$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Initialize-ToolPath.ps1")
. (Join-Path $PSScriptRoot "Place-Projects.ps1")

& (Join-Path $PSScriptRoot "Format-Check.ps1")
& (Join-Path $PSScriptRoot "Lint.ps1")

$placeProjects = @(Get-PlaceProjects)
foreach ($placeProject in $placeProjects) {
    & (Join-Path $PSScriptRoot "Build.ps1") -Place $placeProject.Name
    & (Join-Path $PSScriptRoot "Sourcemap.ps1") -Place $placeProject.Name
}
