<#
.SYNOPSIS
Displays pending windows updates from software center

.DESCRIPTION
Displays pending windows updates from software center on the specified targeted computers

.PARAMETER ComputerName
Specifies the targeted computer(s)

.PARAMETER VMsOnly
Targets VMs on a specific host (specified with the ComputerName parameter) and excludes the hosts

.PARAMETER Cluster
Targets a specific cluster. Targets hosts only by default. Use the VMsOnly parameter to target the VMs and exclude the hosts

.PARAMETER Diag
Enables debugging mode and outputs additional information to the console in blue for troubleshooting purposes.

.EXAMPLE
.\Get-Updates.ps1 -ComputerName HypervHost1, HypervHost2 -VMsOnly
Targets only the VMs that reside on the Hyper-V hosts and NOT the host themselves (hosts are specified with the -ComputerName parameter)

.EXAMPLE
.\Get-Updates.ps1 -ComputerName HypervHost1, HypervHost2 -VMsOnly
Outputs additional information to the console for troubleshooting purposes

.EXAMPLE
.\Get-Updates.ps1 -ComputerName (Get-Content \\path\to\text\file\ComputerList.txt)
Targets servers listed in the ComputerList.txt file

.NOTES
    Version 1.0
    Author: Drew King
    Updated 1/28/2021 0900 Uploaded to Git

.LINK
www.docs.microsoft.com/en-us/mem/configmgr/develop/reference/core/clients/sdk/ccm_softwareupdate-client-wmi-class

#>


[CmdletBinding()]
Param(
        [string[]]$ComputerName,
        [string[]]$Cluster,
        [string[]]$VMsOnly,
        [switch]$Diag
     )



<#----------------------------------------
                Functions
----------------------------------------#>
$LogFile = "PSScriptRoot\Logs_test_$(Get-Date -Format yyyyMMdd_HHmm.ss).csv"

#region Functions
Function Write-Log
{
    [CmdletBinding()]
    Param(
            [Parameter(Mandatory = $false)][String]$File = $LogFile,
            [Parameter(Mandatory = $false)][String]$LineValue,
            [Parameter(Mandatory = $false)][Switch]$Create,
            [Parameter(Mandatory = $false)][Switch]$Finish,

            [Parameter(Mandatory = $false)][String]$Timestamp,
            [Parameter(Mandatory = $false)][String]$Object,
            [Parameter(Mandatory = $false)][String]$Command,
            [Parameter(Mandatory = $false)][String]$Success,
            [Parameter(Mandatory = $false)][String]$ErrorMsg,
            [Parameter(Mandatory = $false)][String]$Message,
            [Parameter(Mandatory = $false)][String]$Output
         )

    Clear-Variable LogProps -ErrorAction SilentlyContinue

    $LogProps = ([PSCustomObject]@{
                                        Timestamp = (Get-Date -Format yyyyMMdd-HHmm.ss)
                                        Object    = $Object
                                        Command   = $Command
                                        Success   = $Success
                                        ErrorMsg  = $ErrorMsg
                                        Message   = $Message
                                        Output    = $Output
                                  })

    IF ($Create -eq $true)
    {
        Try
        {
            $Date = Get-Date -Format yyyyMMdd_HHmm.ss
            $global:FullName = "$PSScriptRoot\Logs_test_$($Date).csv"
            Set-Content $global:FullName -Value "Timestamp,Object,Command,Success,ErrorMsg,Message,Output" -Force
            Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)]`: Log file successfuly created."
        }

        Catch
        {
            Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)]`: Unable to create log file!" 
        }
    }

    ELSEIF ($Finish -eq $true)
    {
        
    }

    ELSE
    {
        Write-Host "Writing the following:"
        $LogProps
        $LogProps | Export-Csv FullName -Append -NoTypeInformation
    }

} #END Function Write-Log

