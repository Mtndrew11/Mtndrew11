Function Get-ADUserPWexpiry
{
<#
.SYNOPSIS
Retrieves the password expiration date of an Active Directory user account object

.DESCRIPTION
Retrieves the password expiration date of an Active Directory user account object

.PARAMETER UserName


.EXAMPLE


.NOTES

#>

    [CmdletBinding()]
    Param(
            [Parameter(Mandatory = $True)][String[]]$UserName
         )

    ForEach ($User in $UserName)
    {
        Try
        {       
            Get-ADUser $User -Properties SamAccountName, "msDS-UserPasswordExpiryTimeComputed" | Select-Object "SamAccountName", @{Name="ExpiryDate";Expression={[datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed")}} 
        }

        #Catch all remaining exceptions
        Catch
        {
            Write-Host "[$(Get-Date -Format 'yyyyMMdd-HHmm.ss')] $Computer`: There was an exception"
        }

    }
}