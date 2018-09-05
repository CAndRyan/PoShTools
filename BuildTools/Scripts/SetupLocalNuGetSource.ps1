Import-Module $(Join-Path $PSScriptRoot "../NuGetHelpers.psm1") -Scope Local

if ($null -eq $env:ONEDRIVE) {
    throw "OneDrive environment variable is not available in this terminal"
}
if (-not (Test-Path $env:ONEDRIVE)) { # stop early if the onedrive directory doesn't exist, so it isn't created below
    throw "OneDrive directory (from environment variable) not found: $($env:ONEDRIVE)"
}

$sourceName = "OneDrive"
$relativeSourcePath = "NuGet"
$sourcePath = Join-Path $env:ONEDRIVE $relativeSourcePath

[System.IO.Directory]::CreateDirectory($sourcePath) |Out-Null

Register-LocalNuGetSource -Name $sourceName -Source $sourcePath
