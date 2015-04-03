param(
	[String]$Server,
	[String]$Database,
	[String]$Instance
)
Import-Module -Name NVR_NAVScripts -DisableNameChecking -Force
Import-Module -Name CommonPSFunctions
Import-Module (Get-NAVAdminModuleName)
Remove-NAVLocalApplication -Server $Server -Database $Database -ServerInstance $Instance