Function Remove-ExpiredCreds
{
    IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Remove-ExpiredCreds) Starting function" -ForegroundColor Cyan}

    $cred_filename = "$PSScriptRoot\_creds.csv"

    #IF CSV exists
    IF (Test-Path $cred_filename)
    {
        IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Remove-ExpiredCreds) Path to $($cred_filename) exists!" -ForegroundColor Cyan}
    
        #Finding old creds
        $Today = Get-Date
        $ExpiredCreds = Import-Csv $cred_filename | Where-Object { ($Today - [datetime]::ParseExact($_.DateWritten,'yyyyMMdd-HHmmss', $null) ).Days -gt 7 }
        $ValidCreds = Import-csv $cred_filename | Where-Object { ($Today - [datetime]::ParseExact($_.DateWritten,'yyyyMMdd-HHmmss', $null) ).Days -lt 7 }

        #Any expired creds found?
        IF ($ExpiredCreds -gt 0)
        {
            IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Remove-ExpiredCreds) Expired creds found and $($ValidCreds.count) valid creds found." -ForegroundColor Cyan}
    
            #Valid creds found
            IF ($ValidCreds.count -gt 0)
            {
                IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Remove-ExpiredCreds) Exporting valid credentials" -ForegroundColor Cyan}
                $ValidCreds | Export-csv $cred_filename -NoTypeInformation
            }

            #No valid creds found
            ELSE
            {
                Write-Host "No valid creds... overwriting _creds.csv as blank file with headers."
                Set-Content "$PSScriptRoot\_creds.csv" -Value "username,cred_user,cred_pass,DateWritten,ComputerName" -Force
            }
        }
    }

    #CSV does NOT exist
    ELSE
    {
        Set-Content "$PSScriptRoot\_creds.csv" -Value "username,cred_user,cred_pass,DateWritten,ComputerName" -Force
    }


} #END Function 

Function Test-Connectivity
{
    [CmdletBinding()]
    Param(
            [string[]]$ComptuerName
         )

    $global:PINGTestSuccessful = ""

    Try
    {
        $PINGresults = Test-Connection -ComputerName $ComputerName -Count 2 -ErrorAction Stop
        $Status = "ONLINE"
        $global:PINGTestSuccessful = $true
        IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Test-Connectivity) Ping test successful on $Computer" -ForegroundColor Cyan}
    }

    Catch
    {
        $global:PINGTestSuccessful = $false
    }


} #END Function Test-Connectivity

Function Get-ObjectOU
{
    [CmdletBinding()]
    Param(
            [string[]]$Object
         )

    IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Get-ObjectOU) Gathering organizational unit for $Object " -ForegroundColor Cyan}
    
    Try
    {
        $global:ObjectOU = (Get-ADComputer "$Object" -Properties * | Select-Object CanonicalName -ErrorAction Stop).CanonicalName
    }

    Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
    {
        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)]`: $Object does not exist in active directory" 
    }

    Catch
    {
        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] ERROR`: Unable to obtain comptuer object from active directory"
    }
    



} #END Function Get-ObjectOU

