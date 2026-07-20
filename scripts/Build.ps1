param(
    [ValidatePattern("^[A-Za-z0-9][A-Za-z0-9_-]*$")]
    [string]$Place = "Main"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Initialize-ToolPath.ps1")
. (Join-Path $PSScriptRoot "Place-Projects.ps1")

$placeProject = Get-PlaceProject -Place $Place
New-Item -ItemType Directory -Force -Path $placeProject.OutputDirectory | Out-Null

$outputPath = Join-Path $placeProject.OutputDirectory "$($placeProject.Name).rbxlx"
& rojo build $placeProject.ProjectPath --output $outputPath
if ($LASTEXITCODE -ne 0) {
    throw "Rojo build failed for place '$($placeProject.Name)' with exit code $LASTEXITCODE."
}
