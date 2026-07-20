$rokitBin = Join-Path $env:USERPROFILE ".rokit\bin"
$wingetLinks = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links"

foreach ($toolDirectory in @($rokitBin, $wingetLinks)) {
    if ((Test-Path -LiteralPath $toolDirectory) -and (($env:Path -split ";") -notcontains $toolDirectory)) {
        $env:Path = "$toolDirectory;$env:Path"
    }
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location -LiteralPath $projectRoot

