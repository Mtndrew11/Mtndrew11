Function Get-RandomCommand {

	Get-Command | Get-Random | Get-Help -ShowWindow

}