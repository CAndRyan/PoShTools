<#
.SYNOPSIS
	Remote to a Server
.DESCRIPTION
	Enter a server name to connect to through a Microsoft remote connection. You will be prompted to enter your credentials before connecting.
   
	~@Author:	Chris Ryan
	@Initial:		October 21st, 2015
	@Version:	10/21/2015
	@Reviewer:	TBD
.ROLE
	Public
#>
function Enter-RemoteServer {
    [CmdletBinding()]
    Param (
        # Server(s) to connect to
        [Parameter()]
        [String[]]
        $Server
    )
	$returnStr = "Successful:`n"
	$unavailable = "`nUnavailable:`n"
	foreach ($s in $Server) {
		# Test connection to server
		if (Test-Connection -count 1 $s -quiet) {
			# Run mstsc.exe to connect, could use cmdkey.exe to pass a credentials object through powershell to all connections
			Invoke-Expression "mstsc.exe /v:$s /f"		# /w:1920 /h:1080 doesn't seem so good...
			$returnStr += "`t$s`n"
		}
		else {
			$unavailable += "`t$s`n"
		}
	}
	
	$returnStr += $unavailable
	
	Return $returnStr
}
