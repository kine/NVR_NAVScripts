param(
	[String]$Server,
	[String]$Database,
	[String]$Instance
)
if (Test-Path $TargetPath\setup.xml) {
    $null = (. "$TargetPath\NVRPowerShell\Scripts\Settings.ps1")
    $config = (. "$TargetPath\NVRPowerShell\Scripts\Get-NAVGITSetup.ps1" -SetupFile "$TargetPath\setup.xml")
}

Import-Module -Name NVR_NAVScripts -DisableNameChecking -Force
Import-Module -Name CommonPSFunctions
Import-Module (Get-NAVAdminModuleName)
Remove-NAVLocalApplication -Server $Server -Database $Database -ServerInstance $Instance