Function Set-Creds
{
    IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Set-Creds) Setting credentials " -ForegroundColor Cyan}

    $username = [Environment]::Username
    $Credentials = $null
    $global:creds = $null
    $cred_filename = "$PSScriptRoot\_creds.csv"

    IF ( -not (Test-Path $cred_filename) )
    {
        Set-Content "$PSScriptRoot\_creds.csv" -Value "username,cred_user,cred_pass,DateWritten,ComptuerName"
    }

    
    Try
    {
        IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Set-Creds) Importing CSV data... " -ForegroundColor Cyan}
        $creds = Import-Csv $cred_filename

        #IF user exists in CSV
        IF ($creds.username -contains $username)
        {
            IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Set-Creds) $username exists in CSV data!" -ForegroundColor Cyan}
            $cred = $creds | Where-Object {$_.username -eq $username}
            $secure_string = $cred.cred_pass | ConvertTo-SecureString -Force
            $global:Credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $cred.cred_user, $secure_string
        }

        
        #CurrentUser does NOT exist in CSV
        ELSE
        {
            IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Set-Creds) User NOT found in CSV data!" -ForegroundColor Cyan}

            do
            {
                $Credentials = Get-Credential -Message "Enter your credentials (Domain\username)"
                IF ($Credentials.UserName -notlike "*\*")
                {
                    Write-Host "You must specify the domain name (see example)" -ForegroundColor Yellow
                    Start-Sleep -Seconds 3
                }

                IF ( ($Credentials.GetNetworkCredential().Password).Length -eq 0 )
                {
                    Write-Host "You must specify a password!" -ForegroundColor Yellow
                    Start-Sleep -Seconds 3
                }

            }until ( ($Credentials.username -like "*\*") -and ( ($Credentials.GetNetworkCredential().Password).Length -ne 0 ) )

            $cred_pass = $Credentials.Password | ConvertFrom-SecureString
            $Properties = [ordered]@{
                                        "username"     = $username
                                        "cred_user"    = $Credentials.UserName
                                        "cred_pass"    = $cred_pass
                                        "DateWritten"  = Get-Date -Format yyyyMMdd-HHmmss
                                        "ComputerName" = $env:COMPUTERNAME
                                    }

            $row = New-Object -TypeName PSCustomObject -Property $Properties
            $row | Export-Csv $cred_filename -Append 
        }

        $global:Credentials = $Credentials

        IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Set-Creds) Credentials set to $($global:Credentials.UserName)" -ForegroundColor Cyan}
    }

    Catch [System.Security.Cryptography.CryptographicException]
    {
        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] ERROR`: Password was encrypted from a different machine!" -ForegroundColor Red
        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)]`: Rerun script from the same machine or remove password from CSV and run script again." -ForegroundColor Red
    }

    Catch
    {
        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] ERROR`: Error setting credentials!" -ForegroundColor Red
        IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Set-Creds) Verify password was encrypted from $env:COMPUTERNAME" -ForegroundColor Cyan}
    }


} #END Function Set-Creds

Function Test-Creds
{
    [CmdletBinding()]
    Param(
            [System.Management.Automation.PSCredential]$Credentials,
            [string[]]$Computer
         )

    IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Test-Creds) Testing credentials with $($Credentials.UserName)" -ForegroundColor Cyan}
    

    #Validate credentials
    Try
    {
        
        IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Test-Creds) Mapping drive to test folder" -ForegroundColor Cyan}
        New-PSDrive -Name _Folder1 -PSProvider FileSystem -Root \\Full\path\to\folder\with\permissions -Credential $Credentials -ErrorAction Stop
        Remove-PSDrive -Name _Folder1 -PSProvider FileSystem
        IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Test-Creds) Credentials validated. Mapped drive removed." -ForegroundColor Cyan}
        $global:TestSuccessful = $true
    }

    Catch
    {
        
        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] ERROR`: Unable to validate credentials" -ForegroundColor Cyan
        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] ERROR`: $($Error[0].Exception)" -ForegroundColor Red
    }

} #END Function Test-Creds

Function Get-Updates
{
    [CmdletBinding()]
    Param(
            [string[]]$ComputerName,
            [string[]]$Cluster,
            [switch]$VMsonly,
            [System.Management.Automation.PSCredential]$Credentials
         )

    
    IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Get-Updates) Starting Get-Updates function" -ForegroundColor Cyan}

    Function Get-SCCMUpdates
    {
        [CmdletBinding()]
        Param(
                [string[]]$ComputerName,
                [switch]$VMsOnly
             )

        Clear-Variable Services, VM, VMs, AllVMs -ErrorAction SilentlyContinue

        #region MAIN
            #region Try
            Try
            {
                IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Get-Updates) Checking for updates..." -ForegroundColor Cyan}
                
                Test-Connectivity -ComptuerName $ComputerName

                IF ($global:PINGTestSuccessful -eq $false)
                {
                    Write-Error -Exception ([System.Net.NetworkInformation.PingException]::new("Ping exception occurred")) -ErrorAction Stop
                }

                <#--------------------
                    Obtain Updates
                --------------------#>
                IF ($global:PINGTestSuccessful -eq $true)
                {
                    <#-------------------------
                        Check for SCCM Client
                    -------------------------#>
                    $SCCMclient = Get-WmiObject -ComputerName $ComputerName -Namespace "ROOT\ccm" -Class SMS_client -Credential $global:Credentials -ErrorAction Stop
                    
                    IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Get-Updates) Checking for updates..." -ForegroundColor Cyan}

                    $Updates = Get-WmiObject -ComputerName $ComputerName -Query "SELECT * FROM CCM_SoftwareUpdate WHERE Compliance = '0' " -Namespace "ROOT\ccm\ClientSDK" -Credential $global:Credentials -ErrorAction Stop

                    IF ($null -eq $Updates)
                    {
                        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] $ComputerName`: No pending updates found." -ForegroundColor Green
                        $UpdateProps = ([PSCustomObject]@{
                                                            Name            = $ComputerName
                                                            Status          = $Status
                                                            ArticleID       = "No pending updates found."
                                                            EvalState       = ""
                                                            PercentComplete = ""
                                                         })
                    }
                    
                    ELSE
                    {
                        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] $ComputerName`: Updates found!" -ForegroundColor Yellow
                        [array]$UpdateProps = @()

                        ForEach ($Update in $Updates)
                        {
                            switch ($Update.EvaluationState)
                            {
                                0  {$EvalState = "Available"}
                                1  {$EvalState = "Available"}
                                5  {$EvalState = "Downloading"}
                                6  {$EvalState = "Waiting to install"}
                                7  {$EvalState = "Installing"}
                                8  {$EvalState = "Pending reboot"}
                                10 {$EvalState = "WaitReboot"}
                                11 {$EvalState = "Pending verification"}
                                12 {$EvalState = "Complete"}
                                13 {$EvalState = "Failed to update"}
                                20 {$EvalState = "Pending update"}
                            }

                            $Props = ([PSCustomObject]@{
                                                            Name            = $ComputerName
                                                            Status          = $Status
                                                            ArticleID       = $Update.ArticleID
                                                            EvalState       = $EvalState
                                                            PercentComplete = $Update.PercentageComplete
                                                        })

                            $UpdateProps = $UpdateProps + $Props
                            Clear-Variable EvalState -ErrorAction SilentlyContinue
                        } # END ForEach
                    } # END ELSE
                }
            }
            #endregion


            #region Catch

            #OFFLINE
            Catch [System.Net.NetworkInformation.PingException]
            {
                Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] ERROR`: $ComputerName - OFFLINE" -ForegroundColor Red
            }

            #ACCESS is denied
            Catch [System.UnauthorizedAccessException]
            {
                Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] ERROR`: $ComputerName - Access is denied" -ForegroundColor Red
            }

            #Exception
            Catch [System.Management.ManagementException]
            {
                Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] ERROR`: $ComputerName - There was an exception" -ForegroundColor Red
            }

            #SCCM Client
            Catch [System.Runtime.InteropServices.COMException]
            {
                Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] ERROR`: $ComputerName - Unable to query CCM client" -ForegroundColor Red
            }

            #Catch ALL
            Catch
            {
                Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] ERROR`: $ComputerName - Failed to check for updates! A generic error occurred." -ForegroundColor Red
            }
            #endregion


        Clear-Variable Status, ArticleID, EvalState, Update, UpdateList -ErrorAction SilentlyContinue
        $Error.clear()
        #endregion
    
    } # END Function Get-SCCMUpdates


    #region ComputerName
    
    IF ($null -ne $ComputerName)
    {
        ForEach ($Computer in $ComputerName)
        {
            Clear-Variable Props, Update, UpdateProps -ErrorAction SilentlyContinue
            [array]$UpdateProps = ""
            IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: ($Computer) Starting Get-Updates function computers section" -ForegroundColor Cyan}
            
            IF ($VMsonly -eq $true)
            {
                Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] $Computer`: Gathering VMs..."
                $VMs = Invoke-Command -ComputerName $Computer -ScriptBlock {Get-VM} -Credential $global:Credentials
            
                ForEach ($VM in $VMs)
                {
                    Get-SCCMUpdates -ComputerName $VM
                }
            }

            ELSE
            {
                Get-SCCMUpdates -ComputerName $ComputerName
            }
        }
    }

    #endregion

    #region Cluster

    IF ($null -ne $Cluster)
    {
        Clear-Variable AllVMs -ErrorAction SilentlyContinue
        [string]$Cluster = $Cluster[0] 

        <#--------------------
           Get Cluster Props
        --------------------#>
        IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Get-Updates) Cluster section started" -ForegroundColor Cyan}

        #Get Cluster
        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] $Cluster`: (Get-Updates) Getting cluster properties"
        $ClusterProperties = Invoke-Command -ComputerName $Cluster -ScriptBlock {Get-Cluster -Name $Using:Cluster} -Credential $Credentials

        #Get Nodes
        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] $Cluster`: (Get-Updates) Getting cluster nodes"
        $ClusterProperties = Invoke-Command -ComputerName $Cluster -ScriptBlock {(Get-ClusterNode -Cluster $Using:Cluster).Name} -Credential $Credentials
        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] $Cluster`: (Get-Updates) $($Nodes.count) nodes were found on the $Cluster cluster"


        <#--------------------
               VMs ONLY
        --------------------#>
        IF ($VMsonly -eq $true)
        {
            IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Get-Updates) VMsOnly specified" -ForegroundColor Cyan}
            

            #Get VMs on each node
            [array]$AllVMs = @()
            ForEach ($Node in $Nodes)
            {
                $NodeVMs = @()

                Try
                {
                    Test-Connectivity -ComptuerName $Node
                
                    IF ($global:PINGTestSuccessful -eq $false)
                    {
                        Write-Error -Exception ([System.Net.NetworkInformation.PingException]::new("Ping exception occurred")) -ErrorAction Stop
                    }
                }

                #OFFLINE
                Catch [System.Net.NetworkInformation.PingException]
                {
                    Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] ERROR`: $Node - OFFLINE"
                }

                Catch
                {
                    Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] ERROR`: $Node - There was an error connecting to the node"
                }

                Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] $Cluster`: Getting VMs on $Node..."
                
                $NodeVMs = Invoke-Command -ComputerName $Node -ScriptBlock {Get-VM} -Credential $Credentials
                $AllVMs = $AllVMs + $NodeVMs
            }

                    
            <#------------------------------
                 VMs' pre-export status
            ------------------------------#>
            IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Get-Updates) Exporting status of all VMs prior to shutting down" -ForegroundColor Cyan}
            $AllVMs | Select-Object VMName, State, Status, ComputerName, Uptime, Generation, IsClustered, Path, VMId, ConfigurationLocation | Export-Csv $PSScriptRoot\$($Cluster)-VMs.csv -NoTypeInformation
            

            <#------------------------------
                 Remove non-updating VMs
            ------------------------------#>
            IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Get-Updates) Removing VMs NOT targeted for updates" -ForegroundColor Cyan}
            $AllVMs = $AllVMs | Where-Object {
                                                $_.State  -ne      "Off"          -and
                                                $_.VMname -notlike "SkipThisVM*"
                                             }

            #Cleanup / Sort
            $AllVMs = $AllVMs | Sort-Object VMname
            
            <#------------------------------
                   Cluster Selection
            ------------------------------#>
            #region ClusterSelection
            IF ($Cluster -eq "Cluster1")
            {
                IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Get-Updates) Cluster1 cluster section" -ForegroundColor Cyan}
                Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] $Cluster`: (Get-Updates) VMs found on nodes:"
                $AllVMs | Select-Object VMName, ComputerName, State, IsClustered | Format-Table -AutoSize
            }


            IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Get-Updates) Initiating Get-SCCMUpdates for each VM" -ForegroundColor Cyan}
            ForEach ($VM in $AllVMs)
            {
                $VM = $VM.Name
                Get-SCCMUpdates -ComputerName $VM
            }
            #endregion
        }


        <#------------------------------
                  Hosts ONLY
        ------------------------------#>
        ELSE
        {
            IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (Get-Updates) Initiating Get-SCCM updates for each node (hosts ONLY)" -ForegroundColor Cyan}
            
            #Get updates on each node
            ForEach ($Node in $Nodes)
            {
                Try
                {
                    Test-Connectivity -ComptuerName $Node

                    IF ($global:PINGTestSuccessful -eq $false)
                    {
                        Write-Error -Exception ([System.Net.NetworkInformation.PingException]::new("Ping exception occurred")) -ErrorAction Stop
                    }

                    Get-SCCMUpdates -ComputerName $Node
                }

                Catch [System.Net.NetworkInformation.PingException]
                {
                    Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] ERROR`: $Node - OFFLINE" -ForegroundColor Red
                }
                
                Catch
                {
                    Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] ERROR`: $Node - There was an error connecting to the node" -ForegroundColor Red
                }
            }
        }

    }
    #endregion Cluster

} #END Function Get-Updates

