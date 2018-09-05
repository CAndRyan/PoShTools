param(
    [Parameter(Mandatory=$true, HelpMessage="The directory containing the nuspec file for a project to be packed")]
    [ValidateScript({ Test-Path $_ })]
    [string]
    $ProjectDirectory
)

Import-Module $(Join-Path $PSScriptRoot "../NuGetHelpers.psm1") -Scope Local

$sourceName = "OneDrive"

Publish-NuGetPackage -ProjectDirectory $ProjectDirectory -SourceName $sourceName
