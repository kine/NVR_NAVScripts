Param (
	[String]$BaseFob,
	[String]$DbBackupFile,
	[String]$LicenseFile,
	[String]$TargetPath,
	[String]$Server,
	[String]$Database,
	[String]$Instance,
    [Bool]$ForceNewDB=$false
)
#Write-Host $PSScriptRoot
if (Test-Path $TargetPath\src\setup.xml) {
  . "$PSScriptRoot\..\Get-NAVGITSetup.ps1" -SetupFile "$TargetPath\src\setup.xml" | Out-Null
}
Import-Module CommonPSFunctions -DisableNameChecking
Import-Module NVR_NAVScripts -DisableNameChecking
Import-NAVAdminTool

if ((Get-NAVServerInstance -ServerInstance $Instance) -and (-not $ForceNewDB)) {
    Write-Host "Server instance $Instance already exists, skipping the initialization of environment..."
} else {
    if (Get-NAVServerInstance -ServerInstance $Instance) 
    {
        Remove-NAVLocalApplication -Server $Server -Database $Database -ServerInstance $Instance
    }
    New-NAVLocalApplication -Server $Server -Database $Database -BaseFob $BaseFob -License $LicenseFile -DbBackupFile $DbBackupFile -ServerInstance $Instance -TargetPath $TargetPath
}
