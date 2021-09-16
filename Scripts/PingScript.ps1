$Computers = Get-Content "$($PSScriptRoot)\Computers.txt"
$Computers.count
$Date = Get-Date -Format yyyymmdd-HHmm

ForEach ($Computer in $Computers)
{
    Write-Host "Checking $Computer..."
    $Result = Test-Connection -ComputerName $Computer -Count 2 -ErrorAction SilentlyContinue

    IF ($Result)
    {
        $Status = $Result[0].IPv4Address.IPAddressToString
    }

    ELSE
    {
        $Status = "OFFLINE"
    }
    
    #Output
    $Props = ([pscustomobject]@{
        'ComputerName'=$Computer
        'Status'=$Status
    })

    $Props | Export-Csv $PSScriptRoot\PingStatus-$($Date).csv -Append -Force -NoTypeInformation

}