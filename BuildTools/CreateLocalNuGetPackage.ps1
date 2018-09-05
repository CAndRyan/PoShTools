#
# Initialize a nuget package spec file
# Edit the .nuspec file as needed
# Publish the package to pack and push to the output directory
#

# TODO: update to read destination from config
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]
    $ProjectDirectory,

    [Parameter(Position=1, ParameterSetName="Publish")]
    [string]
    $Destination
)

Import-Module $(Join-Path $PSScriptRoot "./NuGetHelpers.psm1")

try {
    if ($PSCmdlet.ParameterSetName -eq "Publish") {
        Publish-LocalNuGetPackage -ProjectDirectory $ProjectDirectory -Destination $Destination
    } else {
        Initialize-LocalNuGetPackage -ProjectDirectory $ProjectDirectory
    }
} catch {
    throw $_
 } finally {
    Remove-Module "NuGetHelpers" # TODO: can be removed when complete
}
