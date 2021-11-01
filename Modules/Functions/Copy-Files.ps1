Function Copy-Files
{
<#
.SYNOPSIS
Displays progress while copying file(s)

.DESCRIPTION
Copies file(s) with progress bar. Progress of copy fir a single file is indicated by the file size. Progress of copy for multiple files is indicated by quantity of files to be copied.

.PARAMETER Source
Location of the source file(s)

.PARAMETER Destination
Location for the file(s) to be copied to

.EXAMPLE
Copy-Files -Source "\\path\to\source\file.txt" -Destination "C:\Windows\Temp"

.EXAMPLE
Copy-Files -Source "\\path\to\source\folder1" -Destination "C:\Windows\Temp\SubFolder"

.NOTES

#>

    [CmdletBinding()]
    Param(
            [string]$Source,
            [string]$Destination
        )

    <##############################
            Initial Config
    ##############################>
        Clear-Variable TransferJob -ErrorAction SilentlyContinue
        $StartTime = Get-Date
        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)]`: Copying $Source to $Destination"

    <##############################
             Single File
    ##############################>
    IF ( ( (Get-Item $Source).Attributes -ne "Directory" ) -and ( (Get-Item $Source).Extension -like "*.*" ) )
    {
        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)]`: Only one file targeted for copy"
        $TransferJob = Start-BitsTransfer -Source -Destination $Destination -Asynchronous

        do
        {
            $TransferJob = Get-BitsTransfer -JobId $TransferJob.JobId
            $Transferred = [math]::round($TransferJob.BytesTransferred/1MB,2)
            $Total = [math]::round($TransferJob.BytesTotal/1MB,2)
            
            Write-Progress -Activity "Copying $Source to $Destination" -Status "$Transferred MBs of $Total MBs complete" -PercentComplete ( ( $TransferJob.BytesTransferred / $TransferJob.BytesTotal ) * 100 )
        }
        While ( $TransferJob.BytesTransferred -ne $TransferJob.BytesTotal )

        Write-Progress -Activity "Copying $Source " -Status "Ready" -Completed
        Get-BitsTransfer -JobId $TransferJob.JobId | Complete-BitsTransfer
    }


    <##############################
       Multiple Files/Directories
    ##############################>
    ELSE
    {
        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)]`: Multiple files/folders targeted for copy"

        IF ( ! (Test-Path $Destination))
        {
            New-Item -Path $Destination -ItemType Directory | Out-Null
        }

        ELSE
        {
            Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)]`: $Destination already exists"
        }

        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)]`: Gatering targeted items..."
        $Items = Get-ChildItem -Path $Source -Recurse | Where-Object {$_.Attributes -ne "Directory"} | Sort-Object Directory

        For ($i = 0; $i -lt $Itmes.Count; $i++)
        {
            Clear-Varaible FinalDestination -ErrorAction SilentlyContinue
            $CurrentFile = $i + 1
            $FinalDestination = ( (Split-Path -Path $Items[$i].FullName) ).Replace($Source,$Destination)

            IF ( ! (Test-Path $FinalDestination) )
            {
                New-Item -Path $FinalDestination -ItemType Directory -Force | Out-Null
            }

            Write-Progress -Activity "Copying file $($Item[$i].Name)" -Status "$CurrentFile of $($Items.Count) files complete" -PercentComplete ( ($i / $Item.Count) * 100 )
            Copy-Item $Items[$i].FullName -Destination $FinalDestination -Recurse -Force
        }

        Write-Progress -Activity "Copying file $($item[$i].Name)" -Status "Ready" -Completed
    }

    <##############################
               Cleanup
    ##############################>
        $EndTime = Get-Date
        $Duration = ($EndTime - $StartTime).ToString("hh' hours 'mm' minutes 'ss' seconds' ")
        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)]`: File copy complete! Duration: $Duration"
}