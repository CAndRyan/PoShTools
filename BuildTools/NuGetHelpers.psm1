Import-Module $(Join-Path $PSScriptRoot "../Functions/Helpers.psm1")
Import-Module $(Join-Path $PSScriptRoot "./NuGetHelpers_internal.psm1")

function Initialize-NuGetPackage {
    param(
        [Parameter(Mandatory=$true, HelpMessage="The directory containing the project file to be packed")]
        [ValidateScript({ Test-Path $_ })]
        [string]
        $ProjectDirectory,

        [Parameter(HelpMessage="Set the build mode here (ie. debug, release, ...)")]
        [string]
        $BuildMode = "Release"
    )

    if (-not (Test-CommandIsAvailable "nuget")) {
        throw "NuGet is not available in this terminal"
    }
    
    $projectFilePath = Get-FirstFileByFilter -Directory $ProjectDirectory -Filter "*.csproj"
    if ($projectFilePath -eq $null) {
        throw "Unable to find project file in directory: $ProjectDirectory"
    }
    $projectFilePath = Resolve-Path $projectFilePath

    $content = Get-SingleLineString (Get-ContentNonBlocking $projectFilePath)

    $hasAssemblyData = $content -match "<AssemblyName>([^<]*)<"
    if (-not $hasAssemblyData) {
        throw "Unable to find assembly data in the project file: $projectFilePath"
    }
    $assemblyName = $Matches[1]

    $specPath = Join-Path $ProjectDirectory "$assemblyName.nuspec"
    if (Test-Path $specPath) {
        throw "A .nuspec file already exists for this project: $specPath"
    }
    
    $hasOutputPath = $content -match "<PropertyGroup[^>]*$BuildMode[^>]*>.*<OutputPath>([^<]*)<.*</PropertyGroup>"
    if (-not $hasOutputPath) {
        throw "Unable to find data in the project file: $projectFilePath, for build mode '$BuildMode'"
    }
    $relativeOutputPath = $Matches[1]

    Push-Location $ProjectDirectory
    try {
        & nuget spec $projectFilePath
    } catch {
        throw $_
    } finally {
        Pop-Location
    }

    $resolvedSpecPath = Resolve-Path ($specPath) |Select-Object -ExpandProperty "Path"
    Edit-NewNuGetSpecFile $resolvedSpecPath $relativeOutputPath

    Write-Host "Edit the .nuspec file at: $resolvedSpecPath"
}

function New-NuGetPackage {
    param(
        [Parameter(Mandatory=$true, HelpMessage="The directory containing the nuspec file for a project to be packed")]
        [ValidateScript({ Test-Path $_ })]
        [string]
        $ProjectDirectory,

        [Parameter(Mandatory=$true, HelpMessage="The destination path for this package")]
        [ValidateScript({ Test-Path $_ })]
        [string]
        $Destination,

        [Parameter(HelpMessage="Set the build mode (ie. debug, release, ...). If different from the mode used to generate the .nuspec file, the relative file paths may differ.")]
        [string]
        $BuildMode = "Release",

        [Parameter(HelpMessage="Publish the package using the file with this name (wildcard accepted). By default, publish will use the project file instead of directly using the .nuspec file.")]
        [string]
        $PackSourceFileName = "*.csproj"
    )

    if (-not (Test-CommandIsAvailable -Command "nuget")) {
        throw "NuGet is not available in this terminal"
    }

    $sourceFileName = $(Get-ChildItem -Path $ProjectDirectory -Name $PackSourceFileName |Select-Object -First 1)
    $sourcePath = Resolve-Path (Join-Path $ProjectDirectory $sourceFileName) |Select-Object -ExpandProperty Path

    $packOutput = $null
    & nuget pack $sourcePath -OutputDirectory $Destination -properties "Configuration=$BuildMode" -Build |
        Tee-Object -Variable packOutput |Out-Default
    $packOutput = Get-SingleLineString $packOutput
    
    $wasSuccessful = $packOutput -match "Successfully created package '([^']*)'"
    if (-not $wasSuccessful) {
        throw "Unable to parse the package path from the NuGet output"
    }
    $packagePath = Resolve-Path $Matches[1] |Select-Object -ExpandProperty Path

    return $packagePath
}

function Register-LocalNuGetSource {
    param(
        [Parameter(Mandatory=$true, HelpMessage="The name for this NuGet source")]
        [string]
        $Name,

        [Parameter(Mandatory=$true, HelpMessage="The source path")]
        [ValidateScript({ Test-Path $_ })]
        [string]
        $Source
    )

    if (-not (Test-CommandIsAvailable -Command "nuget")) {
        throw "NuGet is not available in this terminal"
    }

    & nuget sources add -Name $Name -Source $Source
}

