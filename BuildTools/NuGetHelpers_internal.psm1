function Edit-NewNuGetSpecFile {
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
