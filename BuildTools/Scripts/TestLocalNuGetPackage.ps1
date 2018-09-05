#
# Initialize a nuget package spec file
# Edit the .nuspec file as needed
# Create the package
# Publish to the output directory
#

# TODO: update to read destination from config
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]
    $ProjectDirectory,

    [Parameter(Position=1, ParameterSetName="Pack")]
    [string]
    $Destination,

    [Parameter(Position=1, ParameterSetName="Publish")]
    [string]
    $SourceName,

    [Parameter(ParameterSetName="Publish")]
    [switch]
    $KeepPackage
)

Import-Module $(Join-Path $PSScriptRoot "../NuGetHelpers.psm1")

try {
    if ($$PSCmdlet.ParameterSetName -eq "Publish") {
        Publish-NuGetPackage -ProjectDirectory $ProjectDirectory -SourceName $SourceName -KeepPackage:$KeepPackage
    } elseif ($PSCmdlet.ParameterSetName -eq "Pack") {
        New-NuGetPackage -ProjectDirectory $ProjectDirectory -Destination $Destination
    } else {
        Initialize-NuGetPackage -ProjectDirectory $ProjectDirectory
    }
} catch {
    throw $_
 } finally {
    Remove-Module "NuGetHelpers" # TODO: can be removed when complete
}
