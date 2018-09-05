param(
    [Parameter(Mandatory=$true, HelpMessage="The directory containing the project file")]
    [ValidateScript({ Test-Path $_ })]
    [string]
    $ProjectDirectory
)

Import-Module $(Join-Path $PSScriptRoot "../NuGetHelpers.psm1") -Scope Local

Initialize-NuGetPackage -ProjectDirectory $ProjectDirectory
