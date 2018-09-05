Import-Module $(Join-Path $PSScriptRoot "../Functions/GetContentNonBlocking.psm1")

function Test-CommandIsAvailable {
    param(
        [Parameter(Mandatory=$true, HelpMessage="The command or program name to test for command line availability")]
        [string]
        $Command
    )

    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-ProjectFilePath {
    param(
        [Parameter(Mandatory=$true, HelpMessage="The directory containing a project file")]
        [string]
        $ProjectDirectory,

        [Parameter()]
        [string]
        $ProjectFileFilter = "*.csproj"
    )

    return Get-ChildItem -Path $ProjectDirectory -Filter $ProjectFileFilter |
        Select-Object -First 1 -ExpandProperty FullName
}

function Initialize-LocalNuGetPackage {
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
    
    $projectFilePath = Get-ProjectFilePath $ProjectDirectory
    if ($projectFilePath -eq $null) {
        throw "Unable to find project file in directory: $ProjectDirectory"
    }
    $projectFilePath = Resolve-Path $projectFilePath

    $contentRaw = Get-ContentNonBlocking $projectFilePath
    $content = [System.String]::Join("", $contentRaw)
    $content = $content -replace "`r|`n|`r`n",""

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

function Edit-NewNuGetSpecFile { # helper function
    param(
        [Parameter(Mandatory=$true, HelpMessage="The .nuspec file to be configured for the first time.")]
        [ValidateScript({ Test-Path $_ })]
        [string]
        $SpecFilePath,

        [Parameter(Mandatory=$true, HelpMessage="The build output path, relative to the project file.")]
        [string]
        $RelativeBuildOutputDirectory
    )

    $metadataNodesToRemove = @(
        "licenseUrl",
        "projectUrl",
        "iconUrl",
        "tags"
    )

    $doc = New-Object System.Xml.XmlDocument
    $doc.Load($SpecFilePath)

    # TODO: update to be more sophisticated instead of removing all these nodes
    $metadataNodesToRemove |ForEach-Object {
        $node = $doc.GetElementsByTagName($_)[0]
        $doc.DocumentElement.metadata.RemoveChild($node) |Out-Null
    }

    # TODO: update to be more sophisticated and accept release notes for the initial spec file
    $releaseNotesNode = $doc.SelectNodes("(//releaseNotes)[1]")[0]
    $emptyReleaseNotesNode = $doc.CreateElement("releaseNotes")
    $doc.DocumentElement.metadata.RemoveChild($releaseNotesNode) |Out-Null
    $doc.DocumentElement.metadata.AppendChild($emptyReleaseNotesNode) |Out-Null

    $doc.Save($SpecFilePath)
}

function Publish-LocalNuGetPackage {
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

    & nuget pack $sourcePath -OutputDirectory $Destination -properties "Configuration=$BuildMode" -Build
}
