param(
	[String]$Server,
	[String]$Database,
	[String]$Instance
)
Import-Module NVR_NAVScripts -DisableNameChecking
Import-Module CommonPSFunctions -DisableNameChecking
Import-NAVAdminTool -DisableNameChecking
Remove-NAVLocalApplication -Server $Server -Database $Database -ServiceInstance $Instance
