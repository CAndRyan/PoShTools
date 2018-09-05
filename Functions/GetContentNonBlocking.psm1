
function Get-ContentNonBlocking {
	param(
		[Parameter(Mandatory=$true)]
		[string]
		$FullFilePath
	)

	[System.IO.FileStream]$fileStream = [System.IO.File]::Open($FullFilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
	$byteArray = New-Object byte[] $fileStream.Length
	$encoding = New-Object System.Text.UTF8Encoding $true

	while ($fileStream.Read($byteArray, 0 , $byteArray.Length)) {
		$encoding.GetString($byteArray)
	}

	$fileStream.Dispose()
}
