function Get-ContentNonBlocking {
	param(
		[Parameter(Mandatory=$true)]
		[string]
		$FilePath
    )
    
    $resolvedFilePath = Resolve-Path $FilePath |Select-Object -ExpandProperty Path

	[System.IO.FileStream]$fileStream = [System.IO.File]::Open($resolvedFilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
	$byteArray = New-Object byte[] $fileStream.Length
	$encoding = New-Object System.Text.UTF8Encoding $true

	while ($fileStream.Read($byteArray, 0 , $byteArray.Length)) {
		$encoding.GetString($byteArray)
	}

	$fileStream.Dispose()
}

function Test-CommandIsAvailable {
    param(
        [Parameter(Mandatory=$true, HelpMessage="The command or program name to test for command line availability")]
        [string]
        $Command
    )

    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-FirstFileByFilter {
    param(
        [Parameter(Mandatory=$true, HelpMessage="The directory to search")]
        [string]
        $Directory,

        [Parameter(Mandatory=$true, HelpMessage="The search filter to use (ie. *.csproj)")]
        [string]
        $Filter,

        [Parameter()]
        [switch]
        $Recurse
    )

    return Get-ChildItem -Path $Directory -Filter $Filter -Recurse:$Recurse |
        Select-Object -First 1 -ExpandProperty FullName
}

function Get-SingleLineString {
    param(
        [Parameter(
            Mandatory=$true,
            Position=0,
            HelpMessage="An array of strings to consolidate into a single, one-line string")]
        [ValidateScript({ $_ |% { $_.GetType().Name -eq "String" } })]
        [object[]]
        $InputObject,

        [Parameter()]
        [string]
        $Delimiter = ""
    )

    $output = [System.String]::Join($Delimiter, $InputObject)

    return $output -replace "`r`n|`r|`n","$Delimiter"
}
