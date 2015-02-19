Param (
	[String]$Server,
	[String]$Database,
	[String]$ResultFob,
	[String]$NavIde,
	[String]$LogFolder
)
Import-Module NVR_NAVScripts -Force -DisableNameChecking

NVR_NAVScripts\Export-NAVApplicationObject -Server $Server -Database $Database -Path $ResultFob -Filter 'Compiled=1' -NavIde $NavIde -LogFolder $LogFolder

