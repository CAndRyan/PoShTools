<#
.SYNOPSIS
	Create a Handle Object
.DESCRIPTION
	Creates a custom Powershell object storing all the properties found when parsing the handle.exe output. This function is intended for use with Get-Handle, not to be used as an independent function. 
   
	~@Author:	Chris Ryan
	@Initial:	July 25th, 2015
	@Version:	03/16/2016
	@Reviewer:	TBD
.EXAMPLE
	New-Handle -props ("a", 3, "b", "c", "d", "e", "f")
	This command will create a handle with the seven properties of a handle. Note that the second
	property (Process ID) is an integer while the rest are all strings, including the Handle ID (property 4),
	which will be in hexadecimal format.
.INPUTS
	An array of seven values where the second is an integer and the others are strings.
.LINK
	Get-Handle
	Get-HandleOutput
	Close-Handle
.ROLE
	Private
#>
function New-Handle {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param (
        # Array of properties to create this object
        [Parameter(Mandatory=$true)]
        [alias("p")]
        [Object[]]
        $props
    )
    $h = New-Object -TypeName PSObject
    $h |Add-Member -MemberType NoteProperty -Name ProcessName -Value $props[0] -PassThru |
		Add-Member -MemberType NoteProperty -Name ProcessId -Value $props[1] -PassThru |
		Add-Member -MemberType NoteProperty -Name User -Value $props[2] -PassThru |
		Add-Member -MemberType NoteProperty -Name HandleId -Value $props[3] -PassThru |
		Add-Member -MemberType NoteProperty -Name HandleType -Value $props[4] -PassThru |
		Add-Member -MemberType NoteProperty -Name Rights -Value $props[5] -PassThru |
		Add-Member -MemberType NoteProperty -Name Name -Value $props[6]

    return $h
}

<#
.SYNOPSIS
	Trim Handle.exe Output
.DESCRIPTION
	Uses Handle.exe created by Mark Russinovich at SysInternals. Provide a username to trim the output of Handle.exe down to only information regarding that username.
	
	~@Author:	Chris Ryan
	@Initial:	July 25th, 2015
	@Version:	03/14/2016
	@Reviewer:	TBD
.EXAMPLE
	Get-HandleOutput -username test
	This command will output all handles found from the Handle.exe output which pertain to the user "test".
.INPUTS
	A required <String>.
.LINK
	New-Handle
	Get-Handle
	Close-Handle
.ROLE
	Private~h_ExePath
