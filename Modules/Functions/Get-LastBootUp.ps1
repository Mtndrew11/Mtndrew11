Function Get-LastBootUp
{
<#
.SYNOPSIS
Queries the last boot up time of the specified computer(s)

.DESCRIPTION
Queries the last boot up time of the specified computer(s)

.EXAMPLE
Get-LastBootUp -ComputerName Computer1, Computer2


.NOTES
 
#>

    [CmdletBinding()]
    Param(
            [Parameter (Mandatory=$True)]
            [string[]]$ComputerName,

            [string]$Protocol = "Wsman"
         )

    BEGIN {<#$Creds = Get-Credential#>}

    PROCESS
    {
        ForEach ($Computer in $ComputerName)
        {
            #Remote Protocol
            $Option = New-CimSessionOption -Protocol Wsman
            
            #Connect Session
            $Session = New-CimSession -ComputerName $Computer -SessionOption $Option -Credential $Creds
            
            #Query Data
            $OS_params = @{'ClassName'='Win32_OperatingSystem'
                           'CimSession'=$Session}
            $OS = Get-CimInstance @OS_params
            
            #Close Session
            $Session | Remove-CimSession

            #Output Data
            $Props = @{
                        'ComputerName' = $OS.CSName
                        'LastBootup'   = $OS.LastBootUpTime
                      }

            $Obj = New-Object -TypeName PSObject -Property $Props
            Write-Output $Obj
        }
    }

    END {}
}