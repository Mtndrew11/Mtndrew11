Function Start-Function1
{
    [CmdletBinding()]
    Param ()
    Write-Error -Message "An error occurred 199" -ErrorAction Stop

    

}

Clear-Host

$Error.clear()


Try
{
    $Error.Clear()
    Start-Function1
}

Catch
{
    Write-Output "Something threw an exception: $($PSItem.ToString())"
    #$Error[0]
    Write-Host ""
    $PSItem.InvocationInfo.PositionMessage # | Format-List *
    Write-Host "---" -ForegroundColor Cyan
    $PSItem.ScriptSTackTrace
    Write-Host "---" -ForegroundColor Cyan
    $PSItem.Exception.Message
    Write-Host "---" -ForegroundColor Cyan
    $PSItem.Exception.InnerMessage
}