#>
function Get-HandleOutput {
	[CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param (
		[Parameter(Mandatory=$true)]
        [String]
        $Username,

		[Parameter(Mandatory=$true)]
        [String]
        $ExePath
    )
	$dump = & $ExePath -a -accepteula -u
	$dump = $dump[5..$dump.Length]
	$newDump = @()
	
	for ($i = 0; $i -lt ($dump.Length - 1); $i++) {
		if ($dump[$i] -like "-*") {
			$newDump += $dump[$i]
			$i++
			$newDump += $dump[$i]
			$i++
		}
		
		if ($dump[$i] -like "*$Username*") {
			$newDump += $dump[$i]
		}
	}
	
	Remove-Variable dump
	$cleanDump = @()
	
	for ($i = 0; $i -lt $newDump.Length; $i++) {
		if ($newDump[$i] -like "-*") {
			if (($newDump[$i + 2] -notlike "-*") -and (($i + 2) -lt $newDump.Length)) {
				$cleanDump += $newDump[$i]
				$i++
				$cleanDump += $newDump[$i]
				$i++
			}
			else {
				$i = $i + 1
				Continue
			}
		}
		
		$cleanDump += $newDump[$i]
	}
	
	Remove-Variable newDump
	Return $cleanDump
}

<#
.SYNOPSIS
	Find a User's Handles
.DESCRIPTION
	Uses Handle.exe created by Mark Russinovich at SysInternals. Uses custom Handle class to store the information.

	~@Author:	Chris Ryan
	@Initial:	July 25th, 2015
	@Version:	03/14/2016
	@Reviewer:	TBD
.EXAMPLE
	Get-Handle -username test
	This command will output all handles found for the user "test".
.EXAMPLE
	Get-Handle -user "test user"
	This command will output all handles found for the user "test user". Quotes are only required if the
	username contains a space.
.EXAMPLE
	Get-Handle -user test -servers (comp1, comp2)
	This command will output all handles found for the user "test" on the machines named "comp1" 
	and "comp2".
.INPUTS
	A required <String> and an optional <String[]>.
.LINK
	New-Handle
	Get-HandleOutput
	Close-Handle
.ROLE
	Private~h_ModPath
#>
function Get-Handle {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    Param (
        # Username to search handles for
        [Parameter(Mandatory=$true,
                   HelpMessage="Enter a username")]
        [alias("u")]
        [string]
        $Username,
		
		# Server(s) to query
		[Parameter()]
		[alias("v")]
		[string[]]
		$Server,

		# Path of module on machine(s)
		[Parameter()]
		[string]
		$ModPath = "C:\temp\Handle.psm1",

		# Path to the executable (handle.exe)
		[Parameter()]
        [String]
        $ExePath = "C:\temp\handle.exe"
    )
	BEGIN {
		if (!($Server)) {
			$Server = $env:computername		# default to the machine running this
		}

		$foundHandles = @()
		$sw = [Diagnostics.Stopwatch]::StartNew()		# To test the run time of this loop
	}
	PROCESS {
		$foundHandles += Invoke-Command -ComputerName $Server -ScriptBlock {
			$Username = $args[0]
			Import-Module $args[1]
		
			# Regular expressions to match the lines to
			$regexp1 = "^([^ ]+)\spid:\s(\d+)\s([\s*\S*]+)$"
			$regexp2 = "^([(0-9)*(A-F)*]+):\s([^ ]+)\s{2}(\([[RWD-]{3}]?\))\s*([\s*\S*]*$Username[\s*\S*]*)$"
			$regexp3 = "^([(0-9)*(A-F)*]+):\s([^ ]+)\s*([\s*\S*]*$Username[\s*\S*]*)$"
		
			$PSHandles = New-Object System.Collections.Generic.List[PSCustomObject]
			$procInfo = ("", 0, "", "", "", "", "")		# passed as parameter to Create-Handle
			$handles = Get-HandleOutput -Username $Username -ExePath $args[2]
			
			for ($i = 0; $i -lt $handles.Length; $i++) {
				$line = [string]$handles[$i].trim()
			
				# Indicates start of new process
				if ($line.SubString(0, 1) -eq "-") {
					$i++		# Move to the next line
					$line = [string]$handles[$i].trim()

					# Match to regular expression for this line and extract info
					$valid1 = $line -match $regexp1
					if ($valid1) {
						$procInfo[0] = [String]$Matches[1]
						$procInfo[1] = [int]$Matches[2]
						$procInfo[2] = [String]$Matches[3]
					}
				
					# Prep for first file handle from this process
					$i++
					$line = [string]$handles[$i].trim()
				}
			
				# Match to regular expression for the file handle lines and extract info
				$valid2 = $line -match $regexp2
				
				if ($valid2) {		# If it matches regexp2 it is a File and has the access property
					$procInfo[3] = [String]$Matches[1]
					$procInfo[4] = [String]$Matches[2]
					$procInfo[5] = [String]$Matches[3]
					$procInfo[6] = [String]$Matches[4]
				}
				else {	
					$valid3 = $line -match $regexp3
					if ($valid3) {		# If it matches regexp3 it is some type other than File and skips the access property
						$procInfo[3] = [String]$Matches[1]
						$procInfo[4] = [String]$Matches[2]
						$procInfo[5] = ""
						$procInfo[6] = [String]$Matches[3]
					}
					else {		# skip storing this one if it doesn't match the regex
						Clear-Variable Matches
						continue		
					}
				}

				Clear-Variable Matches

				$tempHandle = New-Handle -props $procInfo
				$PSHandles.add($tempHandle)	
			}
			
			Return $PSHandles
		} -ArgumentList @($Username, $ModPath, $ExePath)
	}
	END {
		$sw.Stop()
		$ts = $sw.Elapsed
		$elapsedTime = "$($ts.minutes):$($ts.seconds).$($ts.milliseconds)"
		Write-Verbose "Elapsed time (minutes:seconds.milliseconds) -> $elapsedTime"
		
		# Return search results
		$foundHandles | Sort-Object -Property PSComputerName, ProcessId
	}
}

<#
.SYNOPSIS
	Close Open Handles
.DESCRIPTION
	Closes handles by using the process and handle IDs. Meant to be used in conjuction with Get-Handle. Uses Handle.exe created by Mark Russinovich at SysInternals.

	~@Author:	Chris Ryan
	@Initial:	July 25th, 2015
	@Version:	03/14/2016
	@Reviewer:	TBD
.EXAMPLE
	Close-Handle -handleId 6F -processId 2364
	This command will close the handle with hid 6F and pid 2364.
.EXAMPLE
	Close-Handle -h "5D" -p 1234
	This command will close the handle with hid 6F and pid 2364.
.EXAMPLE
	Close-Handle "47" 865
	This command will close the handle with hid 47 and pid 865.
.EXAMPLE
	Get-Handle test | Close-Handle
	This command will retrieve the open file handles of user "test" and close all that it can.
.INPUTS
	Either an array of custom handle objects or it will accept an integer array <int[]> (process Id's) and
	a string array <String[]> (handle Id's) which are of the same size.

	An array of custom handle objects can be piped to this function as well.
.LINK
	New-Handle
	Get-Handle
	Get-HandleOutput
.ROLE
	Private~h_ExePath
#>
function Close-Handle {
    [CmdletBinding()]
    Param (
		# Server that houses these handles
        [Parameter(Mandatory=$true,
                   HelpMessage="Enter a server for where these handles reside")]
        [alias("s")]
        [string]
        $Server,

		# Handle ID to close (in hexadecimal format)
        [Parameter(Mandatory=$true,
                   HelpMessage="Enter a Handle ID number (Hexadecimal)")]
        [alias("h")]
        [string[]]
        $HandleId,

        # Process ID. Required to close the chosen handle
        [Parameter(Mandatory=$true,
                   HelpMessage="Enter a Process ID number")]
        [alias("p")]
        [int[]]
        $ProcessId,

		[Parameter()]
		[string]
		$ExePath = "C:\temp\handle.exe"
    )
	BEGIN {
		# Verify there is an equal number of handle and process ID's
		if ($HandleId.Length -ne $ProcessId.Length) {
			Write-Error "Number of Handle ID's and Process ID's must match!"
			Break
		}
		
		Write-Verbose "Attempting to close $($HandleId.Length) handle(s)"
	}
	PROCESS {
		$closedCount = Invoke-Command -ComputerName $Server -ScriptBlock {
			# Actually close all the handles specified
			$count = 0
			for ($j = 0; $j -lt $($args[0]).Length; $j++) {
				if ($($args[1])[$j] -ne 4) {			# Exclude system processes
					& $args[2] -accepteula -c $($args[0])[$j] -p $($args[1])[$j] -y | Out-Null
					$count++
				}
				else {
					Write-Verbose "Unable to close system process <PID 4>, skipping..."
				}
			}

			return $count
		} -ArgumentList @($HandleId, $ProcessId, $ExePath)
	}
	END {
		Write-Verbose "Ran closure on $closedCount handles for server $Server"
	}
}
