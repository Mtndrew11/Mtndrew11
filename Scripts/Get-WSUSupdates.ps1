


<#
    Copy PSWindowsUpdate module
    Install module

#>

[CmdletBinding()]
Param(
        [string[]]$Computer,
        [System.Management.Automation.PSCredential]$Credentials
     )




#Import-Module PSWindowsUpdate
#Get-WindowsUpdate -ComputerName $Computer
whoami