#endregion



<#----------------------------------------
                  MAIN
----------------------------------------#>

#region MAIN

Write-Host "
#==================================================#
#   $($MyInvocation.MyCommand) script started!         #
#==================================================#
" -ForegroundColor Cyan


<#----------------------------------------
        Delcare Variables / Cleanup
----------------------------------------#>
$Error.Clear()
[array]$ServersPendingReboot = @()
[array]$global:MasterData    = @()
Clear-Variable UpdateProps -ErrorAction SilentlyContinue
Remove-ExpiredCreds

<#----------------------------------------
    ComputerName parameter specified
----------------------------------------#>
IF ($null -ne $ComputerName)
{
    ForEach ($Computer in $ComputerName)
    {
        IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (MAIN) ----------Beginning---------- $Computer" -ForegroundColor Cyan}

        <# Step 1 #> Test-Connectivity -ComptuerName $Computer

        <# Step 2 #> Set-Creds

        <# Step 3 #> Test-Creds -Computer $Computer -Credentials $Credentials

        <# Step 4 #> IF ($VMsOnly -eq $true)
                     {
                        Get-Updates -ComputerName $Computer -VMsonly -Credentials $Credentials
                     }

                     ELSE
                     {
                        Get-Updates -ComputerName $Computer -Credentials $Credentials
                     }
    }
}



