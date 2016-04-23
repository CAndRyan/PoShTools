<#
.SYNOPSIS
	Get Current Users
.DESCRIPTION
	Provide a server or array of servers to find all users currently logged in to them. If no server is provided, the current machine running this function will be queried. Provide a username as well to search for that user across the entered server(s).

	~@Author:	Chris Ryan
	@Initial:		March 10, 2016
	@Version:	03/21/2016
	@Reviewer:	TBD
.ROLE
	Public~h_Delay~h_Loop~s_Select-Object -Property * | Format-Table -AutoSize -GroupBy Server
#>
function Get-CurrentUser {
    [CmdletBinding()]
    Param (
		# Username to check for
        [Parameter()]
        [alias("u")]
        [string]
        $Username,
		
		# Server(s) to query
		[Parameter()]
		[alias("v")]
		[string[]]
		$Server,

		# Time for each loop (ms) (default is for 1 second)
        [Parameter()]
		[alias("d")]
        [int]
        $Delay = 20,

		# Number of loops to go through (default is for 1 second)
        [Parameter()]
		[alias("l")]
        [int]
        $Loop = 50
    )
	BEGIN {
		if (!($Server)) {
			$Server = $env:computername		# default to the machine running this
		}
		
		# Script block to retrieve data and build user objects
		$code = {
			param([string]$s, [string]$u)

			$list = @()
			$queryRegex = "^[>]?([^ ]+)\s+[^ ]*\s+(\d+)\s+([^ ]+)\s+([\d:.+none]+)\s+(.+)"
			$sessionDump = ""
			$queryError = $false
			$ErrorActionPreference = "Stop"
			try {
				# re-direct error message to standard out
				$sessionDump = query user $u /server:$s 2>&1
			}
			catch {
				$queryError = $true
			}
			$ErrorActionPreference = "Continue"
			
			# If no error is returned, a session, or sessions, were found
			if (!($queryError)) {
				foreach ($line in $sessionDump) {
					$line = $line.Trim()
					if ($line -notlike "USERNAME*") {   # indicates first line of query's return string
						$user = New-Object -TypeName PSObject
						$valid = $line -Match $queryRegex
						if ($valid) {
							# Add most of the properties to the user object
							$user | Add-Member -MemberType NoteProperty -Name Server -Value $s -PassThru |
								Add-Member -MemberType NoteProperty -Name Username -Value $Matches[1] -PassThru |
								Add-Member -MemberType NoteProperty -Name Id -Value $Matches[2] -PassThru |
								Add-Member -MemberType NoteProperty -Name State -Value $Matches[3]

							# Format the date-time
							$logonTime = Get-Date $Matches[5] -Format "MM/dd-HH:mmtt"

							# Format the idle time
							$idleTime = $Matches[4]
							if ($idleTime -eq ".") {
								$idleTime = "<1m"
							}
							elseif ($idleTime -like "*:*") {
								$validTime = $idleTime -Match "^(\d+):(\d+)"
								if ($validTime) {
									$idleTime = "$($Matches[1])" + "h-" + "$($Matches[2])" + "m"
								}
								elseif ($idleTime -match "^(\d+)\+(\d+):(\d+)") {
									$idleTime = "$($Matches[1])" + "d-" + "$($Matches[2])" + "h-" + "$($Matches[3])" + "m"
								}
								else {
									Write-Verbose "Query user: invalid idle time"
								}
							}
							elseif ($idleTime -eq "none") {   # means this is a downed session
								$user.State = "Down"
							}
							else {
								$idleTime = "$idleTime" + "m"
							}
							
							# Add on the remainder of the user properties and add to list
							$user |Add-Member -MemberType NoteProperty -Name Idle -Value $idleTime -PassThru |
								Add-Member -MemberType NoteProperty -Name LoggedOn -Value $logonTime

							$list += $user
						}
						else {
							Write-Verbose "Query User: no match"
						}
					}
				}
			}
			else {    # check the error thrown
				if ($Error.Count -gt 0) {
					Write-Verbose $Error[0].Exception.Message
				}
			}

			return $list
		}

		$userList = New-Object System.Collections.Generic.List[PSCustomObject]
	}
	PROCESS {
		# Call the script block through a runspace for each server
		foreach ($serv in $Server) {
			Write-Verbose "Searching server $serv"

			$posh = [PowerShell]::Create().AddScript($code).AddArgument($serv).AddArgument($Username)
			$job = $posh.BeginInvoke()

			# Test job completion and timeout
			$count = 0
			do {
				Start-Sleep -Milliseconds $Delay
				if ($job.IsCompleted) {
					$count = $Loop
				}
				$count++
			} while ($count -lt $Loop)   # timeout 
			
			# Throw timeout error if the count reached the loop count ((loop + 1) means completed)
			if ($count -eq $Loop) {
				Write-Verbose "$serv timed out. >$($Loop * $Delay)ms"
				Write-Error "$serv took longer than $($Loop * $Delay)ms to respond and was skipped!"
			}
			else {
				# Extract runspace results and dispose of it
				$result = $posh.EndInvoke($job)
				$posh.Dispose()
				foreach ($item in $result) {
					$userList.Add($item)
				}
			}
		}
	}
	END {
		return $userList
	}
}