function Get-NuGetSourceLocation {
    param(
        [Parameter(Mandatory=$true, HelpMessage="The NuGet source name")]
        [string]
        $SourceName
    )

    if (-not (Test-CommandIsAvailable -Command "nuget")) {
        throw "NuGet is not available in this terminal"
    }

    $sourcePath = $null
    $sources = & nuget sources list -Format Detailed

    for ($i = 0; $i -lt $sources.Length; $i++) {
        if ($sources[$i] -match "$SourceName \[([^\]]*)\]") {
            if ($Matches[1] -ne "Enabled") {
                throw "The provided NuGet source is disabled: $SourceName"
            }

            $sourcePath = $sources[$i + 1].Trim()
            break
        }
    }

    if (-not (Test-Path $sourcePath)) {
        throw "The path for the provided source was not found: $sourcePath"
    }

    return $sourcePath
}

function Add-LocalPackageToNuGetSource {
    param(
        [Parameter(Mandatory=$true, HelpMessage="The path to the NuGet package (*.nupkg file)")]
        [string]
        $PackagePath,

        [Parameter(Mandatory=$true, HelpMessage="The NuGet source name to add the package to")]
        [string]
        $SourceName
    )

    if (-not (Test-CommandIsAvailable -Command "nuget")) {
        throw "NuGet is not available in this terminal"
    }

    $resolvedPackagePath = Resolve-Path $PackagePath |Select-Object -ExpandProperty "Path"

    $sourcePath = Get-NuGetSourceLocation -SourceName $SourceName
    
    & nuget add $resolvedPackagePath -source $sourcePath
}

function Publish-NuGetPackage {
    param(
        [Parameter(Mandatory=$true, HelpMessage="The directory containing the nuspec file for a project to be packed")]
        [ValidateScript({ Test-Path $_ })]
        [string]
        $ProjectDirectory,

        [Parameter(Mandatory=$true, HelpMessage="The NuGet source name to add the package to")]
        [string]
        $SourceName,

        [Parameter(HelpMessage="The temporary destination path for this package")]
        [ValidateScript({ Test-Path $_ })]
        [string]
        $TempDestination = "",

        [Parameter(HelpMessage="Set the build mode (ie. debug, release, ...). If different from the mode used to generate the .nuspec file, the relative file paths may differ.")]
        [string]
        $BuildMode = "Release",

        [Parameter(HelpMessage="Publish the package using the file matching this name (wildcard accepted). By default, publish will use the project file instead of directly using the .nuspec file.")]
        [string]
        $PackSourceFileName = "*.csproj",

        [Parameter(HelpMessage="If true, keep the original package that was published")]
        [switch]
        $KeepPackage
    )

    if (-not (Test-CommandIsAvailable -Command "nuget")) {
        throw "NuGet is not available in this terminal"
    }

    if ($TempDestination -eq "") {
        $destination = Join-Path $env:TEMP "NuGetLocalPackages"
        $TempDestination = [System.IO.Directory]::CreateDirectory($destination) |Select-Object -ExpandProperty FullName
    }
    
    $packagePath = New-NuGetPackage -ProjectDirectory $ProjectDirectory -Destination $TempDestination -BuildMode $BuildMode -PackSourceFileName $PackSourceFileName
    Add-LocalPackageToNuGetSource -PackagePath $packagePath -SourceName $SourceName

    if ($KeepPackage) {
        Write-Host "The original package will remain at: '$packagePath'"
    } else {
        Remove-Item $packagePath
    }
}

function Get-NuGetPackages {
    param(
        [Parameter(Mandatory=$true, HelpMessage="The NuGet source name to search")]
        [string]
        $SourceName
    )

    $sourceLocation = Get-NuGetSourceLocation -SourceName $SourceName

    & nuget list -Source $sourceLocation
}

function Remove-NuGetPackage {
    param(
        [Parameter(Mandatory=$true, HelpMessage="The package to remove (package ID in NuGet)")]
        [string]
        $Name,

        [Parameter(Mandatory=$true, HelpMessage="The version of the package to remove")]
        [string]
        $Version,

        [Parameter(Mandatory=$true, HelpMessage="The NuGet source name to remove from")]
        [string]
        $SourceName
    )

    $sourceLocation = Get-NuGetSourceLocation -SourceName $SourceName

    & nuget delete "$Name" "$Version" -Source $sourceLocation
}
