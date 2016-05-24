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
  $config= (. "$PSScriptRoot\..\Get-NAVGITSetup.ps1" -SetupFile "$TargetPath\src\setup.xml")
}
Import-Module -Name NVR_NAVScripts -DisableNameChecking -Force
Import-Module -Name CommonPSFunctions
Import-Module (Get-NAVAdminModuleName)

if ((Get-NAVServerInstance -ServerInstance $Instance) -and (-not $ForceNewDB)) {
    Write-Host "Server instance $Instance already exists, skipping the initialization of environment..."
} else {
    if (Get-NAVServerInstance -ServerInstance $Instance) 
    {
        Remove-NAVLocalApplication -Server $Server -Database $Database -ServerInstance $Instance
    }
    New-NAVLocalApplication -Server $Server -Database $Database -BaseFob $BaseFob -License $LicenseFile -DbBackupFile $DbBackupFile -ServerInstance $Instance -TargetPath $TargetPath -Version $config.NAVVersion
}
