Function Get-DiskInventory
{
    [CmdletBinding()]
    Param(
            [string[]]$ComputerName,

            [switch]$VMsOnly,

            [System.Management.Automation.PSCredential]$Credential
         )
         
    $AllDisks = @()
    $ALLVMs = @()
    Clear-Variable DiskProps -ErrorAction SilentlyContinue


    <#--------------------
          VMs ONLY
    --------------------#>
    IF ($VMsOnly -eq $true)
    {
        ForEach ($Computer in $ComputerName)
        {
            $CurrentHostVMs = @()

            $CurrentHostVMs = Get-VM -ComputerName $Computer
            $ALLVMs = $ALLVMs + $CurrentHostVMs
        }

        Write-Host "The following VMs have been found on specified hosts:"
        $AllVMs.Name


        ForEach ($VM in $ALLVMs)
        {
            Clear-Variable DiskProps -ErrorAction SilentlyContinue

            $Disks = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $VM -Credential $Credential

            $DiskProps = ([PSCustomObject]@{
                                    Computer    = $Disk.PSComputerName
                                    DriveLetter = $Disk.DeviceID
                                    Size        = $Disk.Size / 1GB -as [int]                                             
                                })
            
            $DiskProps

        }

    }


    <#--------------------
          Computers
    --------------------#>
    ForEach ($Computer in $ComputerName)
    {
        $Disks = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $Computer -Credential $Credential

        ForEach ($Disk in $Disks)
        {

            $DiskProps = ([PSCustomObject]@{
                                                Computer    = $Disk.PSComputerName
                                                DriveLetter = $Disk.DeviceID
                                                Size        = $Disk.Size / 1GB -as [int]                                             
                                           })


            $AllDisks = $AllDisks + $DiskProps
        }

        $AllDisks        
    }
}