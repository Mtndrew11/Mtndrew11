Function Get-ADUserGroups
{
<#
.SYNOPSIS
Obtains the groups of an Active Directory users object

.DESCRIPTION
Obtains the groups of an Active Directory users object

.PARAMETER UserName
Specified user account to be searched in Active Directory

.EXAMPLE
Get-ADUserGroups -UserName User1

.NOTES

#>

    [CmdletBinding()]
    Param(
            [Parameter(Mandatory = $True)][String[]]$UserName
         )

    ForEach ($User in $UserName)
    {
        Write-Host $User -ForegroundColor Green
        (Get-ADUserPrincipalGroupMembership -Identity $User).Name
        Write-Output ""
    }
}