<#----------------------------------------
       Cluster parameter specified
----------------------------------------#>
ELSEIF ($null -ne $Cluster)
{
    ForEach ($ClusterObj in $Cluster)
    {
        IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (MAIN) ----------Beginning---------- $ClusterObj" -ForegroundColor Cyan}

        <# Step 1 #> Test-Connectivity -ComptuerName $ClusterObj

        <# Step 2 #> Set-Creds

        <# Step 3 #> Test-Creds -Computer $ClusterObj -Credentials $Credentials

        <# Step 4 #> IF ($VMsOnly -eq $true)
                     {
                        Get-Updates -Cluster $ClusterObj -VMsonly -Credentials $Credentials
                     }

                     ELSE
                     {
                        Get-Updates -Cluster $ClusterObj -Credentials $Credentials
                     }
    }
}

<#----------------------------------------
       CN or Cluster not specified
----------------------------------------#>
ELSE {}


<#----------------------------------------
         Servers Pending Reboot
----------------------------------------#>
#region ServersPendingReboot
    IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (MAIN) Checking for computers with pending reboot status and no additional updates actively installing..." -ForegroundColor Cyan}
    
    <#--------------------------------------------------
         Remove computers with status of "Installing"
    --------------------------------------------------#>
    $UniqueComputers = $MasterData.Name | Select-Object -Unique
    ForEach ($Computer in $UniqueComputers)
    {
        IF ( ( ( $MasterData | Where-Object {$_.Name -eq $Computer} ).EvalState ) -ccontains "Pending Reboot" )
        {
        
            #Check for "Installing status"
            IF ( ( ( $MasterData | Where-Object {$_.Name -eq $Computer} ).EvalState ) -ccontains "Installing"           -or
                 ( ( $MasterData | Where-Object {$_.Name -eq $Computer} ).EvalState ) -ccontains "Downloading"          -or
                 ( ( $MasterData | Where-Object {$_.Name -eq $Computer} ).EvalState ) -ccontains "Waiting to install"   -or
                 ( ( $MasterData | Where-Object {$_.Name -eq $Computer} ).EvalState ) -ccontains "WaitReboot"           -or
                 ( ( $MasterData | Where-Object {$_.Name -eq $Computer} ).EvalState ) -ccontains "Pending verification"
               )
            {
                #Updates still installing... not adding to reboot list
            }

            ELSE
            {
                IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (MAIN) Not updates installing on $Computer. Adding to reboot list" -ForegroundColor Cyan}
                $ServersPendingReboot = $ServersPendingReboot + $Computer
            }
        }

        ELSE
        {
            IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (MAIN) No updates pending reboot found." -ForegroundColor Cyan}
        }
    }


    <#----------------------------------------
             Prompt for reboots
    ----------------------------------------#>
    IF ($ServersPendingReboot.count -gt 0)
    {
        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] RESULTS`: $($ServersPendingReboot.count) server(s) found pending reboot. Prompting for selection..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    
        $ObjectsSelected = $ServersPendingReboot | Out-GridView -PassThru -Title "Select the servers to reboot"
        IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (MAIN) $($ObjectsSelected.count) objects were selected." -ForegroundColor Cyan}
        
        IF ($ObjectsSelected.count -gt 0)
        {
            IF ($Diag){Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] DIAG`: (MAIN) (Inside objects selected -gt 0) $($ObjectsSelected.count) objects were selected" -ForegroundColor Cyan}
        
            Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)]`: (MAIN) The following servers were selected."
            Write-Output $ObjectsSelected
            Write-Host ""

            $msg = 'Are you sure you would like to reboot the selected servers? [Y/N]'
            do
            {
                $response = Read-Host -Prompt $msg
            }
            until ( ($reponse -clike 'Y') -or ($response -clike 'N') )


            IF ($response -eq 'Y')
            {
                Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)]`: $(([Environment]::UserName)) decided to reboot the servers."
                $Reboot = $true

                <#------------------------------
                         Reboot servers
                ------------------------------#>
                IF ($Reboot -eq $true)
                {
                    ForEach ($Computer in $ObjectsSelected)
                    {
                        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)]`: Restarting $Computer..."
                        Restart-Computer -ComputerName $Computer -Credential $Credentials -Force
                    }

                    Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)]`: Servers may take several minutes to install updates prior to rebooting" -ForegroundColor Yellow
                    Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)]`: To check the status of the update installations directly and monitor reboot, open a VM console form Hyper-V" -ForegroundColor Yellow
                }

            }

            ELSE
            {
                Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)]`: $(([Environment]::UserName)) decided to NOT reboot servers."
            }

        }

        ELSE
        {
            Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)]`: No objects were selected for reboot"
        }
    }

    ELSE
    {
        Write-Host "[$(Get-Date -Format yyyyMMdd-HHmm.ss)] RESULTS`: 0 servers found with pending reboot" -ForegroundColor Green
    }

#endregion


#endregion MAIN