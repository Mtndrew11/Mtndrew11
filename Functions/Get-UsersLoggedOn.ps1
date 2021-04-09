Function Get-UsersLoggedOn
{
<#
.SYNOPSIS
Retrieves user(s) login sessions on remote machine(s)
.DESCRIPTION
Retrieves users login sessions on remote machines via query.exe
.PARAMETER ComputerName
One or more computer names. When using WMI, this can also be IP addresses
.EXAMPLE
Get-UsersLoggedOn -ComputerName Computer1, Computer2
This example will query three machines
.NOTES
#>

    [CmdletBinding()]
    Param(
            [Parameter(Mandatory = $True)][String[]]$ComputerName,
            [System.Management.Automation.PSCredential]$Credential
         )

    ForEach ($Computer in $ComputerName)
    {
        Try
        {       
            Test-Connection $Computer -Count 1 -ErrorAction Stop | Out-Null

            [Array]$LoggedOnUsers = Invoke-Command -ComputerName $Computer -ScriptBlock {& query.exe user 2>&1 | Select-Object -Skip 1} -ErrorAction Stop -Credential $dcapCreds

            IF ($null -ne $LoggedOnUsers)
            {
                ForEach ($LoggedOnUser in $LoggedOnUsers)
                {
                    Write-Host "[$(Get-Date -Format 'yyyyMMdd-HHmm.ss')] $Computer`: $LoggedOnUser"
                }
            }

            ELSE
            {
                Write-Host "[$(Get-Date -Format 'yyyyMMdd-HHmm.ss')] $Computer`: No users logged on"
            }

        }

        #Computer offline
        Catch [System.Net.NetworkInformation.PingException]
        {
            Write-Host "[$(Get-Date -Format 'yyyyMMdd-HHmm.ss')] $Computer`: Computer is offline"
        }
        
        #Access is denied
        Catch [System.Management.Automation.Remoting.PSRemotingTransportException]
        {
            Write-Host "[$(Get-Date -Format 'yyyyMMdd-HHmm.ss')] $Computer`: Access is denied"
        }

        #Catch all remaining exceptions
        Catch
        {
            Write-Host "[$(Get-Date -Format 'yyyyMMdd-HHmm.ss')] $Computer`: There was an exception"
        }

    }
}