# PoShTools
A set of PowerShell tools, scripts and modules, for remote management of servers.

## Handle.psm1
The <i>Handle</i> module containes a collection of functions for extracting and working with open file handles on Windows OS'. It requires a download of Mark Russinovich's <a href="https://technet.microsoft.com/en-us/sysinternals/handle.aspx" target="_blank">Handle utility</a>. The path to Handle.exe needs to be supplied in the -ExePath parameter for finding and closing file handles.

<b>New-Handle</b>: Creates a new PSObject from the provided parameters, which can be extracted from the Handle.exe output.<br/>
<b>Get-HandleOutput</b>: Trims the output of Handle.exe using a provided username. The returned string contains the relevant handle information for that username only.<br/>
<b>Get-Handle</b>: Parses the trimmed output from <i>Get-HandleOutput</i>, returning a list of PSObjects open for the provided user.<br/>
<b>Close-Handle</b>: Takes an array of handle id's and an array of their respective process id's. Each of the provided handles is passed through Handle.exe to be closed.

## GetUser.psm1
The <i>GetUser</i> module contains the function <i>Get-CurrentUser</i> which uses PowerShell runspaces and the utility <i>query user</i> to retrieve all users, or search for a specific user, on the provided servers. The output of this function is a list of user objects containing the properties: Server, Username, Id, State, Idle (time), and LoggedOn (time).

## ServerInfo.psm1
The <i>ServerInfo</i> module contains the function <i>Get-ServerBootTime</i> which retreives the lastbootuptime property from the provided servers.

## Enter-RemoteServer.psm1
The <i>Enter-RemoteServer</i> module contains the function <i>Enter-RemoteServer</i> which uses the utility mstsc.exe to enter a remote session on the provided servers.
