Param (
	[String]$BaseFob,
	[String]$DbBackupFile,
	[String]$LicenseFile,
	[String]$TargetPath,
	[String]$Server,
	[String]$Database,
	[String]$Instance
)
Import-Module CommonPSFunctions -DisableNameChecking
Import-Module NVR_NAVScripts -DisableNameChecking
Import-NAVAdminTool
New-NAVLocalApplication -Server $Server -Database $Database -BaseFob $BaseFob -License $LicenseFile -DbBackupFile $DbBackupFile -ServiceInstance $Instance -TargetPath $TargetPath
