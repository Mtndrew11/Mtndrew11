Function Test-PingStatus
{
<#
.SYNOPSIS
Tests the online status of the specified computer(s)
.DESCRIPTION
Tests the online status of the specified computer(s)
.EXAMPLE
Test-PingStatus -ComputerName Computer1, Computer2
.EXAMPLE
Test-PingStatus -ComputerName Computer1 -t
.NOTES
 
#>

[CmdletBinding()]
Param(
        [Parameter (Mandatory=$True)]
        [String[]]$ComputerName,

        [switch]$t
     )

IF ($t)
{
    While ($Count -lt 1000)
    {
        ForEach ($Computer in $ComputerName)
        {
            $Result = Test-Connection $Computer -Count 2 -ErrorAction SilentlyContinue
    
            IF ($Result)
            {
                Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] $Computer is Online" -ForegroundColor Green
            }
    
            ELSE
            {
                Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] $Computer is OFFLINE" -ForegroundColor Red
            }
        }     
    }
}

ELSE
{
    ForEach ($Computer in $ComputerName)
    {
        $Result = Test-Connection $Computer -Count 1 -ErrorAction SilentlyContinue

        IF ($Result)
        {
            Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] $Computer is Online" -ForegroundColor Green
        }

        ELSE
        {
            Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] $Computer is OFFLINE" -ForegroundColor Red
        }
    }    
}


}