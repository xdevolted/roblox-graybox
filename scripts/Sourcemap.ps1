$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Initialize-ToolPath.ps1")

$outputDirectory = Join-Path $projectRoot "build"
$projectPath = Join-Path $projectRoot "default.project.json"
$outputPath = Join-Path $outputDirectory "sourcemap.json"

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
& rojo sourcemap $projectPath --output $outputPath
if ($LASTEXITCODE -ne 0) {
    throw "Rojo sourcemap failed with exit code $LASTEXITCODE."
}
