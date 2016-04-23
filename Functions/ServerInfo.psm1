<#
.SYNOPSIS
	Retrieve Last Boot Time
.DESCRIPTION
	Provide an array of server names. The function will return an array of each server's last boot time.

	~@Author:	Chris Ryan
	@Initial:		September 7th, 2015
	@Version:	03/21/2016
	@Reviewer:	TBD
.ROLE
	Public~s_Format-Table -AutoSize
#>
function Get-ServerBootTime {
    [CmdletBinding()]
    Param (
        # Server name or array of server names.
        [Parameter()]
		[alias("v")]
        [string[]]
        $Server
    )
	# Retrieve the last boot time for all servers passed
	$bootTime = Get-WmiObject -ComputerName $Server -Class win32_operatingsystem |
		Select-Object @{LABEL='Server';EXPRESSION={$_.csname}}, @{LABEL='LastBootUpTime';EXPRESSION={$_.ConvertToDateTime($_.lastbootuptime)}}
		
	return $bootTime
}
