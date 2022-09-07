Function Copy-Files {
<#
.SYNOPSIS
Displays progress while copying file(s) / folder(s)

.DESCRIPTION
Copies file(s) / folder(s) with progress bar. Progress of copy for a single file is indicated by the file size. Progress of copy for multiple files is indicated by quantity of files to be copied.

.PARAMETER Source
Location of the source file(s) / folder(s)

.PARAMETER Destination
Location for the file(s) / folder(s) to be copied to

.EXAMPLE
Copy-Files -Source "\\path\to\source\file.txt" -Destination "C:\Windows\Temp"

.EXAMPLE
Copy-Files -Source "\\path\to\source\folder1" -Destination "C:\Windows\Temp\SubFolder"

.NOTES

#>

    [CmdletBinding()]
    Param(
        [string]$ComputerName,
        [string]$Source,
        [string]$Destination
    )
    
    Clear-Variable TransferJob -ErrorAction SilentlyContinue

    <##############################
             Single File
    ##############################>
    IF ( ( (Get-Item $Source).Attributes -ne "Directory" ) -and ( (Get-Item $Source).Extension -like "*.*") ) {

        <# ----- Check if folder exists ----- #>
        IF ( ( ! ( Test-Path $Destination) ) ) {
            New-Item -Path $Destination -ItemType Directory | Out-Null
        }

        ELSE {
            IF ( $global:DIAG -eq $true) { Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] $ComputerName`: Folder already exists" -ForegroundColor Gree }
        }
        
        <# ----- Check if file exists ----- #>
        IF ( ( ! ( Test-Path $($Destination + "\" + ($Source -split "\\")[-1] ) ) ) ) {
            $StartTime = Get-Date
            Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)]`: Copying $Source to $Destination"

            $TransferJob = Start-BitsTransfer -Source $Source -Destination $Destination -Asynchronous

            do {
                $TransferJob = Get-BitsTransfer -JobId $TransferJob.JobId
                $Transferred = [math]::round($TransferJob.BytesTransferred/1MB,2)
                $Total       = [math]::round($TransferJob.BytesTotal/1MB,2)

                Write-Progress -Activity "Copying $Source to $Destination" -Status " $Transferred MBs of $Total MBs complete" -PercentComplete ( ( $TransferJob.BytesTransferred / $TransferJob.BytesTotal ) * 100 )
            } while ( $TransferJob.BytesTransferred -ne $TransferJob.BytesTotal)
        
            Write-Progress -Activity "Copying $Source to $Destination" -Status "Ready" -Completed
            Get-BitsTransfer -JobId $TransferJob.JobId | Complete-BitsTransfer
        
        }

        ELSE {
            Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] $ComputerName`: $Destination\$(($Source -split "\\")[-1]) already exists"
        }

    }
        
    <##############################
       Multiple Files/Directories
    ##############################>
    ELSE {
        IF ( $global:DIAG -eq $true ) {Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] $ComputerName`: Multiple files/folders targeted for copy."}
        $StartTime = Get-Date

        <# ----- Check if folder exists ----- #>
        IF ( ! ( Test-Path $Destination ) ) {
            New-Item -Path $Destination -ItemType Directory | Out-Null

            IF ( $global:DIAG -eq $true ) {Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] $ComputerName`: Gathering items..."}
            $Items = Get-ChildItem -Path $Source -Recurse | Where-Object {$_.Attributes -ne "Directory"} | Sort-Object Directory
            
            IF ( $Items.Count -eq 0 ) {
                Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] $ComputerName`: No files found in directorie(s)."
            }

            ELSE {
                IF ( $global:DIAG -eq $true ) {Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] $ComputerName`: $($Items.Count) items targeted for copy."}

                For ( $i = 0; $i -lt $Items.count; $i++) {
                    Clear-Variable FinalDestination -ErrorAction SilentlyContinue
                    $CurrentFile = $i + 1
                    $FinalDestination = ( ( Split-Path -Path $Items[$i].FullName) ).Replace($Source, $Destination)

                    IF ( ( ! (Test-Path $FinalDestination) ) ) {
                        New-Item -Path $FinalDestination -ItemType Directory -Force | Out-Null
                    }

                    ELSE {
                        
                    }

                    Write-Progress -Activity "Copying file $($Items[$i].Name)" -Status "$CurrentFile of $($Items.Count) files complete" -PercentComplete ( ( $i / $Items.Count) * 100 )
                    Copy-Item $Items[$i].FullName -Destination $FinalDestination -Recurse -Force
                }

                Write-Progress -Activity "Copying file $($Items[$i].Name)" -Status "Ready" -Completed
            }
        }

        ELSE {
            Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] $ComputerName`: $Destination already exists"
        }

    }

    <##############################
               Cleanup
    ##############################>
        Start-Sleep -Seconds 3
        $EndTime = Get-Date
        $Duration = ($EndTime - $StartTime).ToString("hh' hours 'mm' minutes 'ss' seconds'")
        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)]`: File copy complete! Duration: $Duration"
}