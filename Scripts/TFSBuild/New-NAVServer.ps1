Param (
	[String]$BaseFob,
	[String]$DbBackupFile,
	[String]$LicenseFile,
	[String]$TargetPath,
	[String]$Server,
	[String]$Database,
	[String]$Instance
)
#Write-Host $PSScriptRoot
if (Test-Path $TargetPath\src\setup.xml) {
  . "$PSScriptRoot\..\Get-NAVGITSetup.ps1" -SetupFile "$TargetPath\src\setup.xml" | Out-Null
}
Import-Module CommonPSFunctions -DisableNameChecking
Import-Module NVR_NAVScripts -DisableNameChecking
Import-NAVAdminTool

if (Get-NAVServerInstance -ServerInstance $Instance) {
    Write-Host "Server instance $Instance already exists, skipping the initialization of environment..."
} else {
    New-NAVLocalApplication -Server $Server -Database $Database -BaseFob $BaseFob -License $LicenseFile -DbBackupFile $DbBackupFile -ServerInstance $Instance -TargetPath $TargetPath
}
