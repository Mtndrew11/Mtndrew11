[CmdletBinding()]
Param(
        [string[]]$ComputerName,

        [System.Management.Automation.PSCredential]$Credential
        )
        
<#--------------------
      Computers
--------------------#>
ForEach ($Computer in $ComputerName)
{
    $Bios = Get-CimInstance Win32_Bios | Select-Object *
    $CS = Get-CimInstance Win32_ComputerSystem | Select-Object *
    $OSinfo = Get-CimInstance Win32_OperatingSystem | Select-Object *
    $IP = ""

    $CurrentData = ([PSCustomObject]@{
                                        Make        = $CS.PSComputerName
                                        Model       = $CS.DeviceID
                                        ModelNumber = $CS.Size / 1GB -as [int]  
                                        Serial      = $Bios.Serial   
                                        Hostname    = $Computer
                                        OSversion   = $OS.Caption
                                        IP = ""                                        
                                    })


    $AllData = $AllDisks + $CurrentData     
}

$AllData