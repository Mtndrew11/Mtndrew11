Function Get-MachineInfo
{
<#
.SYNOPSIS
Retrieves specific information about one or more computers

.DESCRIPTION


.PARAMETER UserName


.EXAMPLE


.NOTES

#>

    [CmdletBinding()]
    Param(
            [Parameter(Mandatory = $True)]
            [String[]]$ComputerName,

            [string]$LogFailuresToPath,

            [ValidateSet('Wsman','Dcom')]
            [string]$Protocol = "Wsman",

            [switch]$ProtocolFallback,

            [System.Management.Automation.PSCredential]$Credentials
         )

    

    ForEach ($Computer in $ComputerName)
    {
        $Option = New-CimSessionOption -Protocol Wsman

        Try
        {
            $Params = @{'ComputerName'= $Computer
                        'SessionOption' = $Option
                        'ErrorAction' = 'Stop'
                        'ErrorVariable' = 'ErrorMessage'
                        'Credential' = $Credential
                       }

            $Session = New-CimSession @params

            $OS_params = @{'ClassName' = 'Win32_OperatingSystem'
                           'CimSession' = $Session}
            $OS = Get-CimInstance @OS_params

            $CS_params = @{'ClassName' = 'Win32_ComputerSystem'
                           'CimSession' = $Session}
            $CS = Get-CimInstance @CS_params

            $BIOS_params = @{'ClassName' = 'Win32_Bios'
                             'CimSession' = $Session}
            $BIOS = Get-CimInstance @BIOS_params

            $Date = Get-Date -Format yyMMdd-HHmm.ss

            $Session | Remove-CimSession

            $Props = ([PSCustomObject]@{
                                            'Date' = $Date
                                            'ComputerName' = $Computer
                                            'Make' = $CS.Manufacturer
                                            'Model' = $CS.Model
                                            'SerialNumber' = $BIOS.SerialNumber
                                            'HDcapacity' = $CS.Manufacturer
                                            'RAM' = ($CS.TotalPhysicalMemory / 1GB)
                                            'Processor' = $CS.Numberofprocessors
                                            'OS' = $OS.Caption
                                            'OSversion' = $OS.BuildNumber
                                            'LastBootUp' = $OS.LastBootUpTime
                                        })

            $Props | Export-CSV $PSScriptRoot\MachineInfo_$($Date).csv -Append -NoTypeInformation
            Write-Host $Computer SUCCESS -ForegroundColor Green
            $Props

            $Success = $True
        }

        Catch
        {
            $Props = ([PSCustomObject]@{
                                            'Date' = $Date
                                            'ComputerName' = $Computer
                                            'Make' = "Remoting Failed"
                                       })

            $Props | Export-CSV $PSScriptRoot\MachineInfo_$($Date).csv -Append -NoTypeInformation
            Write-Warning "$Computer FAILED on $Protocol"

            $Success = $False
        }


        $LogProps = ([PSCustomObject]@{
                                        'Date' = $Date
                                        'ComputerName' = $Computer
                                        'Make' = "Remoting Failed"
                                      })
        
    }

}