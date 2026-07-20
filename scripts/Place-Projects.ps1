function Get-PlaceProject {
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern("^[A-Za-z0-9][A-Za-z0-9_-]*$")]
        [string]$Place
    )

    $placesDirectory = Join-Path $projectRoot "places"
    $placeDirectory = Get-ChildItem -LiteralPath $placesDirectory -Directory | Where-Object {
        $_.Name -eq $Place
    }

    if ($null -eq $placeDirectory) {
        throw "Unknown place '$Place'. Expected a directory under '$placesDirectory'."
    }

    $expectedProjectName = "$($placeDirectory.Name.ToLowerInvariant()).project.json"
    $projectFiles = @(Get-ChildItem -LiteralPath $placeDirectory.FullName -File -Filter "*.project.json")

    if ($projectFiles.Count -ne 1 -or $projectFiles[0].Name -cne $expectedProjectName) {
        throw "Place '$($placeDirectory.Name)' must contain exactly one project named '$expectedProjectName'."
    }

    return [PSCustomObject]@{
        Name            = $placeDirectory.Name
        ProjectPath     = $projectFiles[0].FullName
        OutputDirectory = Join-Path (Join-Path $projectRoot "build") $placeDirectory.Name
    }
}

function Get-PlaceProjects {
    $placesDirectory = Join-Path $projectRoot "places"

    if (-not (Test-Path -LiteralPath $placesDirectory -PathType Container)) {
        throw "Places directory does not exist: $placesDirectory"
    }

    $placeDirectories = @(Get-ChildItem -LiteralPath $placesDirectory -Directory | Sort-Object Name)
    if ($placeDirectories.Count -eq 0) {
        throw "No place directories were found under '$placesDirectory'."
    }

    foreach ($placeDirectory in $placeDirectories) {
        Get-PlaceProject -Place $placeDirectory.Name
    }
}
