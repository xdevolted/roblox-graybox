param(
    [ValidatePattern("^[A-Za-z0-9][A-Za-z0-9_-]*$")]
    [string]$Place = "Main"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Initialize-ToolPath.ps1")
. (Join-Path $PSScriptRoot "Place-Projects.ps1")

$placeProject = Get-PlaceProject -Place $Place
& rojo serve $placeProject.ProjectPath
if ($LASTEXITCODE -ne 0) {
    throw "Rojo serve failed for place '$($placeProject.Name)' with exit code $LASTEXITCODE."
}
